# CordX by Wraith

A fast, private toolkit for Discord server owners and creators. Static site — no build step, no backend, no tracking.

Open `index.html` directly, or serve the folder with any static host:

```bash
npx serve creator-hub        # or: python3 -m http.server -d creator-hub
```

It works from `file://` as well (classic scripts and hash routing, no ES modules or fetch of local files).

## What's inside

| Route | Tool |
| --- | --- |
| `#/home`, `#/tools` | Landing page with a lightweight 3D hero, tool index with filtering |
| `#/embeds` | **Embed builder** — live Discord-style preview, up to 10 embeds, fields (inline), author/footer/thumbnail/image, colour, timestamp, markdown toolbar, link/interactive buttons, live validation of Discord's limits, export as webhook JSON / embeds array / discord.js / discord.py / cURL, JSON import, optional "send through a webhook", save as template |
| `#/bio` | 15 styles × 3 lengths, symbols, 13 Unicode fonts, interests / games / anime / keywords / custom phrases, mood and personality. Always ≤ 190 characters (Discord's About Me limit) |
| `#/username` | 16 categories with examples, name / nickname / favourite word / numbers / characters / interests / theme / length range, validity check against Discord's handle rules, favourites |
| `#/rules` | 10 server types, strictness 1–5, 3–20 rules, 5 tones, staff & moderation policy, output as Discord markdown / plain / embed JSON, auto-split for the 2,000-character limit |
| `#/announcements` | 10 announcement types, Discord timestamp tags (`<t:…>`), ping warnings, 5 tones |
| `#/description` | Short / medium / long server descriptions with length caps |
| `#/roles` | Themed role hierarchies with colours and least-privilege permission suggestions; export as text, JSON or discord.js |
| `#/channels` | Category + channel layouts per server type with topics, read-only/staff hints, JSON export and a setup guide |
| `#/bots`, `#/ideas`, `#/templates` | Bot directory (plus Discord's built-in alternatives), server ideas + roulette, 14 ready-made embed templates |
| `#/saved` | Library of everything saved — search, favourites, export / import backup |
| `#/legal` | © Terms of use, privacy, copyright, trademarks and credits |
| `#/pro`, `#/about`, `#/settings` | Honest pricing page (no payments exist), privacy + Discord limits, effects/accent/density/data controls |

Global search: <kbd>Ctrl</kbd>/<kbd>⌘</kbd> + <kbd>K</kbd> or <kbd>/</kbd>.

## Performance model

* Initial load is ~63 KB of JS (unminified, ≈ 20 KB gzipped) + one CSS file. Every tool page is a separate script loaded on first visit.
* Effects are gated by `<html data-fx="full|lite|off">`:
  * **full** (desktop, fine pointer): half-resolution particle canvas capped at 30 fps, cursor light, card spotlight, 3D tilt, hero parallax.
  * **lite** (phones/touch, ≤ 2 cores or ≤ 2 GB RAM, data-saver): no canvas, no tilt, no blur.
  * **off** (`prefers-reduced-motion`): no animation at all.
* A frame-time governor halves, then stops, the particle field if frames stay slow. Particles also hold still while scrolling, pause when the tab is hidden, and pause while the search overlay is open.
* Only `transform`/`opacity` are animated. No `backdrop-filter` sits over moving content.

All of this can be overridden in **Settings**.

## Being accurate about Discord

The embed builder validates Discord's published limits (10 embeds, 256/4096/1024/2048 character caps, 25 fields, 6,000 characters combined) and explains the things that are easy to get wrong: only bots and webhooks can send embeds, buttons live outside the embed, non-link buttons need an application to receive clicks, plain webhooks have limited component support, mentions in embeds never ping. Where Discord's behaviour is uncertain or changes (server description length, webhook component support) the UI says so rather than guessing. Verify critical details against Discord's developer documentation.

## Privacy

Everything is stored in `localStorage` under `ch:*` keys (settings, drafts, saved items, form memory). The only network requests are the font stylesheet, images/emoji you choose to preview, and a webhook POST when you press **Send message**. Webhook URLs are never stored.

## Layout

```
index.html            shell, header, nav, search palette
css/styles.css        design tokens + all components
js/util.js            DOM helper (el), crypto RNG, storage, icons, toast, clipboard
js/md.js              Discord markdown → escaped HTML
js/preview.js         Discord-style message renderer
js/app.js             settings, router, nav, global search, shared UI kit
js/fx.js              particles, cursor light, tilt (lazy, idle-loaded)
js/pages/*.js         one lazy-loaded script per route
```

Adding a tool: create `js/pages/<id>.js` calling `CH.page('<id>', function (root) { … })`, then add the route to `ROUTES` in `js/app.js`.

## Interfaces (themes)

Pick one on the home page or in **Settings**. Each changes colours, the 3D lettering materials, the sticker character and the cursor effect:

| Interface | Inspired by | Cursor effect |
| --- | --- | --- |
| Wraith (default) | — | sparkle trail, star bursts |
| Optic | Cyclops | red laser trail; a visor beam, flash and screen shake on click / Generate |
| Speed | Quicksilver | white speed streaks behind the cursor; sonic ring on click |
| Claw | Wolverine | steel sparks; three claw slashes on click |

The stickers (characters, emblems, phrases) are original vector art — **no film stills or official artwork are included.** To use your own licensed images instead, list them in `js/config.js` under `characterImages` (for example `optic: ['assets/characters/optic-1.png']`). Only use images you have the right to publish.

Hero phrases and sticker angles "teleport" every ~1.5 s with a paper-tear transition (full/lite effects only; static under reduced motion). Movement effects run in Full mode with a mouse; clicks/taps also work in Lite mode.

## Deploying (Vercel)

It's a static site — no build step. In Vercel, import the repository and set **Root Directory** to `creator-hub`, Framework Preset **Other**, leave Build Command empty. `vercel.json` adds security headers and clean URLs.

## Tests used during development

Headless-Chromium scripts covered: all routes at three viewport sizes, ~1,000 generated bios (≤ 190 characters), username validity, embed builder export/import/validation, XSS escaping, reduced-motion / mobile (lite) modes, the theme switcher, sticker + tape teleporting, and the cursor-effect canvas.
