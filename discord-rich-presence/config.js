// ============================================================
//  EDIT THIS FILE. Everything shown on your profile is here.
// ============================================================

module.exports = {
  // Application ID from https://discord.com/developers/applications
  // The application's NAME is the header shown on your profile
  // (e.g. "Watching <App Name>"), so name the app whatever you want displayed.
  clientId: "PUT_YOUR_APPLICATION_ID_HERE",

  // 0 = Playing, 2 = Listening, 3 = Watching, 5 = Competing
  type: 3,

  // First bold line
  details: "Your first line here",
  // Second line
  state: "Your second line here",

  // Big picture: either an asset name uploaded in
  // Developer Portal -> Rich Presence -> Art Assets,
  // or a direct https:// image URL (.png / .jpg / .gif).
  largeImageKey: "https://i.imgur.com/your-image.png",
  largeImageText: "Text shown when hovering the big image",

  // Small round badge in the corner of the big picture (optional, "" to hide)
  smallImageKey: "https://i.imgur.com/your-badge.png",
  smallImageText: "Text shown when hovering the badge",

  // Timer. Set hoursAgo to a big number for a huge "elapsed" timer
  // (e.g. 647 makes it start at ~647:00:00). Set to null to hide the timer.
  hoursAgo: 0,

  // Up to 2 buttons. Labels max 32 chars, URL must start with https://
  // NOTE: you can't click your own buttons - only other people can.
  buttons: [
    { label: "Roblox", url: "https://www.roblox.com" },
    { label: "Gun.lol", url: "https://guns.lol" },
  ],
};
