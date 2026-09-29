'use strict';

/*
 * Gate Resolver — core library (no HTTP server).
 *
 * Shared by the local dev server (server.js) and the Vercel serverless
 * function (api/resolve.js) so the SSRF and redirect logic lives in one place.
 *
 * WHAT THE RESOLVER DOES
 *   Follows ONLY standard HTTP 3xx `Location` redirects and reports the chain.
 *   It DETECTS and LABELS steps that require a human (CAPTCHA, anti-bot
 *   challenge, login, paywall, ad-gate, meta-refresh / JS redirect) and stops
 *   the automated chain there. It never bypasses any of them: no JavaScript is
 *   executed, no cookies/sessions are replayed, no access control is defeated.
 *
 * SAFETY
 *   URL validation (http/https only) + SSRF protection: private / loopback /
 *   link-local / reserved IPv4+IPv6 ranges are blocked, the connection is pinned
 *   to the vetted IP (DNS-rebinding safe), and every hop is re-validated.
 */

const http = require('http');
const https = require('https');
const net = require('net');
const dns = require('dns').promises;
const { URL } = require('url');

// ----------------------------- configuration ------------------------------- //

const DEFAULTS = {
  maxHops: 10,
  hopTimeoutMs: 10_000,
  budgetMs: 30_000,
  maxBodyBytes: 65_536,
  maxLocationLength: 4_096,
  userAgent: 'GateResolver/1.0 (+redirect-chain inspector; passive, no bypass)',
};

const ALLOWED_PROTOCOLS = new Set(['http:', 'https:']);
const ALLOWED_PORTS = new Set([80, 443, 8080, 8443]);

// ------------------------------ IP range logic ----------------------------- //

function ipv4ToInt(ip) {
  const parts = ip.split('.');
  if (parts.length !== 4) return null;
  let n = 0;
  for (const p of parts) {
    if (!/^\d{1,3}$/.test(p)) return null;
    const v = Number(p);
    if (v > 255) return null;
    n = n * 256 + v;
  }
  return n >>> 0;
}

function inV4Cidr(ipInt, cidr) {
  const [base, bitsStr] = cidr.split('/');
  const bits = Number(bitsStr);
  const baseInt = ipv4ToInt(base);
  if (baseInt === null) return false;
  if (bits === 0) return true;
  const mask = (0xffffffff << (32 - bits)) >>> 0;
  return (ipInt & mask) === (baseInt & mask);
}

// Blocked IPv4 ranges (private, loopback, link-local, CGNAT, reserved, etc.)
const BLOCKED_V4_CIDRS = [
  '0.0.0.0/8',        // "this" network
  '10.0.0.0/8',       // private
  '100.64.0.0/10',    // CGNAT
  '127.0.0.0/8',      // loopback
  '169.254.0.0/16',   // link-local (incl. cloud metadata 169.254.169.254)
  '172.16.0.0/12',    // private
  '192.0.0.0/24',     // IETF protocol assignments
  '192.0.2.0/24',     // TEST-NET-1
  '192.88.99.0/24',   // 6to4 relay anycast
  '192.168.0.0/16',   // private
  '198.18.0.0/15',    // benchmarking
  '198.51.100.0/24',  // TEST-NET-2
  '203.0.113.0/24',   // TEST-NET-3
  '224.0.0.0/4',      // multicast
  '240.0.0.0/4',      // reserved
  '255.255.255.255/32',
];

function isBlockedV4(ip) {
  const ipInt = ipv4ToInt(ip);
  if (ipInt === null) return true; // unparseable => block
  return BLOCKED_V4_CIDRS.some(cidr => inV4Cidr(ipInt, cidr));
}

// Parse an IPv6 string into 16 bytes; returns null if invalid.
function ipv6ToBytes(input) {
  let ip = input.split('%')[0]; // strip zone id
  let embeddedV4 = null;

  if (ip.includes('.')) {
    const lastColon = ip.lastIndexOf(':');
    const v4 = ip.slice(lastColon + 1);
    const v4Int = ipv4ToInt(v4);
    if (v4Int === null) return null;
    embeddedV4 = [(v4Int >>> 24) & 255, (v4Int >>> 16) & 255, (v4Int >>> 8) & 255, v4Int & 255];
    ip = ip.slice(0, lastColon + 1) + '0:0';
  }

  const halves = ip.split('::');
  if (halves.length > 2) return null;

  const parseGroups = (s) => (s === '' ? [] : s.split(':'));
  const head = parseGroups(halves[0]);
  const tail = halves.length === 2 ? parseGroups(halves[1]) : null;

  let groups;
  if (tail === null) {
    groups = head;
    if (groups.length !== 8) return null;
  } else {
    const missing = 8 - (head.length + tail.length);
    if (missing < 0) return null;
    groups = [...head, ...Array(missing).fill('0'), ...tail];
  }
  if (groups.length !== 8) return null;

  const bytes = [];
  for (const g of groups) {
    if (!/^[0-9a-fA-F]{1,4}$/.test(g)) return null;
    const val = parseInt(g, 16);
    bytes.push((val >>> 8) & 255, val & 255);
  }
  if (embeddedV4) {
    bytes[12] = embeddedV4[0]; bytes[13] = embeddedV4[1];
    bytes[14] = embeddedV4[2]; bytes[15] = embeddedV4[3];
  }
  return bytes;
}

