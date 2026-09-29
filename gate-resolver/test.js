'use strict';

// Tests — no external network required. Run: node test.js
const assert = require('assert');
const { EventEmitter } = require('events');

const {
  validateUrl, isBlockedIp, isBlockedV4, isBlockedV6, analyzeBody, ipv6ToBytes,
  RateLimiter, resolveChain, ALLOWED_PORTS,
} = require('./api/_lib/resolver.js');
const { createResolveHandler } = require('./api/_lib/handler.js');

let pass = 0, fail = 0;
function t(name, fn) {
  try { fn(); console.log('  ok  ' + name); pass++; }
  catch (e) { console.error('  FAIL ' + name + '\n       ' + (e && e.message)); fail++; }
}

console.log('URL validation');
t('rejects non-http protocol', () => assert.strictEqual(validateUrl('ftp://x.com').ok, false));
t('rejects file://', () => assert.strictEqual(validateUrl('file:///etc/passwd').ok, false));
t('rejects javascript:', () => assert.strictEqual(validateUrl('javascript:alert(1)').ok, false));
t('rejects credentials in URL', () => assert.strictEqual(validateUrl('http://u:p@x.com').ok, false));
t('rejects disallowed port', () => assert.strictEqual(validateUrl('http://x.com:22').ok, false));
t('accepts plain https', () => assert.strictEqual(validateUrl('https://example.com/a?b=1').ok, true));
t('accepts explicit :443', () => assert.strictEqual(validateUrl('https://example.com:443/').ok, true));

console.log('IPv4 SSRF ranges');
for (const ip of ['127.0.0.1', '10.1.2.3', '192.168.1.1', '172.16.5.5', '169.254.169.254', '100.64.0.1', '0.0.0.0', '224.0.0.1', '255.255.255.255']) {
  t('blocks ' + ip, () => assert.strictEqual(isBlockedV4(ip), true));
}
for (const ip of ['8.8.8.8', '1.1.1.1', '93.184.216.34']) {
  t('allows ' + ip, () => assert.strictEqual(isBlockedV4(ip), false));
}
t('rejects malformed v4 (leading zeros/oversize handled)', () => assert.strictEqual(isBlockedV4('999.1.1.1'), true));

console.log('IPv6 SSRF ranges');
t('blocks ::1 loopback', () => assert.strictEqual(isBlockedV6('::1'), true));
t('blocks fe80:: link-local', () => assert.strictEqual(isBlockedV6('fe80::1'), true));
t('blocks fc00:: ULA', () => assert.strictEqual(isBlockedV6('fc00::1'), true));
t('blocks fd12:: ULA', () => assert.strictEqual(isBlockedV6('fd12:3456::1'), true));
t('blocks :: unspecified', () => assert.strictEqual(isBlockedV6('::'), true));
t('blocks ff02:: multicast', () => assert.strictEqual(isBlockedV6('ff02::1'), true));
t('blocks ::ffff:127.0.0.1 mapped', () => assert.strictEqual(isBlockedV6('::ffff:127.0.0.1'), true));
t('blocks ::ffff:10.0.0.1 mapped', () => assert.strictEqual(isBlockedV6('::ffff:10.0.0.1'), true));
t('allows 2606:4700:4700::1111', () => assert.strictEqual(isBlockedV6('2606:4700:4700::1111'), false));
t('allows ::ffff:8.8.8.8 mapped-public', () => assert.strictEqual(isBlockedV6('::ffff:8.8.8.8'), false));

console.log('isBlockedIp dispatch');
t('non-IP hostname blocked', () => assert.strictEqual(isBlockedIp('example.com'), true));
t('public v4 allowed', () => assert.strictEqual(isBlockedIp('8.8.8.8'), false));

console.log('ipv6 parser');
t('parses expanded form', () => assert.deepStrictEqual(ipv6ToBytes('0:0:0:0:0:0:0:1').slice(-1), [1]));
t('rejects garbage', () => assert.strictEqual(ipv6ToBytes('nope::zz'), null));

console.log('gate detection (label only, never bypass)');
t('flags reCAPTCHA', () => {
  const f = analyzeBody(200, { 'content-type': 'text/html' }, '<div class="g-recaptcha" data-sitekey="x"></div>');
  assert.ok(f.some(x => x.type === 'captcha' && x.requiresUser));
});
t('flags Cloudflare challenge + 403 access-control', () => {
  const f = analyzeBody(403, { 'content-type': 'text/html' }, 'Checking your browser before accessing');
  assert.ok(f.some(x => x.type === 'anti-bot'));
  assert.ok(f.some(x => x.type === 'access-control'));
});
t('flags login wall', () => {
  const f = analyzeBody(200, { 'content-type': 'text/html' }, '<input type="password" name="password">');
  assert.ok(f.some(x => x.type === 'auth' && x.requiresUser));
});
t('flags ad-gate', () => {
  const f = analyzeBody(200, { 'content-type': 'text/html' }, '<a href="https://linkvertise.com/123">unlock</a>');
  assert.ok(f.some(x => x.type === 'ad-gate'));
});
t('flags meta-refresh with target, not followed', () => {
  const f = analyzeBody(200, { 'content-type': 'text/html' }, '<meta http-equiv="refresh" content="0;url=https://dest.example/next">');
  const mr = f.find(x => x.type === 'meta-refresh');
  assert.ok(mr && mr.target === 'https://dest.example/next' && mr.requiresUser);
});
t('flags JS redirect, not executed', () => {
  const f = analyzeBody(200, { 'content-type': 'text/html' }, '<script>window.location.href="https://dest.example/x"</script>');
  assert.ok(f.some(x => x.type === 'js-redirect' && x.requiresUser));
});
t('401 => auth required', () => assert.ok(analyzeBody(401, {}, '').some(x => x.type === 'auth')));
t('429 => rate-limit flag', () => assert.ok(analyzeBody(429, {}, '').some(x => x.type === 'rate-limit')));
t('clean page has no flags', () => assert.strictEqual(analyzeBody(200, { 'content-type': 'text/html' }, '<h1>Hello</h1>').length, 0));

