# Discord Rich Presence (Playing / Watching / Listening)

Shows a custom activity card on your Discord profile: a header, two lines of text, a big image,
a small badge, an elapsed timer and up to 2 buttons.

## Requirements
- A **PC** (Windows / macOS / Linux) with the **Discord desktop app** open and logged in.
  Rich Presence can't be set from the phone app, but once it's running on PC,
  everyone (phone users too) sees it on your profile.
- [Node.js](https://nodejs.org) 18 or newer.

## Setup
1. Go to https://discord.com/developers/applications → **New Application**.
   - The **name** you give the app is the header on your profile
     (e.g. name it `My Show` and it'll say "Watching My Show").
2. Copy the **Application ID** from General Information.
3. Optional: under **Rich Presence → Art Assets** upload images and use their names as
   `largeImageKey` / `smallImageKey`. You can also just paste direct `https://` image URLs.
4. Open `config.js` and fill in `clientId`, text, images, timer and buttons.
5. In Discord: **User Settings → Activity Privacy → "Share my activity"** must be ON.

## Run
```
npm install
npm start
```
On Windows you can just double-click `start.bat`.

Keep the window open; the status disappears when you close it (or press Ctrl+C).

## Notes
- `type`: `0` Playing, `2` Listening, `3` Watching, `5` Competing.
- You can't click your own buttons, and they may not show for you — check from an alt or ask a friend.
- After editing `config.js`, stop (Ctrl+C) and run again.