function isBlockedV6(ip) {
  const b = ipv6ToBytes(ip);
  if (!b) return true;

  const isZero = (from, to) => b.slice(from, to).every(x => x === 0);

  // ::/128 unspecified, ::1 loopback
  if (isZero(0, 16)) return true;
  if (isZero(0, 15) && b[15] === 1) return true;

  // IPv4-mapped ::ffff:0:0/96 and IPv4-compatible ::/96 -> check the v4 tail
  if ((isZero(0, 10) && b[10] === 0xff && b[11] === 0xff) || isZero(0, 12)) {
    return isBlockedV4(`${b[12]}.${b[13]}.${b[14]}.${b[15]}`);
  }
  // NAT64 64:ff9b::/96 -> check embedded v4
  if (b[0] === 0x00 && b[1] === 0x64 && b[2] === 0xff && b[3] === 0x9b && isZero(4, 12)) {
    return isBlockedV4(`${b[12]}.${b[13]}.${b[14]}.${b[15]}`);
  }

  if ((b[0] & 0xfe) === 0xfc) return true;                  // fc00::/7 unique local
  if (b[0] === 0xfe && (b[1] & 0xc0) === 0x80) return true; // fe80::/10 link-local
  if (b[0] === 0xff) return true;                           // ff00::/8 multicast
  if (b[0] === 0x20 && b[1] === 0x01 && b[2] === 0x0d && b[3] === 0xb8) return true; // 2001:db8::/32 doc

  return false;
}

function isBlockedIp(ip) {
  const kind = net.isIP(ip);
  if (kind === 4) return isBlockedV4(ip);
  if (kind === 6) return isBlockedV6(ip);
  return true; // not an IP literal => block
}

// --------------------------- URL validation / SSRF ------------------------- //

function validateUrl(raw) {
  let u;
  try {
    u = new URL(raw);
  } catch {
    return { ok: false, reason: 'Not a valid URL.' };
  }
  if (!ALLOWED_PROTOCOLS.has(u.protocol)) {
    return { ok: false, reason: `Protocol "${u.protocol}" is not allowed (http/https only).` };
  }
  if (!u.hostname) {
    return { ok: false, reason: 'URL has no host.' };
  }
  const port = u.port ? Number(u.port) : (u.protocol === 'https:' ? 443 : 80);
  if (!ALLOWED_PORTS.has(port)) {
    return { ok: false, reason: `Port ${port} is not allowed.` };
  }
  if (u.username || u.password) {
    return { ok: false, reason: 'URLs with embedded credentials are not allowed.' };
  }
  return { ok: true, url: u, port };
}

// Resolve a hostname and return a single vetted, public IP (or an error).
async function resolveSafeIp(hostname) {
  const literalKind = net.isIP(hostname);
  if (literalKind) {
    if (isBlockedIp(hostname)) {
      return { ok: false, reason: `Address ${hostname} is in a blocked (private/reserved) range.` };
    }
    return { ok: true, ip: hostname, family: literalKind };
  }

  let records;
  try {
    records = await dns.lookup(hostname, { all: true, verbatim: true });
  } catch (e) {
    return { ok: false, reason: `DNS lookup failed: ${e.code || e.message}` };
  }
  if (!records.length) {
    return { ok: false, reason: 'DNS returned no records.' };
  }
  // Every resolved address must be public; otherwise refuse (rebinding-safe).
  for (const r of records) {
    if (isBlockedIp(r.address)) {
      return { ok: false, reason: `Host resolves to a blocked (private/reserved) address ${r.address}.` };
    }
  }
  const chosen = records[0];
  return { ok: true, ip: chosen.address, family: chosen.family };
}

// ------------------------------ gate detection ----------------------------- //
// These signatures only LABEL a step as needing a human. Nothing is bypassed.