console.log('rate limiter');
t('allows up to max then blocks', () => {
  const rl = new RateLimiter({ windowMs: 1000, max: 3 });
  assert.strictEqual(rl.check('a').allowed, true);
  assert.strictEqual(rl.check('a').allowed, true);
  assert.strictEqual(rl.check('a').allowed, true);
  const fourth = rl.check('a');
  assert.strictEqual(fourth.allowed, false);
  assert.ok(fourth.retryAfterSec >= 0);
});
t('keys are independent', () => {
  const rl = new RateLimiter({ windowMs: 1000, max: 1 });
  assert.strictEqual(rl.check('a').allowed, true);
  assert.strictEqual(rl.check('b').allowed, true);
});

console.log('resolveChain SSRF refusal (no network)');
(async () => {
  const r1 = await resolveChain('http://169.254.169.254/latest/meta-data/');
  t('refuses cloud-metadata IP', () => {
    assert.strictEqual(r1.completed, false);
    assert.ok(/blocked|private|reserved/i.test(r1.stopReason || (r1.hops[0] && r1.hops[0].error) || ''));
  });
  const r2 = await resolveChain('http://127.0.0.1:8080/');
  t('refuses loopback', () => {
    assert.strictEqual(r2.completed, false);
    assert.ok(/blocked|private|reserved|not allowed/i.test(r2.stopReason || (r2.hops[0] && r2.hops[0].error) || ''));
  });

  console.log('handler (mock req/res, no network)');
  await runHandlerTests();

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})();

// --- handler harness -------------------------------------------------------- //

function mockReq({ method = 'POST', body, headers = {} } = {}) {
  const req = new EventEmitter();
  req.method = method;
  req.headers = headers;
  req.socket = { remoteAddress: '203.0.113.9' };
  req.destroy = () => {};
  // Emit body on next tick unless the platform pre-parsed it.
  if (body !== undefined && typeof body !== 'object') {
    process.nextTick(() => { req.emit('data', Buffer.from(body)); req.emit('end'); });
  } else if (body && typeof body === 'object') {
    req.body = body; // simulate platform-parsed JSON
  } else {
    process.nextTick(() => req.emit('end'));
  }
  return req;
}

function mockRes() {
  return {
    statusCode: null, headers: {}, body: '',
    setHeader(k, v) { this.headers[k] = v; },
    writeHead(code, hdrs) { this.statusCode = code; Object.assign(this.headers, hdrs || {}); return this; },
    end(chunk) { if (chunk) this.body += chunk; this.done = true; },
  };
}

function call(handler, reqOpts) {
  const req = mockReq(reqOpts);
  const res = mockRes();
  return new Promise((resolve) => {
    const iv = setInterval(() => { if (res.done) { clearInterval(iv); resolve(res); } }, 5);
    handler(req, res);
  });
}

async function runHandlerTests() {
  const handler = createResolveHandler({ rateLimiter: new RateLimiter({ windowMs: 60000, max: 100 }) });

  let res = await call(handler, { method: 'GET' });
  t('GET => 405', () => { assert.strictEqual(res.statusCode, 405); assert.strictEqual(res.headers.Allow, 'POST'); });

  res = await call(handler, { body: '{}' });
  t('missing url => 400', () => { assert.strictEqual(res.statusCode, 400); assert.ok(/url/i.test(res.body)); });

  res = await call(handler, { body: 'not json' });
  t('bad JSON => 400', () => assert.strictEqual(res.statusCode, 400));

  res = await call(handler, { body: JSON.stringify({ url: 'file:///etc/passwd' }) });
  t('bad protocol => 400', () => assert.strictEqual(res.statusCode, 400));

  res = await call(handler, { body: { url: 'http://169.254.169.254/' } });
  t('pre-parsed body + SSRF target => 200 with refusal', () => {
    assert.strictEqual(res.statusCode, 200);
    const j = JSON.parse(res.body);
    assert.strictEqual(j.completed, false);
  });

  const limited = createResolveHandler({ rateLimiter: new RateLimiter({ windowMs: 60000, max: 1 }) });
  await call(limited, { body: JSON.stringify({ url: 'file:///x' }) }); // consumes the 1 allowed
  res = await call(limited, { body: JSON.stringify({ url: 'file:///x' }) });
  t('over rate limit => 429 with Retry-After', () => {
    assert.strictEqual(res.statusCode, 429);
    assert.ok(res.headers['Retry-After'] !== undefined);
  });
}
