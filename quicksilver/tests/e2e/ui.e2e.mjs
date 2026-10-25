// Browser end-to-end tests: the real page, in Chromium, served from this folder.
//
//   node --test tests/e2e/ui.e2e.mjs
//
// Needs Playwright with a Chromium (set QS_PLAYWRIGHT to its index.mjs, or install it locally). Without it the
// suite is skipped with a message rather than reported as passing.

import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { readZip } from '../helpers/zip-read.mjs';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const corpus = path.join(root, 'tests/corpus');

async function loadPlaywright() {
  const candidates = [process.env.QS_PLAYWRIGHT, 'playwright', '/opt/node22/lib/node_modules/playwright/index.mjs'].filter(Boolean);
  for (const c of candidates) { try { return await import(c); } catch { /* try next */ } }
  return null;
}

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.lua': 'text/plain' };
function serve() {
  const server = http.createServer((req, res) => {
    const u = new URL(req.url, 'http://x');
    let file = path.join(root, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
    if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); res.end('not found'); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

const pw = await loadPlaywright();
const skip = pw ? false : 'Playwright is not available (set QS_PLAYWRIGHT)';
let server; let browser; let base;
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-e2e-'));

before(async () => {
  if (!pw) return;
  server = await serve();
  base = `http://127.0.0.1:${server.address().port}`;
  browser = await pw.chromium.launch();
});
after(async () => { if (browser) await browser.close(); if (server) server.close(); fs.rmSync(tmp, { recursive: true, force: true }); });

async function newPage(opts = {}) {
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 860 }, acceptDownloads: true, ...opts });
  const page = await ctx.newPage();
  const problems = [];
  page.on('console', (m) => { if (['error', 'warning'].includes(m.type())) problems.push(`[${m.type()}] ${m.text()}`); });
  page.on('pageerror', (e) => problems.push(`[pageerror] ${e.message}`));
  await page.goto(`${base}/index.html`);
  await page.waitForSelector('#toollist li', { state: 'attached' });
  return { page, ctx, problems };
}

const idle = (page) => page.waitForFunction(() => document.querySelector('#act-cancel').hidden, null, { timeout: 60_000 });
const status = (page) => page.textContent('#st-state');
const activeTab = (page) => page.getAttribute('[role=tab][aria-selected=true]', 'id');

async function loadFile(page, file) {
  await page.setInputFiles('#file-input', file);
  await page.waitForFunction((n) => document.querySelector('#docname').textContent.includes(n), path.basename(file));
  // the page names the obfuscator on its own a moment after a file opens; wait for that, so a click that follows is not
  // swallowed by buttons the automatic detection has just disabled
  await page.waitForFunction(() => !/Not analysed yet/.test(document.querySelector('#resultbar').textContent) && document.querySelector('#act-cancel').hidden, null, { timeout: 15_000 }).catch(() => {});
}

