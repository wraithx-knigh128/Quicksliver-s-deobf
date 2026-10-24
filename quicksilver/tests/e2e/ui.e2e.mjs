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
}

test('page loads cleanly and lists every obfuscator', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  assert.equal(await page.locator('#toollist li').count(), 15);
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
  // the two sources stack instead of shrinking to nothing
  const [l, r] = await Promise.all([page.locator('.col').nth(0).boundingBox(), page.locator('.col').nth(1).boundingBox()]);
  assert.ok(l.height > 120 && r.height > 120, 'both panes keep a usable height');
  assert.ok(r.y >= l.y + l.height - 1, 'right pane sits below the left one');
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('the obfuscated source is on the left and the deobfuscated source on the right', { skip }, async () => {
  const { page, ctx, problems } = await newPage();
  const [l, r] = await Promise.all([page.locator('.col').nth(0).boundingBox(), page.locator('.col').nth(1).boundingBox()]);
  assert.ok(r.x > l.x + l.width - 1, 'panes are side by side');
  assert.ok(Math.abs(l.width - r.width) < 40, 'and roughly equal');
  assert.match(await page.textContent('.col:nth-of-type(1) h2'), /Obfuscated source/);
  assert.match(await page.textContent('.col:nth-of-type(2) h2'), /Deobfuscated source/);
  assert.equal(await page.isEditable('textarea.editor'), true, 'the left side takes input');
  assert.equal(await page.locator('.col:nth-of-type(2) textarea').count(), 0, 'the right side is read-only');
  assert.deepEqual(problems, []);
  await ctx.close();
});

test('opening a file names the obfuscator without pressing anything', { skip }, async () => {
  const { page, ctx } = await newPage();
  await loadFile(page, path.join(corpus, 'obfuscated/prometheus/s06_combined__step-ProxifyLocals.lua'));
  await page.waitForFunction(() => /Prometheus/.test(document.querySelector('#resultbar').textContent), null, { timeout: 15_000 });
  assert.equal(await page.isVisible('#out-empty'), true, 'nothing is recovered until asked');
  await ctx.close();
});

test('the divider resizes the panes and the theme switch is remembered', { skip }, async () => {
  const { page, ctx } = await newPage();
  const widths = async () => Promise.all([0, 1].map(async (i) => (await page.locator('.col').nth(i).boundingBox()).width));
  const [a0] = await widths();
  await page.focus('.splitter');
  for (let i = 0; i < 4; i++) await page.keyboard.press('ArrowRight');
  const [a1] = await widths();
  assert.ok(a1 > a0 + 30, 'left pane grew');
  await page.dblclick('.splitter');
  const [a2] = await widths();
  assert.ok(Math.abs(a2 - a0) < 4, 'double-click resets');

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
