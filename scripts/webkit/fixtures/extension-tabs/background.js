let updates = [];
browser.tabs.onUpdated.addListener((id, change) => updates.push({ id, change }));
browser.runtime.onMessage.addListener((message, sender, reply) => {
  if (message === "gate") { reply("worker-answer"); return; }
  const run = async () => {
    if (message.operation === "create") return browser.tabs.create({url: message.url});
    if (message.operation === "update") return browser.tabs.update(message.id, {url: message.url});
    return {tabs: await browser.tabs.query({}), updates};
  };
  run().then(reply, error => reply({error: error.message}));
  return true;
});
