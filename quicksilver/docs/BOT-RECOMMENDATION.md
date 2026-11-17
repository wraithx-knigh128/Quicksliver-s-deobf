# Should OMEGA NEXUS also be a bot? — recommendation

Prompt XVII §VIII asks for an honest recommendation on a Discord (or other) bot, not an implementation. Short answer below, then the reasoning,
the three models compared, a practical architecture if you want it, and the decision I need from you.

## Recommendation (short)

**Yes — but a thin one, and later.** A Discord bot is a good fit for this product's audience and would plausibly bring users, because the Roblox/
Luau scripting communities this tool serves already live on Discord. But it should be a **thin front-end over the existing engine**, not a second
product, and it is **not** the highest-value work right now. I would ship the website redesign first, keep the bot as a fast follow, and start it
as a single-guild / invite-only beta rather than a public bot.

The one hard requirement: the bot must reuse the exact same reconstruction engine the website uses, with the **same no-execution guarantee**. If a
bot ever ran submitted scripts to "see what they do", that would be a serious regression in safety; it must not.

## Why a bot fits here (and why to be careful)

- **Audience fit.** The people who hit obfuscated Lua/Luau are overwhelmingly on Discord already. "Paste the script, get the reconstruction back"
  is a natural bot interaction, and it removes the step of opening a site and pasting into a box.
- **The engine is portable.** The core engine (`src/recover/pipeline.js` and everything under `src/`) is pure JavaScript that already runs in a Web
  Worker with no DOM dependency. The same modules run unchanged under Node, so a bot does **not** need a reimplementation — it needs a Node process
  that imports `recover()` and returns the result. This is the single biggest reason a bot is cheap to build correctly.
- **The caution.** A bot centralises what is currently a client-side, zero-server-trust tool. Today a user's script never leaves their browser
  unless they ask for the sandbox. A bot means users upload scripts to infrastructure you run. That is a privacy and liability shift, not just an
  engineering one, and it drives most of the decisions below.

## The §VIII checklist, answered

- **Would users benefit?** Yes, for the submit-and-receive flow and for sharing a reconstruction in a channel. They would *not* benefit from a bot
  that is just the website's features re-listed as slash commands; the benefit is the in-Discord convenience, not new capability.
- **How jobs are processed.** A Node worker imports the existing engine and runs `recover(src, { sandbox: { enabled: false } })` by default (static,
  no execution). Sandbox evaluation stays **off** for bot jobs unless a trusted operator explicitly enables it for a specific job, because the
  sandbox, while isolated, is still more surface than static reconstruction needs.
- **File uploads / downloadable results.** Accept `.lua`/`.txt` attachments and code blocks; return the reconstruction as a file attachment (not a
  giant message), plus the short report inline. Cap input size (e.g. 2 MB) and output size.
- **Processing limits / queue.** A single in-process queue with a per-job wall-clock timeout (the engine already supports fuel/time limits) and a
  concurrency cap. Reject rather than queue indefinitely when full.
- **Hosting / cost.** Modest: one small always-on Node host (the engine is CPU-bound but short per job; no GPU, no DB required for a stateless bot).
  The existing Vercel functions do not fit a long-lived bot gateway connection, so the bot is a separate small service (a cheap VPS or a container),
  not a Vercel function. Cost is dominated by that one host plus egress; low at community scale.
- **Security / safe handling.** (1) Never execute submitted scripts — static reconstruction only. (2) Treat every upload as hostile input: run the
  engine with time and memory caps; the engine is already written to not execute code it reads. (3) Do not log script contents; keep only
  minimal metadata. (4) Run the worker as an unprivileged process with no outbound network for job handling.
- **Permissions / privacy.** Process only scripts submitted directly to the bot (DM or a command), never scrape channels. State clearly that
  submitted scripts are processed on your infrastructure and not retained. Offer a DM mode so a user need not post their script in a public channel.
- **Rate limits / abuse.** Per-user and per-guild rate limits; a global concurrency cap; size caps; reject archives. Abuse here is mostly
  resource-exhaustion (huge or pathological inputs), which the engine's limits and a job timeout handle.
- **Integration with site/API.** Share the engine package and the report formatter. The bot can also just link to the website for the full
  interactive view (diff, tree, trace) rather than trying to reproduce those in Discord.
- **Would it attract users or just duplicate the site?** It attracts users *if* it offers the in-Discord convenience and sharing that the site
  cannot; it duplicates the site if it tries to be a second full UI. Keep it to submit → report + file, and link out for the rich views.

## Three models compared

| | Website only (today) | Bot only | Website + bot (thin bot) |
|---|---|---|---|
| Reach into the actual audience | moderate | high | high |
| Privacy / trust | best (client-side, nothing uploaded) | weakest (all uploads centralised) | mixed: site stays client-side, bot is opt-in upload |
| Build cost | none (exists) | high (loses the rich UI) | low (reuse engine + report) |
| Running cost | ~static hosting | one small host | static hosting + one small host |
| Rich views (diff, tree, trace) | yes | no (Discord can't) | yes on site, link from bot |
| Abuse surface | minimal | real (resource exhaustion) | contained by caps |

Bot-only is the worst of the three: it throws away the client-side privacy story and the rich UI. Website-only is safe but misses where the users
are. Website + a thin bot is the recommendation.

## Proposed architecture (if you approve)

```
  Discord  ──slash command / DM / attachment──►  bot gateway (small Node service, separate host)
                                                   │  validate size/type, rate-limit, enqueue
                                                   ▼
                                                 job queue (in-process, bounded, per-job timeout)
                                                   │
                                                   ▼
                                                 engine worker  (imports src/recover/pipeline.js,
                                                   │             recover(src, { sandbox:{enabled:false} }))
                                                   ▼
                                                 reply: short report inline + reconstruction as a file;
                                                        link to the website for diff/tree/trace
```

- **One repository, shared engine.** The bot is a new top-level service (e.g. `bot/`) that imports the existing `src/` modules; no engine fork.
- **Stateless.** No database needed for v1; no script retention. Add persistence only if you later want job history, and make it opt-in.
- **Same report.** Reuse the report formatter so the bot's output matches the website's wording and honesty (PARTIAL/minimal where the program is
  not recovered, etc.).
- **Rollout.** Invite-only / single-guild beta → watch cost and abuse → widen. Keep sandbox execution off for bot jobs.

## What I need from you

A decision before I build anything:

1. **Go / no-go / defer** on a thin Discord bot.
2. If go: confirm the **no-execution, no-retention** constraints as hard requirements, and whether you want it in this repo (`bot/`) or a separate
   one.
3. Confirm the rollout can start **invite-only** rather than public.

I will not implement the bot until you decide. If you say go, the website redesign still ships first.
