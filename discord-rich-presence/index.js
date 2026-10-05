const { Client } = require("@xhayper/discord-rpc");
const config = require("./config");

if (!config.clientId || config.clientId.startsWith("PUT_")) {
  console.error("Set your Application ID in config.js first (clientId).");
  process.exit(1);
}

const startTimestamp =
  config.hoursAgo === null ? undefined : Date.now() - config.hoursAgo * 60 * 60 * 1000;

const activity = {
  type: config.type,
  details: config.details || undefined,
  state: config.state || undefined,
  startTimestamp,
  largeImageKey: config.largeImageKey || undefined,
  largeImageText: config.largeImageText || undefined,
  smallImageKey: config.smallImageKey || undefined,
  smallImageText: config.smallImageText || undefined,
  buttons: (config.buttons || []).slice(0, 2),
  instance: false,
};

const client = new Client({ clientId: config.clientId });

client.on("ready", async () => {
  try {
    await client.user.setActivity(activity);
    console.log(`Rich Presence is live on ${client.user.username}'s profile.`);
    console.log("Keep this window open. Press Ctrl+C to stop.");
  } catch (err) {
    console.error("Failed to set activity:", err.message || err);
  }
});

client.on("disconnected", () => {
  console.log("Disconnected from Discord. Retrying in 15s...");
  setTimeout(connect, 15000);
});

function connect() {
  client.login().catch((err) => {
    console.error(
      "Could not connect to Discord. Is the Discord DESKTOP app open on this PC?",
      err.message || err
    );
    setTimeout(connect, 15000);
  });
}

process.on("SIGINT", async () => {
  try {
    await client.user?.clearActivity();
    await client.destroy();
  } catch {}
  process.exit(0);
});

connect();
