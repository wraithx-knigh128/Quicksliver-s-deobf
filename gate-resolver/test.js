'use strict';

// Lightweight tests — no external network required.
const assert = require('assert');
const http = require('http');
const {
  validateUrl, isBlockedIp, isBlockedV4, isBlockedV6, analyzeBody, ipv6ToBytes,
} = require('./server.js');

let pass = 0, fail = 0;
function t(name, fn) {
  try { fn(); console.log('  ok  ' + name); pass++; }
  catch (e) { console.error('  FAIL ' + name + '\n       ' + e.message); fail++; }
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
for (const ip of ['127.0.0.1', '10.1.2.3', '192.168.1.1', '172.16.5.5', '169.254.1.1', '100.64.0.1', '0.0.0.0', '224.0.0.1', '255.255.255.255']) {
  t('blocks ' + ip, () => assert.strictEqual(isBlockedV4(ip), true));
}
for (const ip of ['8.8.8.8', '1.1.1.1', '93.184.216.34']) {
  t('allows ' + ip, () => assert.strictEqual(isBlockedV4(ip), false));
}

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
t('flags Cloudflare challenge', () => {
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
t('401 => auth required', () => {
  const f = analyzeBody(401, {}, '');
  assert.ok(f.some(x => x.type === 'auth'));
});
t('429 => rate-limit flag', () => {
  const f = analyzeBody(429, {}, '');
  assert.ok(f.some(x => x.type === 'rate-limit'));
});
t('clean page has no flags', () => {
  const f = analyzeBody(200, { 'content-type': 'text/html' }, '<h1>Hello</h1>');
  assert.strictEqual(f.length, 0);
});

// End-to-end: local server that 302-chains then serves a plain page, and one
// that serves a CAPTCHA page. Uses 127.0.0.1, so we bypass the SSRF guard only
// for this in-process test by pointing resolveChain-equivalent logic via the
// real HTTP path is not possible (127.0.0.1 is blocked by design). Instead we
// assert the guard refuses loopback, which is the correct production behavior.
console.log('end-to-end (loopback is correctly refused by SSRF guard)');
(async () => {
  const { resolveChain } = require('./server.js');
  const srv = http.createServer((req, res) => { res.writeHead(200); res.end('ok'); });
  await new Promise(r => srv.listen(0, '127.0.0.1', r));
  const port = srv.address().port;
  const result = await resolveChain('http://127.0.0.1:' + (require('./server.js').CONFIG.ALLOWED_PORTS.has(port) ? port : 8080) + '/');
  // Loopback must be refused regardless.
  t('resolveChain refuses loopback target', () => {
    assert.ok(!result.completed);
    assert.ok(/blocked|private|reserved|not allowed/i.test(result.stopReason || (result.hops[0] && result.hops[0].error) || ''));
  });
  srv.close();

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})();
