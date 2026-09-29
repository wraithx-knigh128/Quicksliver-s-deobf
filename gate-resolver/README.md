# Gate Resolver

A **passive redirect-chain inspector** for URLs you are authorized to inspect.
It answers "where does this link actually go, and what stops an automated
follower along the way?" — the same job as `curl -IL` or an online redirect
checker, with SSRF protection and a small UI.

## What it does

- Follows **only standard HTTP `3xx` `Location` redirects**, up to a hop limit.
- Reports the full chain: each URL, resolved IP, HTTP status, `Server` /
  `Content-Type`, number of cookies set, per-hop timing, the final URL, and any
  errors.
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
- **Rate limiting** — per client IP, plus a global concurrency cap.
- **Timeouts & size caps** — per-hop and whole-chain time budgets; only a small
  body sample is read for gate detection.
- **Honest `User-Agent`** — it identifies itself and does not spoof a browser to
  evade anti-bot measures.

## Run

No dependencies (Node.js built-ins only). Requires Node 18+.

```bash
cd gate-resolver
node server.js
# open http://127.0.0.1:8080
```

Environment variables: `PORT` (default `8080`), `HOST` (default `127.0.0.1`).

## Test

```bash
node test.js
```

## API

`POST /api/resolve` with `{"url": "https://example.com/..."}` returns:

```jsonc
{
  "start": "…", "finalUrl": "…", "hopCount": 2,
  "completed": true, "stopReason": null,
  "hops": [
    { "url": "…", "ip": "…", "status": 301, "location": "…",
      "server": "…", "contentType": "…", "setCookie": 0,
      "elapsedMs": 42, "flags": [] }
  ]
}
```

Each `flags[]` entry has `type`, `label`, `requiresUser: true`, and (for
redirects it won't follow) a `target`.

## Authorized use only

Use this on URLs you own or are authorized to inspect. It is a diagnostic tool,
not a means to defeat any protection.
