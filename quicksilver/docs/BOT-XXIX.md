# Website or Discord bot? — Prompt XXIX evaluation

Prompt XXIX §VII asks whether QuickSilver should stay a website, add a Discord bot, or do both, and says not to build a bot before the
findings are presented and approved. **Nothing in this document has been implemented.** It updates the recommendation of
`docs/BOT-RECOMMENDATION.md` (Prompt XVII) with what has changed since then.

## Recommendation

**Keep the website as the only product for now. Do not build a public bot. If you want a bot, make it a private, single-server, DM-only
beta that calls the same `/api/` backend, and only after the conditions below hold.**

Three things changed since XVII, and all three point the same way:

1. **Some deobfuscation now happens on the server.** The MoonSec V3 adapter sends the script to `/api/engine` after the person confirms,
   on the website, that they may have it analysed (`src/app/engine-ui.js`). A bot would put that confirmation in a chat window, where the
   script has already been posted (and, in a channel, shown to everyone) before anyone confirms anything.
2. **Results are classified honestly, and the classification needs room.** A result is one of eight outcomes. Most real results are
   "syntax-valid but behaviourally unverified" or "partial" (docs/REPORT-XXIX.md), and the report explains why at a length a
   2,000-character Discord message cannot hold. A bot would push the result towards a downloaded file with a one-line verdict, which is
   the presentation most likely to be read as "deobfuscated" when it is not.
3. **The audience risk is concrete.** Of the 786 programs the MoonSec V3 engine rebuilt from the public sample collection, 354 (45%)
   call functions that only Roblox exploit executors provide (`hookmetamethod`, `getgenv`, `http_request`, `fireclickdetector`, …) and
   549 (70%) download and run more code (`HttpGet` / `loadstring`). A bot that turns a pasted protected script into readable source in a
   shared channel is a distribution channel for that material. Discord's Community Guidelines prohibit sharing game cheats or hacks, and the Developer Policy holds the
   app's owner responsible for what the app does.

## The comparison

| | Website (today) | Discord bot |
|---|---|---|
| Where the script goes | Stays in the browser unless the person confirms a server engine or a retrieval; the server keeps nothing | Always goes to the bot's server, and in a channel to everyone in it |
| Authorisation | A dialog before anything is sent, with what happens to the script | A button after the script is already posted; cannot stop it being seen |
| Result | The full report, the stages, the behaviour check, a diff, a download | 2,000 characters, or a file attachment; the report is easy to skip |
| Behaviour check (sandbox) | In the browser, on the person's machine | On the bot's server, for everyone: more load, and the same isolation work |
| Limits | Per-instance rate and concurrency limits on `/api/engine`; client work is free | Every request is server work; per-user limits needed |
| Timing | No deadline | Must acknowledge within 3 seconds, then deferred follow-ups for at most 15 minutes |
| Licence | Ed25519 keys checked on the server (`api/_lib/entitlement.js`) | The same check, keyed by Discord user instead of a key in the browser |
| Policy surface | The site's own terms | Discord's Developer Policy and Community Guidelines as well |
| Cost to build | Done | A new process, a gateway or HTTP endpoint, storage for per-user state, moderation |

## If you approve a bot later: the conditions

- **Same backend, no second engine.** The bot calls the deployment's own `/api/engine`, `/api/github` and a new endpoint that runs the
  same `deobfuscate()` (src/pipeline/unified.js) the page runs. No reconstruction logic in the bot.
- **DMs and ephemeral replies only.** No command in guild channels that posts code; results are ephemeral messages or files sent to the
  requester alone.
- **Attestation before upload.** A slash command opens a modal with the same statement as the website's dialog; the file is attached
  only after the person confirms.
- **The full classification.** Every reply starts with the outcome label (validated / syntax-valid but unverified / partial / …) and
  the first line of the reason; "validated" is never shortened to "done".
- **Per-user limits and a kill switch.** Rate limits per Discord user and per server, `QS_ENGINE_MODE=off` respected, and a way to
  revoke a user.
- **No storage of scripts.** As on the website: nothing is kept after the reply.
- **Deferred responses.** Engine runs take up to 60 seconds, so every command defers within the 3-second window and answers by
  follow-up within the 15-minute token lifetime.

## What I need from you

A yes or no on the recommendation. If yes, which server the private beta should run in and who may use it. I will not start a bot without
that answer.

## Sources

- Discord, Receiving and Responding to Interactions (3-second initial response, 15-minute interaction tokens):
  https://docs.discord.com/developers/interactions/receiving-and-responding
- Discord Developer Policy: https://support-dev.discord.com/hc/en-us/articles/8563934450327-Discord-Developer-Policy
- Discord Community Guidelines (sharing or selling game cheats or hacks): https://discord.com/guidelines
- Upload limits: Discord's free limit changed several times (8 MB, 25 MB in 2023, 10 MB in 2024, 20 MB in 2026 according to press
  reports); no source found states a separate limit for bot attachments, so a design would have to be checked against the live API.
