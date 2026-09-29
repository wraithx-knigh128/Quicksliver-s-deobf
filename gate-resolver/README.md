# Gate Resolver

A **passive redirect-chain inspector** for URLs you are authorized to inspect.
It answers "where does this link actually go, and what stops an automated
follower along the way?" — the same job as `curl -IL` or an online redirect
checker, with SSRF protection and a small UI.

## What it does

- Follows **only standard HTTP `3xx` `Location` redirects**, up to a hop limit.
- Reports the full chain: each URL, resolved IP, HTTP status, `Server` /
  `Content-Type`, number of cookies set, `Retry-After` (when present), per-hop
  timing, the final URL, and any errors.
- **Detects and clearly labels** steps that require a human, and **stops the
  automated chain there**:
  - CAPTCHA (reCAPTCHA, hCaptcha, Cloudflare Turnstile)
  - Anti-bot / "checking your browser" challenges (Cloudflare, DDoS-Guard, Imperva)
  - Login / authentication walls (and HTTP 401/403/407)
  - Paywalls (and HTTP 402)
  - Ad-link / unlock gates
  - `meta refresh` and JavaScript-based navigation (target shown, not followed)

## What it deliberately does **not** do

This tool respects access controls. It does not, and will not:

- Execute page JavaScript or drive a headless browser.
- Store or replay cookies/sessions to get past a challenge.
- Solve or circumvent any CAPTCHA, anti-bot system, paywall, login, or other
  access control.
- Auto-follow `meta refresh` or JS redirects.

When it meets any of those, it labels the step as **"requires user action"** and
stops. Identifying a gate is not the same as opening it — this only does the
former.

## Safety

- **URL validation** — `http`/`https` only, allowed ports, no embedded credentials.
- **SSRF protection** — DNS is resolved up front; requests to private, loopback,
  link-local, CGNAT, and other reserved IPv4/IPv6 ranges are refused. The
  connection is **pinned to the vetted IP** (with correct `Host`/SNI) so a host
  cannot rebind to an internal address between the check and the fetch. Every
  redirect hop is re-validated.
- **Rate limiting** — fixed window per client IP. On the serverless deployment
  each warm instance keeps its own window, so it is best-effort abuse control;
  a hard global cap would need a shared store (e.g. Vercel KV / Redis).
- **Timeouts & size caps** — per-hop and whole-chain time budgets; only a small
  body sample is read for gate detection.
- **Security headers** — `Content-Security-Policy` (no inline scripts),
  `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options`.
- **Honest `User-Agent`** — it identifies itself and does not spoof a browser to
  evade anti-bot measures.

## Layout

```
gate-resolver/
  index.html          static UI (served at /)
  app.js              front-end script (no inline JS, CSP-friendly)
  api/
    resolve.js        POST /api/resolve  (Vercel serverless function)
    _lib/
      resolver.js     SSRF + redirect-chain core (bundled, never routed/served)
      handler.js      shared request handler
  server.js           local dev server (mounts the same handler)
  test.js             53 checks, no network needed
  vercel.json         function limits + security headers
  package.json
```

The `_lib` directory uses the Vercel convention that `api/` files prefixed with
`_` are helpers, not HTTP endpoints, so the core is bundled into the function
but never exposed as a route or a static file.

## Run locally

No dependencies (Node.js built-ins only). Requires Node 18+.

```bash
cd gate-resolver
npm start          # or: node server.js
# open http://127.0.0.1:8080
```

`PORT` and `HOST` are configurable via environment variables.

## Test

```bash
npm test           # or: node test.js
```

## Deploy to Vercel

This is a zero-config Vercel project: static files at the root, one serverless
function under `api/`. No build step, no dependencies.

- Import the repository in Vercel and set the **Root Directory** to
  `gate-resolver`, or
- run `vercel` from this directory with the CLI.

`vercel.json` sets the function's `maxDuration` and the response security
headers. The serverless resolve budget is kept under the function timeout.

## API

`POST /api/resolve` with `{"url": "https://example.com/..."}` returns:

```jsonc
{
  "start": "…", "finalUrl": "…", "hopCount": 2,
  "completed": true, "stopReason": null,
  "hops": [
    { "url": "…", "ip": "…", "status": 301, "location": "…",
      "server": "…", "contentType": "…", "setCookie": 0,
      "retryAfter": null, "elapsedMs": 42, "flags": [] }
  ]
}
```

Each `flags[]` entry has `type`, `label`, `requiresUser: true`, and (for
redirects it won't follow) a `target`.

## Authorized use only

Use this on URLs you own or are authorized to inspect. It is a diagnostic tool,
not a means to defeat any protection.