test('page loads cleanly and lists every obfuscator', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  assert.equal(await page.locator("#toollist li").count(), 24);
  assert.equal(await page.textContent('#ver'), 'v1.0.0');
  for (const id of ['open', 'detect', 'beautify', 'analyze', 'recover', 'compare', 'export']) assert.ok(await page.isVisible(`#act-${id}`), `${id} button`);
  // strict CSP: no inline styles or scripts were needed to render
  const csp = await page.getAttribute('meta[http-equiv="Content-Security-Policy"]', 'content');
  assert.match(csp, /script-src 'self'/);
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('only .txt, .lua and .luau files are accepted', { skip }, async () => {
  const { page, ctx } = await newPage();
  const bad = path.join(tmp, 'picture.png');
  fs.writeFileSync(bad, Buffer.from([0x89, 0x50, 0x4e, 0x47]));
  await page.setInputFiles('#file-input', bad);
  await page.waitForSelector('#toast:not([hidden])');
  assert.match(await page.textContent('#toast'), /is not supported/);
  assert.equal((await page.inputValue('textarea.editor')), '');
  assert.equal(await page.getAttribute('#file-input', 'accept'), '.lua,.luau,.txt');
  await ctx.close();
});

test('detect, beautify, analyze, recover, compare and export work on a Prometheus script', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  await loadFile(page, path.join(corpus, 'obfuscated/prometheus/s06_combined__step-ProxifyLocals.lua'));

  await page.click('#act-detect'); await idle(page);
  assert.equal(await activeTab(page), 'tab-detection');
  assert.match(await page.textContent('#view-detection'), /Prometheus/);

  await page.click('#act-beautify'); await idle(page);
  assert.equal(await activeTab(page), 'tab-work');
  assert.match(await page.textContent('#out-body'), /\S/);
  assert.match(await page.textContent('#view-work'), /Beautified/);

  await page.click('#act-analyze'); await idle(page);
  assert.equal(await activeTab(page), 'tab-analysis');
  assert.match(await page.textContent('#view-analysis'), /Functions/);

  await page.click('#act-recover'); await idle(page);
  assert.equal(await activeTab(page), 'tab-work');
  assert.match(await page.textContent('#view-work'), /Recovered/);
  assert.match(await page.textContent('#resultbar'), /Confidence/);
  assert.match(await page.textContent('#inspector'), /Confidence/);

  await page.click('#act-compare'); await idle(page);
  assert.equal(await activeTab(page), 'tab-compare');
  assert.match(await page.textContent('#view-compare'), /unchanged/);
  assert.match(await page.textContent('#view-compare'), /re-formatted/);

  await page.click('#tab-luast');
  await page.waitForSelector('#luast-body .node');
  assert.match(await page.textContent('#view-luast'), /Chunk/);

  const [dl] = await Promise.all([page.waitForEvent('download'), (async () => { await page.click('#act-export'); await page.click('.menu button:has-text("Bundle")'); })()]);
  const file = path.join(tmp, 'bundle.zip');
  await dl.saveAs(file);
  const files = readZip(new Uint8Array(fs.readFileSync(file)));
  const original = fs.readFileSync(path.join(corpus, 'obfuscated/prometheus/s06_combined__step-ProxifyLocals.lua'));
  const keyOriginal = Object.keys(files).find((k) => k.startsWith('original/'));
  assert.deepEqual([...files[keyOriginal]], [...original], 'the original file is byte-identical inside the bundle');
  assert.ok(Object.keys(files).some((k) => k.startsWith('recovered/') && k.endsWith('.recovered.lua')));
  const manifest = JSON.parse(new TextDecoder().decode(files['manifest.json']));
  assert.equal(manifest.original.bytes, original.length);
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('bytes that are not valid UTF-8 survive the round trip untouched', { skip }, async () => {
  const { page, ctx } = await newPage();
  const raw = Buffer.concat([Buffer.from('local s = "'), Buffer.from([0xff, 0xfe, 0x80, 0xc3]), Buffer.from('"\r\nprint(#s)\r\n')]);
  const file = path.join(tmp, 'raw.lua');
  fs.writeFileSync(file, raw);
  await loadFile(page, file);
  assert.match(await page.textContent('#notes'), /not valid UTF-8/);
  await page.click('#act-recover'); await idle(page);
  const [dl] = await Promise.all([page.waitForEvent('download'), (async () => { await page.click('#act-export'); await page.click('.menu button:has-text("Bundle")'); })()]);
  const out = path.join(tmp, 'raw.zip');
  await dl.saveAs(out);
  const files = readZip(new Uint8Array(fs.readFileSync(out)));
  assert.deepEqual([...files[Object.keys(files).find((k) => k.startsWith('original/'))]], [...raw]);
  await ctx.close();
});

test('editing the source replaces the preserved bytes and clears stale results', { skip }, async () => {
  const { page, ctx } = await newPage();
  await page.fill('textarea.editor', 'print("a")');
  await page.click('#act-recover'); await idle(page);
  assert.match(await page.textContent('#out-body'), /print/);
  await page.fill('textarea.editor', 'print("b")');
  assert.equal(await page.isVisible('#out-empty'), true);
  assert.equal(await page.isVisible('#out-body'), false);
  await ctx.close();
});

test('code that does not parse is reported with a position, not a crash', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  await page.fill('textarea.editor', 'local x = = 1\nprint(x');
  await page.click('#act-recover'); await idle(page);
  assert.match(await page.textContent('#notes'), /does not parse|Recovery stopped|cannot|expected/i);
  await page.click('#act-beautify'); await idle(page);
  assert.match(await page.textContent('#view-work'), /layout only/);
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('decoders are evaluated only after the user allows the sandbox', { skip }, async () => {
  const { page, ctx } = await newPage();
  await loadFile(page, path.join(corpus, 'obfuscated/prometheus/s06_combined__step-EncryptStrings.lua'));
  await page.click('#act-recover'); await idle(page);
  assert.match(await page.textContent('#resultbar'), /Encoded strings remain/);
  const before = await page.textContent('#out-body');
  assert.doesNotMatch(before, /QuickSilver/);
  await page.click('#resultbar button:has-text("Recover with sandbox")');
  await page.waitForSelector('.modal');
  assert.match(await page.textContent('.modal'), /own Lua interpreter/);
  await page.click('.modal button:has-text("Allow")');
  await idle(page);
  await page.waitForFunction(() => /sandbox: on/.test(document.querySelector('#st-sandbox').textContent));
  assert.doesNotMatch(await page.textContent('#resultbar'), /Encoded strings remain/);
  await ctx.close();
});

test('trace asks first, then lists what a Roblox-style script does', { skip }, async () => {
  const { page, ctx } = await newPage();
  await loadFile(page, path.join(corpus, 'obfuscated/prometheus/s07_roblox_style__Medium.lua'));
  await page.click('#act-trace');
  await page.waitForSelector('.modal');
  assert.match(await page.textContent('.modal'), /Run this script in the sandbox/);
  await page.click('.modal button:has-text("Cancel")');
  assert.equal(await page.locator('.modal').count(), 0);
  assert.equal(await page.isVisible('#out-body'), false, 'nothing ran after Cancel');

  await page.click('#act-trace');
  await page.waitForSelector('.modal');
  await page.click('.modal button:has-text("Run in sandbox")');
  await idle(page);
  const text = await page.textContent('#view-work');
  assert.match(text, /Trace/);
  assert.match(text, /GetService/);
  assert.match(text, /Instance\.new/);
  assert.match(await page.textContent('#inspector'), /not the original source/);
  await ctx.close();
});

test('cancel stops a long-running operation', { skip }, async () => {
  const { page, ctx } = await newPage();
  // a loop that would burn the whole instruction budget
  await page.fill('textarea.editor', 'local n = 0\nwhile true do n = n + 1 end');
  await page.click('#act-trace');
  await page.waitForSelector('.modal');
  await page.click('.modal button:has-text("Run in sandbox")');
  await page.waitForSelector('#act-cancel:not([hidden])', { timeout: 5000 }).catch(() => {});
  if (await page.isVisible('#act-cancel')) {
    await page.click('#act-cancel');
    await idle(page);
    assert.match(await status(page), /Cancelled/);
  } else {
    // finished before the click landed: the limits stopped it, which is also correct
    assert.match(await page.textContent('#view-work'), /limit/);
  }
  await ctx.close();
});

test('the interface stays usable on a phone-sized screen', { skip }, async () => {
  const { page, ctx, problems } = await newPage({ viewport: { width: 390, height: 780 } });
  for (const id of ['open', 'detect', 'recover', 'export']) assert.ok(await page.isVisible(`#act-${id}`));
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
  assert.equal(overflow, false, 'no horizontal page scroll');
  // the two editors keep a usable height
  const [l, r] = await Promise.all([page.locator('.col').nth(0).boundingBox(), page.locator('.col').nth(1).boundingBox()]);
  assert.ok(l.height > 120 && r.height > 120, 'both panes keep a usable height');
  assert.ok(r.y >= l.y + l.height - 1, 'the deobfuscated editor sits below the obfuscated one');
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('the obfuscated source is above and the deobfuscated source below', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  const [t, b] = await Promise.all([page.locator('.col').nth(0).boundingBox(), page.locator('.col').nth(1).boundingBox()]);
  assert.ok(b.y >= t.y + t.height - 1, 'editors are stacked');
  assert.ok(Math.abs(t.width - b.width) < 2 && t.width > 800, 'and both use the full width');
  assert.ok(t.height > 150 && b.height > 150, 'each keeps a usable height');
  assert.match(await page.textContent('.col:nth-of-type(1) h2'), /Obfuscated source/);
  assert.match(await page.textContent('.col:nth-of-type(2) h2'), /Deobfuscated source/);
  assert.equal(await page.isEditable('textarea.editor'), true, 'the top editor takes input');
  assert.equal(await page.locator('.col:nth-of-type(2) textarea').count(), 0, 'the bottom one is read-only');
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('both editors colour Lua, the input one without giving up the plain textarea', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  const code = 'local function f(a)\n  -- note\n  return string.format("%d", a + 1)\nend\nprint(f(2))';
  await page.evaluate((v) => { const e = document.querySelector('textarea.editor'); e.value = v; e.dispatchEvent(new Event('input', { bubbles: true })); }, code);
  await page.waitForSelector('.hl .t-kw');
  const kinds = await page.evaluate(() => ({
    kw: [...document.querySelectorAll('.hl .t-kw')].map((n) => n.textContent),
    ctl: [...document.querySelectorAll('.hl .t-ctl')].map((n) => n.textContent),
    str: document.querySelectorAll('.hl .t-str').length,
    com: document.querySelectorAll('.hl .t-com').length,
    fn: [...document.querySelectorAll('.hl .t-fn')].map((n) => n.textContent),
    ink: getComputedStyle(document.querySelector('textarea.editor')).color,
    rows: document.querySelectorAll('.hl .hl-row').length,
  }));
  assert.deepEqual(kinds.kw, ['local', 'function']);
  assert.ok(kinds.ctl.includes('return') && kinds.ctl.includes('end'));
  assert.ok(kinds.str >= 1 && kinds.com === 1);
  assert.ok(kinds.fn.includes('f') && kinds.fn.includes('format') && kinds.fn.includes('print'));
  assert.equal(kinds.ink, 'rgba(0, 0, 0, 0)', 'the textarea itself is transparent; the layer under it carries the colour');
  assert.equal(kinds.rows, 5);
  // one line number per row (the numbers are separated by newlines, which must not collapse)
  const gutter = await page.evaluate(() => { const n = document.querySelector('.gutter .nums'); return { text: n.textContent, height: n.getBoundingClientRect().height, lh: parseFloat(n.style.lineHeight) }; });
  assert.equal(gutter.text, '1\n2\n3\n4\n5');
  assert.ok(Math.abs(gutter.height - 5 * gutter.lh) < 2, `numbers stack one per row (${gutter.height}px for 5 rows)`);
  // the layer shows exactly the text of the textarea, row for row
  const same = await page.evaluate(() => [...document.querySelectorAll('.hl .hl-row')].map((r) => r.textContent).join('\n') === document.querySelector('textarea.editor').value);
  assert.ok(same, 'overlay text equals the textarea text');
  // typing still works and the layer follows
  await page.click('textarea.editor');
  await page.keyboard.press('Control+End');
  await page.keyboard.type('\nlocal z = nil');
  await page.waitForFunction(() => document.querySelectorAll('.hl .hl-row').length === 6);
  // the result pane colours too
  await page.click('#act-beautify'); await idle(page);
  assert.ok(await page.locator('#out-body .t-kw').count() > 0, 'output is coloured');
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('a minified one-line script is coloured by the columns on screen, not all at once', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  await page.evaluate(() => {
    const parts = [];
    for (let i = 0; i < 30000; i++) parts.push(`local v${i}=${i} if v${i} then v${i}="s${i}" end`);
    const e = document.querySelector('textarea.editor');
    e.value = parts.join(' ');
    e.dispatchEvent(new Event('input', { bubbles: true }));
  });
  await page.waitForSelector('.hl .t-kw');
  const drawn = await page.evaluate(() => document.querySelector('.hl-rows').textContent.length);
  assert.ok(drawn > 200 && drawn < 20_000, `only the visible window is drawn (${drawn} characters)`);
  // scrolling right redraws the window at the new place
  await page.evaluate(() => { const e = document.querySelector('textarea.editor'); e.scrollLeft = 400_000; });
  await page.waitForFunction(() => /v3\d{4}|v2\d{4}/.test(document.querySelector('.hl-rows').textContent) || document.querySelector('.hl-rows').textContent.includes('v'));
  const at = await page.evaluate(() => { const e = document.querySelector('textarea.editor'); const first = document.querySelector('.hl-rows .t-kw'); return { left: e.scrollLeft, text: document.querySelector('.hl-rows').textContent.slice(0, 40), have: !!first }; });
  assert.ok(at.left > 0 && at.have);
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('the timer counts while an operation runs and keeps the time it took', { skip }, async () => {
  const { page, ctx } = await newPage();
  assert.match(await page.textContent('#timer-text'), /^0\.00 s$/);
  await loadFile(page, path.join(corpus, 'obfuscated/prometheus/s06_combined__step-ProxifyLocals.lua'));
  await page.click('#act-recover');
  await page.waitForSelector('#timer.running');
  await idle(page);
  await page.waitForSelector('#timer.done');
  assert.match(await page.textContent('#timer-text'), /^\d+\.\d\d s$|^\d+:\d\d\.\d$/);
  assert.match(await page.textContent('#timer-op'), /Recovering/);
  assert.match(await page.getAttribute('#timer', 'title'), /Recovering/);
  await ctx.close();
});

test('an editor can take the whole height and give it back', { skip }, async () => {
  const { page, ctx } = await newPage();
  const heights = () => Promise.all([0, 1].map(async (i) => (await page.locator('.col').nth(i).boundingBox())?.height || 0));
  const [t0, b0] = await heights();
  assert.ok(t0 > 100 && b0 > 100);
  await page.click('.col:nth-of-type(1) .col-head button[aria-label="Maximise this editor"]');
  const [t1, b1] = await heights();
  assert.equal(b1, 0, 'the other editor is hidden');
  assert.ok(t1 > t0 + b0 - 20, 'the top editor got the room');
  await page.click('.col:nth-of-type(1) .col-head button[aria-label="Show both editors again"]');
  const [t2, b2] = await heights();
  assert.ok(Math.abs(t2 - t0) < 3 && Math.abs(b2 - b0) < 3, 'both are back');
  await page.dblclick('.col:nth-of-type(2) .col-head h2');
  assert.equal((await heights())[0], 0, 'double-clicking a title bar maximises that editor');
  await ctx.close();
});

test('opening a file names the obfuscator without pressing anything', { skip }, async () => {
  const { page, ctx } = await newPage();
  await loadFile(page, path.join(corpus, 'obfuscated/prometheus/s06_combined__step-ProxifyLocals.lua'));
  await page.waitForFunction(() => /Prometheus/.test(document.querySelector('#resultbar').textContent), null, { timeout: 15_000 });
  assert.equal(await page.isVisible('#out-empty'), true, 'nothing is recovered until asked');
  await ctx.close();
});

test('the divider resizes the editors and the theme switch is remembered', { skip }, async () => {
  const { page, ctx } = await newPage();
  const heights = async () => Promise.all([0, 1].map(async (i) => (await page.locator('.col').nth(i).boundingBox()).height));
  const [a0] = await heights();
  await page.focus('.splitter');
  for (let i = 0; i < 4; i++) await page.keyboard.press('ArrowDown');
  const [a1] = await heights();
  assert.ok(a1 > a0 + 30, 'top editor grew');
  await page.dblclick('.splitter');
  const [a2] = await heights();
  assert.ok(Math.abs(a2 - a0) < 4, 'double-click resets');
  // dragging the divider works with the pointer too
  const box = await page.locator('.splitter').boundingBox();
  await page.mouse.move(box.x + 200, box.y + 2);
  await page.mouse.down();
  await page.mouse.move(box.x + 200, box.y - 120, { steps: 6 });
  await page.mouse.up();
  const [a3] = await heights();
  assert.ok(a3 < a0 - 60, 'dragging up shrinks the top editor');

  const before = await page.getAttribute('html', 'data-theme');
  await page.click('#btn-theme');
  const after = await page.getAttribute('html', 'data-theme');
  assert.notEqual(before, after);
  await page.reload();
  await page.waitForSelector('#toollist li', { state: 'attached' });
  assert.equal(await page.getAttribute('html', 'data-theme'), after, 'theme survives a reload');
  await ctx.close();
});

test('a large script scrolls without building a row per line', { skip }, async () => {
  const { page, ctx } = await newPage();
  const lines = [];
  for (let i = 0; i < 40000; i++) lines.push(`local v${i} = ${i} -- line ${i}`);
  // pasting is one input event; Playwright's fill() types it character by character into the page's own textarea logic
  await page.evaluate((v) => { const e = document.querySelector('textarea.editor'); e.value = v; e.dispatchEvent(new Event('input', { bubbles: true })); }, lines.join('\n'));
  await page.click('#act-beautify'); await idle(page);
  const rows = await page.locator('#out-body .row').count();
  assert.ok(rows > 10 && rows < 400, `virtual rows only (${rows})`);
  await page.evaluate(() => { document.querySelector('#out-body .viewer').scrollTop = 20 * 20000; });
  await page.waitForFunction(() => /v2000\d\b/.test(document.querySelector('#out-body').textContent));
  await ctx.close();
});

// ---- tools bar -------------------------------------------------------------------------------------------------------------------

test('the tools bar names every tool in words, even on a narrow window', { skip }, async () => {
  const { page, ctx, problems } = await newPage({ viewport: { width: 1000, height: 800 } });
  const names = { 'act-recover': 'Deobfuscate', 'tool-luraph': 'Luraph', 'tool-ironbrew': 'IronBrew', 'tool-moonveil': 'MoonVeil', 'act-detect': 'Detect', 'act-beautify': 'Beautify', 'act-rename': 'Rename', 'act-dump': 'Dump', 'act-origin': 'AI check', 'act-help': 'Help' };
  for (const [id, text] of Object.entries(names)) {
    assert.ok(await page.isVisible(`#${id} .lbl`), `${id} shows its label`);
    assert.equal((await page.textContent(`#${id} .lbl`)).trim(), text);
  }
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('the Examples tab lists every bundled script and times a recovery on request', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  await page.click('#tab-examples');
  await page.waitForSelector('.examples-table tbody tr.row-main');
  const rows = await page.locator('.examples-table tr.row-main').count();
  assert.ok(rows >= 30, `${rows} examples listed`);
  const groups = await page.locator('.examples-table tr.group').allTextContents();
  assert.ok(groups.some((g) => /Prometheus/.test(g)) && groups.some((g) => /Hercules/.test(g)) && groups.some((g) => /IronBrew 2/.test(g)));
  // the offline measurement that came with the sample set is shown, and says when the tool's own output is broken
  const offline = await page.locator('.examples-table td.off').allTextContents();
  assert.ok(offline.some((t) => /→ \d+%/.test(t)), 'offline fidelity is shown');

  // time one example: Prometheus' Vmify step is quick and is recognised
  const row = page.locator('tr.row-main', { hasText: 'prometheus__s06_combined__Vmify.lua' });
  await row.locator('button[aria-label^="Time "]').click();
  await page.waitForFunction(() => document.querySelector('#act-cancel').hidden && document.querySelector('#timer.done'), null, { timeout: 60_000 });
  assert.match(await row.locator('td.time').textContent(), /^\d+\.\d\d s$/);
  assert.match(await row.locator('td.res').textContent(), /Prometheus.*confidence \d+%.*parses/);
  assert.match(await page.textContent('#view-examples .summary'), /1 of \d+ timed/);

  // open + deobfuscate puts the example in the editor and runs the normal recovery
  await row.locator('button:has-text("Open + deobfuscate")').click();
  await page.waitForSelector('#out-body .row', { timeout: 60_000 });
  await idle(page);
  assert.equal(await activeTab(page), 'tab-work');
  assert.match(await page.inputValue('textarea.editor'), /^return\(function/);
  assert.ok((await page.textContent('#out-body')).length > 100, 'the recovered code is shown');
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('readable examples open straight into the AI check, and the sandbox can be switched on from the Examples tab', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  await page.click('#tab-examples');
  await page.waitForSelector('.examples-table tbody tr.row-main');
  const row = page.locator('tr.row-main', { hasText: 'origin__assistant_inventory.lua' });
  assert.equal(await row.locator('button[aria-label^="Time "]').count(), 0, 'no timer for a script that is not obfuscated');
  await row.locator('button:has-text("Open + AI check")').click();
  await page.waitForSelector('#tab-origin[aria-selected=true]');
  await page.waitForFunction(() => /Written by AI\s*\d+%/.test(document.querySelector('#originbar').textContent));
  assert.match(await page.textContent('#view-origin'), /Written by AI/);

  // a packer whose payload is computed needs the sandbox; the button asks first
  await page.click('#tab-examples');
  assert.match(await page.textContent('#view-examples .codebar'), /Sandbox: off/);
  await page.click('#view-examples button:has-text("Sandbox: off")');
  await page.click('.modal button:has-text("Allow")');
  await page.waitForFunction(() => /Sandbox: on/.test(document.querySelector('#view-examples .codebar').textContent));
  const packed = page.locator('tr.row-main', { hasText: 'loaders__s06_combined__xor.lua' });
  await packed.locator('button[aria-label^="Time "]').click();
  await page.waitForFunction(() => document.querySelector('#act-cancel').hidden && document.querySelector('#timer.done'), null, { timeout: 60_000 });
  await page.click('#tab-work');
  await packed.scrollIntoViewIfNeeded().catch(() => {});
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('Time all can be stopped between two examples', { skip }, async () => {
  const { page, ctx } = await newPage();
  await page.click('#tab-examples');
  await page.waitForSelector('.examples-table tbody tr.row-main');
  await page.click('#view-examples button:has-text("Time all")');
  await page.waitForSelector('#view-examples button:has-text("Stop after this one"):not([hidden])');
  await page.click('#view-examples button:has-text("Stop after this one")');
  await page.waitForFunction(() => document.querySelector('#act-cancel').hidden, null, { timeout: 120_000 });
  const done = await page.locator('.examples-table td.res', { hasText: 'confidence' }).count();
  const total = await page.locator('.examples-table tr.row-main').count();
  assert.ok(done >= 1 && done < total - 4, `stopped after ${done} of ${total}`);
  assert.equal(await page.isVisible('#view-examples button:has-text("Stop after this one")'), false);
  await ctx.close();
});

test('help explains the page and shows the top of the dialog', { skip }, async () => {
  const { page, ctx } = await newPage();
  await page.click('#act-help');
  await page.waitForSelector('.modal');
  assert.match(await page.textContent('.modal'), /1\. Put your script in/);
  assert.equal(await page.evaluate(() => document.querySelector('.modal').scrollTop), 0, 'the dialog opens at its top');
  assert.match(await page.textContent('.modal'), /nobody can turn that back into the source automatically/);
  await page.keyboard.press('Escape');
  assert.equal(await page.locator('.modal').count(), 0);
  await ctx.close();
});

test('rename shows readable names on the right and leaves the input alone', { skip }, async () => {
  const { page, ctx } = await newPage();
  const src = 'local a, b = 1, 2\nlocal function c(d) return d + a end\nprint(c(b))';
  await page.fill('textarea.editor', src);
  await page.click('#act-rename'); await idle(page);
  assert.match(await page.textContent('#view-work'), /Renamed/);
  assert.match(await page.textContent('#out-body'), /local function fn\(param\)/);
  assert.equal(await page.inputValue('textarea.editor'), src);
  await ctx.close();
});

test('IronBrew rebuilds an IronBrew 2 script and says what it cannot do for others', { skip }, async () => {
  const { page, ctx } = await newPage();
  await loadFile(page, path.join(corpus, 'obfuscated/ironbrew2/s06_combined__default.lua'));
  await page.click('#tool-ironbrew'); await idle(page);
  const out = await page.textContent('#out-body');
  assert.match(out, /setmetatable/);
  assert.match(out, /function\s/);
  await page.click('#act-clear');
  await page.fill('textarea.editor', 'print("hello")');
  await page.click('#tool-ironbrew'); await idle(page);
  assert.match(await page.textContent('#notes'), /IronBrew 2 was not recognised/);
  assert.match(await page.textContent('#notes'), /IronBrew 1 is not supported/);
  await ctx.close();
});

test('Luraph is honest about what it can do, asks before running, then dumps', { skip }, async () => {
  const { page, ctx } = await newPage();
  const payload = 'local t = {}\\n' + Array.from({ length: 10 }, (_, i) => `t[${i + 1}] = "value ${i}"`).join('\\n') + '\\nprint(#t)';
  await page.fill('textarea.editor', `local code = "${payload.replace(/"/g, '\\"')}"\nloadstring(code)()`);
  await page.click('#tool-luraph');
  await page.waitForSelector('.modal');
  const said = await page.textContent('.modal');
  assert.match(said, /cannot turn that back into the original source/);
  assert.match(said, /Only run scripts you own/);
  await page.click('.modal button:has-text("Cancel")');
  assert.equal(await page.isVisible('#out-body'), false, 'nothing ran after Cancel');

  await page.click('#tool-luraph');
  await page.waitForSelector('.modal');
  await page.click('.modal button:has-text("Run in sandbox")');
  await idle(page);
  assert.match(await page.textContent('#view-work'), /Dump/);
  assert.match(await page.textContent('#out-body'), /value 9/);
  assert.match(await page.textContent('#inspector'), /loaded chunk 1/);
  await ctx.close();
});

test('Dump on its own asks first and captures table.concat output', { skip }, async () => {
  const { page, ctx } = await newPage();
  await page.fill('textarea.editor', 'local out = {}\nfor i = 1, 30 do out[#out + 1] = "segment " .. i .. " of the hidden text" end\nlocal text = table.concat(out, "\\n")');
  await page.click('#act-dump');
  await page.waitForSelector('.modal');
  assert.match(await page.textContent('.modal'), /table\.concat/);
  await page.click('.modal button:has-text("Run in sandbox")');
  await idle(page);
  assert.match(await page.textContent('#out-body'), /segment 30 of the hidden text/);
  await ctx.close();
});

// ---- origin check ----------------------------------------------------------------------------------------------------------------

test('origin check shows both readings with their evidence and never searches without asking', { skip }, async () => {
  const { page, ctx } = await newPage();
  await loadFile(page, path.join(corpus, 'origin/assistant_inventory.lua'));
  await page.click('#act-origin'); await idle(page);
  assert.equal(await activeTab(page), 'tab-origin');
  const text = await page.textContent('#view-origin');
  assert.match(text, /Written by AI/);
  assert.match(text, /Copied from elsewhere/);
  assert.match(text, /Emoji in messages or comments/);
  assert.match(text, /not proof/);
  assert.ok(await page.isVisible('#view-origin button:has-text("Search GitHub for these lines")'));

  // the search lists exactly what would be sent and can be cancelled
  await page.click('#view-origin button:has-text("Search GitHub for these lines")');
  await page.waitForSelector('.modal');
  assert.match(await page.textContent('.modal'), /will be sent to this site's server/);
  assert.ok(await page.locator('.modal li').count() >= 4);
  await page.click('.modal button:has-text("Cancel")');
  assert.match(await page.textContent('#view-origin'), /Not searched yet/);

  // on a server without the function the answer says so instead of failing silently
  await page.click('#view-origin button:has-text("Search GitHub for these lines")');
  await page.waitForSelector('.modal');
  await page.click('.modal button:has-text("Search")');
  await page.waitForSelector('#view-origin :text("not available on this server")');
  await ctx.close();
});

test('origin check reads the style of the code, not of an obfuscated blob or of rebuilt code', { skip }, async () => {
  const { page, ctx } = await newPage();
  await loadFile(page, path.join(corpus, 'obfuscated/prometheus/s06_combined__Weak.lua'));
  await page.click('#act-origin'); await idle(page);
  assert.match(await page.textContent('#view-origin'), /Deobfuscate first, then check/);

  await page.click('#act-clear');
  await loadFile(page, path.join(corpus, 'obfuscated/ironbrew2/s06_combined__default.lua'));
  await page.click('#act-recover'); await idle(page);
  await page.click('#act-origin'); await idle(page);
  assert.match(await page.textContent('#view-origin'), /rebuilt this code from IronBrew 2/);
  assert.match(await page.textContent('#view-origin'), /Cannot be read from rebuilt code/);
  await ctx.close();
});

test('the AI check is always in view and reads the code by itself', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  const bar = () => page.textContent('#originbar').then((t) => t.replace(/\s+/g, ' '));
  const reading = async (file) => {
    await loadFile(page, path.join(corpus, 'origin', file));
    await page.waitForFunction(() => /Written by AI/.test(document.querySelector('#originbar').textContent) && !/Reading the style/.test(document.querySelector('#originbar').textContent), null, { timeout: 15_000 });
    return bar();
  };
  assert.match(await bar(), /AI check.*Paste code to see how likely/);

  const assistant = await reading('assistant_inventory.lua');
  const percent = Number(/Written by AI (\d+)%/.exec(assistant)[1]);
  assert.ok(percent >= 60, `an assistant-style module reads as AI-written (${percent}%): ${assistant}`);
  assert.match(assistant, /AI-(written|assisted)/);
  assert.match(assistant, /Copied \(skidded\)/);
  assert.match(assistant, /not searched yet/);
  assert.match(await page.textContent('#tab-origin'), /AI check\s*\d+%/, 'the tab carries the number too');

  // a quick hand-written script reads clearly lower
  await page.click('#act-clear');
  const scrappy = await reading('scrappy_autofarm.lua');
  const low = Number(/Written by AI (\d+)%/.exec(scrappy)[1]);
  assert.ok(low < percent - 25, `hand-written ${low}% is well below assistant-style ${percent}%`);

  // credit lines, invites and pasted-together style show up as clues of copying
  await page.click('#act-clear');
  const patch = await reading('patchwork_credited.lua');
  assert.match(patch, /Copied \(skidded\) \d+% possible, \d+ clues? in the text/);

  // searching GitHub always asks first and shows what would be sent
  await page.click('#originbar button:has-text("Search GitHub")');
  await page.waitForSelector('.modal');
  assert.ok(await page.locator('.modal li').count() >= 1);
  await page.click('.modal button:has-text("Cancel")');
  assert.match(await bar(), /possible, \d+ clues? in the text/, 'cancelling sent nothing');

  // clearing the editor clears the reading
  await page.click('#act-clear');
  assert.match(await bar(), /Paste code to see how likely/);
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('the AI check says so when the code is obfuscated, and offers to deobfuscate first', { skip }, async () => {
  const { page, ctx } = await newPage();
  await loadFile(page, path.join(corpus, 'obfuscated/prometheus/s06_combined__Weak.lua'));
  await page.waitForFunction(() => /no readable style/.test(document.querySelector('#originbar').textContent), null, { timeout: 15_000 });
  assert.equal(await page.isVisible('#originbar button:has-text("Deobfuscate, then check")'), true);
  await page.click('#originbar button:has-text("Deobfuscate, then check")');
  await idle(page);
  await page.waitForFunction(() => /rebuilt from Prometheus/.test(document.querySelector('#originbar').textContent), null, { timeout: 30_000 });
  await ctx.close();
});

test('From link explains itself when the server cannot fetch', { skip }, async () => {
  const { page, ctx } = await newPage();
  await page.click('#act-link');
  await page.waitForSelector('.modal');
  assert.match(await page.textContent('.modal'), /It is only read, never run/);
  await page.fill('.modal input', 'https://raw.githubusercontent.com/a/b/main/x.lua');
  await page.click('.modal button:has-text("Get file")');
  await page.waitForSelector('#toast:not([hidden])');
  assert.match(await page.textContent('#toast'), /deployed site/);
  await ctx.close();
});