const GATE_SIGNATURES = [
  { type: 'captcha', label: 'CAPTCHA challenge', re: /www\.google\.com\/recaptcha|g-recaptcha|grecaptcha|data-sitekey|hcaptcha\.com|h-captcha|challenges\.cloudflare\.com\/turnstile|cf-turnstile/i },
  { type: 'anti-bot', label: 'Anti-bot / Cloudflare challenge', re: /cf-browser-verification|__cf_chl|cf-challenge|checking your browser|ddos-guard|_Incapsula_|imperva/i },
  { type: 'ad-gate', label: 'Ad-link / unlock gate', re: /linkvertise|loot-?labs|lootdest|work\.ink|work-ink|sub2unlock|sub4unlock|adf\.ly|adfly|rekonise|boost\.ink|lockr\.so|social-unlock|mboost/i },
  { type: 'auth', label: 'Login / authentication wall', re: /<input[^>]+type=["']password["']|name=["'](password|passwd|login)["']|id=["'](login|signin)["']|oauth\/authorize|accounts\.google\.com\/signin/i },
  { type: 'paywall', label: 'Paywall', re: /paywall|subscribe to (?:read|continue)|meteredContent|piano\.io|tinypass/i },
];

function detectMetaRefresh(body) {
  const m = body.match(/<meta[^>]+http-equiv=["']?refresh["']?[^>]*content=["'][^"']*url=([^"'>\s]+)/i);
  return m ? m[1] : null;
}

function detectJsRedirect(body) {
  const m = body.match(/(?:window\.)?location(?:\.href)?\s*=\s*["']([^"']+)["']|location\.replace\(\s*["']([^"']+)["']/i);
  return m ? (m[1] || m[2]) : null;
}

function analyzeBody(status, headers, body) {
  const flags = [];
  const ct = (headers['content-type'] || '').toLowerCase();

  if (status === 401 || status === 407) flags.push({ type: 'auth', label: `Authentication required (HTTP ${status})`, requiresUser: true });
  if (status === 403) flags.push({ type: 'access-control', label: 'Access forbidden (HTTP 403) — likely an access control / anti-bot block', requiresUser: true });
  if (status === 429) flags.push({ type: 'rate-limit', label: 'Rate limited by the target (HTTP 429)', requiresUser: true });
  if (status === 402) flags.push({ type: 'paywall', label: 'Payment required (HTTP 402)', requiresUser: true });

  if (ct.includes('text/html') && body) {
    for (const sig of GATE_SIGNATURES) {
      if (sig.re.test(body)) flags.push({ type: sig.type, label: sig.label, requiresUser: true });
    }
    const meta = detectMetaRefresh(body);
    if (meta) flags.push({ type: 'meta-refresh', label: 'Meta-refresh redirect (not auto-followed)', target: meta, requiresUser: true });
    const js = detectJsRedirect(body);
    if (js) flags.push({ type: 'js-redirect', label: 'JavaScript navigation (not executed)', target: js, requiresUser: true });
  }
  // De-dup by type
  const seen = new Set();
  return flags.filter(f => (seen.has(f.type) ? false : seen.add(f.type)));
}

// ------------------------------- HTTP fetch -------------------------------- //

// Perform one request, pinned to a vetted IP, returning headers + a body sample.
function fetchOne(urlObj, ip, deadline, opts) {
  return new Promise((resolve) => {
    const isHttps = urlObj.protocol === 'https:';
    const lib = isHttps ? https : http;
    const port = urlObj.port ? Number(urlObj.port) : (isHttps ? 443 : 80);
    const remainingBudget = deadline - Date.now();
    const timeout = Math.max(1, Math.min(opts.hopTimeoutMs, remainingBudget));

    const options = {
      host: ip,                    // connect to the vetted IP (rebinding-safe)
      servername: urlObj.hostname, // SNI for TLS
      port,
      method: 'GET',
      path: urlObj.pathname + urlObj.search,
      headers: {
        Host: urlObj.host,
        'User-Agent': opts.userAgent,
        Accept: 'text/html,application/xhtml+xml,*/*;q=0.8',
        'Accept-Language': 'en',
      },
      timeout,
    };

    const started = Date.now();
    let req;
    try {
      req = lib.request(options);
    } catch (e) {
      resolve({ ok: false, error: e.message, code: e.code, elapsedMs: 0 });
      return;
    }

    req.on('response', (res) => {
      const chunks = [];
      let received = 0;
      let done = false;
      const finish = () => {
        if (done) return; done = true;
        const body = Buffer.concat(chunks).toString('utf8');
        resolve({
          ok: true,
          status: res.statusCode,
          statusMessage: res.statusMessage,
          headers: res.headers,
          body,
          elapsedMs: Date.now() - started,
        });
      };
      res.on('data', (c) => {
        received += c.length;
        if (received <= opts.maxBodyBytes) chunks.push(c);
        else res.destroy(); // stop downloading; we only sample for detection
      });
      res.on('end', finish);
      res.on('close', finish);
      res.on('error', finish);
    });

    req.on('timeout', () => { req.destroy(new Error('Request timed out')); });
    req.on('error', (e) => {
      resolve({ ok: false, error: e.message, code: e.code, elapsedMs: Date.now() - started });
    });
    req.end();
  });
}

function countSetCookie(headers) {
  const sc = headers['set-cookie'];
  if (Array.isArray(sc)) return sc.length;
  return sc ? 1 : 0;
}

// Follow the redirect chain (HTTP 3xx Location only).
async function resolveChain(startUrl, options = {}) {
  const opts = { ...DEFAULTS, ...options };
  const deadline = Date.now() + opts.budgetMs;
  const hops = [];
  const visited = new Set();
  let currentRaw = startUrl;
  let stopReason = null;

  for (let i = 0; i < opts.maxHops; i++) {
    if (Date.now() > deadline) { stopReason = 'Total time budget exceeded.'; break; }

    const v = validateUrl(currentRaw);
    if (!v.ok) { hops.push({ url: currentRaw, error: v.reason }); stopReason = v.reason; break; }

    const canon = v.url.toString();
    if (visited.has(canon)) {
      hops.push({ url: canon, error: 'Redirect loop detected.' });
      stopReason = 'Redirect loop detected.';
      break;
    }
    visited.add(canon);

    const safe = await resolveSafeIp(v.url.hostname);
    if (!safe.ok) { hops.push({ url: canon, error: safe.reason }); stopReason = safe.reason; break; }

    const res = await fetchOne(v.url, safe.ip, deadline, opts);
    if (!res.ok) {
      hops.push({ url: canon, ip: safe.ip, error: `${res.error}${res.code ? ' (' + res.code + ')' : ''}`, elapsedMs: res.elapsedMs });
      stopReason = res.error;
      break;
    }

    const rawLocation = res.headers.location;
    const isRedirect = res.status >= 300 && res.status < 400 && !!rawLocation;
    const flags = analyzeBody(res.status, res.headers, res.body);
    const retryAfter = res.headers['retry-after'] || null;

    hops.push({
      url: canon,
      ip: safe.ip,
      status: res.status,
      statusMessage: res.statusMessage,
      server: res.headers.server || null,
      contentType: res.headers['content-type'] || null,
      setCookie: countSetCookie(res.headers),
      retryAfter,
      elapsedMs: res.elapsedMs,
      flags,
      location: isRedirect ? rawLocation : null,
    });

    // If a human-action gate is detected, stop the automated chain here.
    if (flags.some(f => f.requiresUser)) {
      stopReason = 'Stopped: a step requires user action (see flags). This tool does not bypass it.';
      break;
    }

    if (isRedirect) {
      if (rawLocation.length > opts.maxLocationLength) {
        stopReason = 'Redirect target is unreasonably long; stopping.';
        break;
      }
      let next;
      try { next = new URL(rawLocation, v.url).toString(); }
      catch { stopReason = 'Invalid redirect target.'; break; }
      currentRaw = next;
      continue;
    }

    // Not a redirect and no gate => this is the final destination.
    stopReason = null;
    break;
  }

  if (hops.length >= opts.maxHops && !stopReason) {
    stopReason = `Stopped after the maximum of ${opts.maxHops} hops.`;
  }

  const last = hops[hops.length - 1];
  const completed = !!last && !last.error &&
    !(last.status >= 300 && last.status < 400) &&
    !(last.flags && last.flags.some(f => f.requiresUser));

  return {
    start: startUrl,
    finalUrl: last ? last.url : startUrl,
    hopCount: hops.length,
    completed,
    stopReason,
    hops,
  };
}

// ------------------------------ rate limiting ------------------------------ //
// Fixed-window per-key limiter. In a serverless deployment each warm instance
// keeps its own window, so this is best-effort abuse control, not a hard global
// cap (that would need a shared store such as Vercel KV / Redis).

class RateLimiter {
  constructor({ windowMs = 60_000, max = 20 } = {}) {
    this.windowMs = windowMs;
    this.max = max;
    this.buckets = new Map();
  }

  check(key) {
    const now = Date.now();
    let b = this.buckets.get(key);
    if (!b || now > b.resetAt) {
      b = { count: 0, resetAt: now + this.windowMs };
      this.buckets.set(key, b);
    }
    b.count++;
    if (b.count <= this.max) return { allowed: true };
    return { allowed: false, retryAfterSec: Math.ceil((b.resetAt - now) / 1000) };
  }

  sweep() {
    const now = Date.now();
    for (const [k, b] of this.buckets) if (now > b.resetAt) this.buckets.delete(k);
  }
}

module.exports = {
  DEFAULTS, ALLOWED_PROTOCOLS, ALLOWED_PORTS,
  validateUrl, resolveSafeIp, resolveChain, analyzeBody,
  isBlockedIp, isBlockedV4, isBlockedV6, ipv6ToBytes,
  RateLimiter,
};
