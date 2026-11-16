browser.action.setBadgeText({text: "8"});
browser.action.setTitle({title: "Ardia fixture action"});
browser.runtime.onMessage.addListener((message, sender, reply) => { reply("worker-answer"); });
