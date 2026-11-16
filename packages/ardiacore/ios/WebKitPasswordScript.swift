import Foundation

enum WebKitPasswordScript {
  static let source = #"""
(() => {
  const token = globalThis.crypto?.randomUUID?.() || Math.random().toString(36).slice(2) + Date.now();
  const post = (kind, data) => {
    try { webkit.messageHandlers.ardiaPasswords.postMessage({kind, data, token}); } catch (_) {}
  };
  const visible = (element) => {
    if (!element || !element.isConnected || element.disabled || element.readOnly || element.closest('[hidden],[inert]')) return false;
    const rect = element.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0 || innerWidth <= 0 || innerHeight <= 0 || rect.bottom <= 0 || rect.right <= 0 || rect.top >= innerHeight || rect.left >= innerWidth) return false;
    for (let node = element; node instanceof Element; node = node.parentElement) {
      const style = getComputedStyle(node);
      if (style.display === 'none' || style.visibility !== 'visible' || Number(style.opacity) === 0) return false;
    }
    try {
      for (let frame = window; frame !== frame.top; frame = frame.parent) {
        const host = frame.frameElement;
        if (!host) return false;
        const bounds = host.getBoundingClientRect();
        for (let node = host; node; node = node.parentElement) {
          if (Number(frame.parent.getComputedStyle(node).opacity) === 0) return false;
        }
        const style = frame.parent.getComputedStyle(host);
        if (bounds.width <= 0 || bounds.height <= 0 || bounds.bottom <= 0 || bounds.right <= 0 || bounds.top >= frame.parent.innerHeight || bounds.left >= frame.parent.innerWidth || style.display === 'none' || style.visibility !== 'visible' || Number(style.opacity) === 0) return false;
      }
    } catch (_) { return false; }
    return true;
  };
  const inspect = (field = document.activeElement) => {
    const scope = field?.form || document;
    const passwords = Array.from(scope.querySelectorAll('input[type="password"]'));
    if (passwords.length !== 1 || !visible(passwords[0])) return null;
    const password = passwords[0];
    const inputs = Array.from(scope.querySelectorAll('input'));
    const preceding = inputs.slice(0, inputs.indexOf(password)).filter(input => ['text','email','tel'].includes(input.type) && visible(input));
    const username = preceding.findLast(input => input.autocomplete === 'username') || preceding.at(-1) || null;
    if (field instanceof HTMLInputElement && field !== username && field !== password) return null;
    return {username, password};
  };
  let gestureAt = -Infinity;
  let selected = null;
  let submitted = false;
  const request = (gesture = false) => {
    const form = inspect();
    if (!form) return;
    selected = form;
    const rect = document.activeElement.getBoundingClientRect();
    let x = rect.x, y = rect.bottom;
    try {
      for (let frame = window; frame !== frame.top; frame = frame.parent) {
        const host = frame.frameElement;
        const bounds = host.getBoundingClientRect();
        x += bounds.left + host.clientLeft;
        y += bounds.top + host.clientTop;
      }
    } catch (_) { return; }
    post('focus', {username: form.username?.value || '', empty: !form.password.value && !form.username?.value, gesture, x, y});
  };
  for (const kind of ['pointerdown', 'keydown']) document.addEventListener(kind, event => {
    if (!event.isTrusted) return;
    gestureAt = performance.now();
    if (kind === 'pointerdown') setTimeout(() => request(true), 0);
  }, true);
  document.addEventListener('focusin', () => request(performance.now() - gestureAt < 1000), true);
  const submit = (form) => {
    if (submitted) return;
    const candidate = inspect(form?.querySelector('input[type="password"]') || document.activeElement);
    if (candidate && candidate.password.value && candidate.password.value.length <= 65536) {
      submitted = true;
      post('submit', {username: candidate.username?.value || '', password: candidate.password.value});
      return;
    }
    if (!document.querySelector('input[type="password"]')) {
      const username = document.querySelector('input[autocomplete="username"],input[type="email"]');
      if (visible(username) && username.value) post('username', {username: username.value});
    }
  };
  document.addEventListener('submit', event => { submitted = false; submit(event.target); }, true);
  addEventListener('pagehide', () => submit(null));
  window.__ardiaPasswords = {
    inspect: () => { const form = inspect(); return form ? {username: !!form.username, password: true} : null; },
    request,
    fill(expected, username, password) {
      if (expected !== token) return false;
      const form = inspect();
      if (!form || !selected || form.password !== selected.password || form.username !== selected.username || form.password.value) return false;
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
      const set = (input, value) => {
        setter.call(input, value);
        input.dispatchEvent(new Event('input', {bubbles: true}));
        input.dispatchEvent(new Event('change', {bubbles: true}));
      };
      if (form.username) set(form.username, username);
      const current = inspect();
      if (!current || current.password !== form.password || current.username !== form.username || current.password.value) return false;
      set(form.password, password);
      return true;
    },
  };
  const ready = () => post('ready', {form: !!inspect()});
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', ready, {once: true});
  else ready();
})();
"""#
}
