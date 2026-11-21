#!/usr/bin/env node
// Prompt XXVII Part VII/IX, updated for Prompt XXVIII: how the v1.8 interface performs, measured in Chromium.
//
// For the Deobfuscate page (the supplied artwork drifting behind it), the same page during a run (the stage rail updating) and Expert tools (the
// backdrop paused), on a desktop viewport and on a phone viewport with a 4× CPU slowdown:
//   fps            frames the page produced in a 5 s window (requestAnimationFrame count / 5)
//   longFrames     frames that took more than 50 ms
//   layouts/paints Layout and Paint events in the trace during the window: a compositor-only animation causes none of either
//   mainThreadMs   main-thread task time during the window (CDP Performance.TaskDuration)
//   fcp / lcp / cls first contentful paint, largest contentful paint, cumulative layout shift of the load
//   bytes          sum of the decoded sizes of everything the page loaded (scripts, styles, fonts, art)
//
//   node tools/perf/measure-ui.mjs [--out docs/perf-xxvii.json]
// Needs Playwright with Chromium (pre-installed in this environment). Serves the repository itself on a free port.

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
let chromium;
for (const c of [process.env.QS_PLAYWRIGHT, 'playwright', '/opt/node22/lib/node_modules/playwright'].filter(Boolean)) { try { ({ chromium } = require(c)); break; } catch { /* next */ } }
if (!chromium) { console.error('Playwright is not available.'); process.exit(2); }

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.lua': 'text/plain', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  const p = path.join(root, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
  if (!p.startsWith(root) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(p)] || 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch();

async function measure({ name, viewport, cpu = 1, screen }) {
  const ctx = await browser.newContext({ viewport, deviceScaleFactor: 1 });
  if (screen === 'work') await ctx.addInitScript(() => { try { sessionStorage.setItem('qs.expert', '1'); } catch { /* ignore */ } });
  await ctx.addInitScript(() => {
    window.__qs = { lcp: 0, cls: 0, long: 0 };
    new PerformanceObserver((l) => { for (const e of l.getEntries()) window.__qs.lcp = e.startTime; }).observe({ type: 'largest-contentful-paint', buffered: true });
    new PerformanceObserver((l) => { for (const e of l.getEntries()) if (!e.hadRecentInput) window.__qs.cls += e.value; }).observe({ type: 'layout-shift', buffered: true });
  });
  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);
  if (cpu > 1) await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu });
  await cdp.send('Performance.enable');
  await page.goto(`${base}/index.html`);
  await page.waitForLoadState('load');
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(1500);   // the entrance animation finishes; what is measured next is the steady state
  if (screen === 'running') {          // a deobfuscation in progress: the stage rail and its pulse are what moves
    const src = fs.readFileSync(path.join(root, 'tests/corpus/obfuscated/zartha/s07_roblox_style__constants.lua'), 'utf8');
    await page.fill('#deob-text', src.repeat(4));
    await page.click('#deob-run');
    await page.waitForTimeout(200);
  }
  const m0 = Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map((x) => [x.name, x.value]));
  await browser.startTracing(page, { categories: ['devtools.timeline'] });
  const frames = await page.evaluate(() => new Promise((resolve) => {
    let n = 0; let long = 0; let last = performance.now(); const end = last + 5000;
    const tick = (t) => { n++; if (t - last > 50) long++; last = t; if (t < end) requestAnimationFrame(tick); else resolve({ n, long }); };
    requestAnimationFrame(tick);
  }));
  const trace = JSON.parse((await browser.stopTracing()).toString('utf8'));
  const m1 = Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map((x) => [x.name, x.value]));
  const events = trace.traceEvents || [];
  const count = (nm) => events.filter((e) => e.name === nm && e.ph !== 'E').length;
  const vitals = await page.evaluate(() => ({ fcp: (performance.getEntriesByName('first-contentful-paint')[0] || {}).startTime || null, lcp: window.__qs.lcp, cls: window.__qs.cls, bytes: performance.getEntriesByType('resource').reduce((a, r) => a + (r.decodedBodySize || 0), 0) + (performance.getEntriesByType('navigation')[0]?.decodedBodySize || 0), animations: document.getAnimations().filter((a) => a.playState === 'running').length }));
  await ctx.close();
  return {
    name, viewport: `${viewport.width}x${viewport.height}`, cpuSlowdown: cpu, screen,
    fps: Math.round((frames.n / 5) * 10) / 10, longFrames: frames.long,
    layouts: count('Layout'), paints: count('Paint'), styleRecalcs: count('UpdateLayoutTree'),
    mainThreadMs: Math.round((m1.TaskDuration - m0.TaskDuration) * 1000),
    runningAnimations: vitals.animations,
    fcpMs: vitals.fcp && Math.round(vitals.fcp), lcpMs: Math.round(vitals.lcp), cls: Math.round(vitals.cls * 1000) / 1000, kb: Math.round(vitals.bytes / 1024),
  };
}

const runs = [];
runs.push(await measure({ name: 'Deobfuscate page, desktop', viewport: { width: 1440, height: 900 }, screen: 'site' }));
runs.push(await measure({ name: 'Deobfuscate page, phone, CPU 4× slower', viewport: { width: 390, height: 844 }, cpu: 4, screen: 'site' }));
runs.push(await measure({ name: 'Deobfuscate page while running, desktop', viewport: { width: 1440, height: 900 }, screen: 'running' }));
runs.push(await measure({ name: 'Expert tools, desktop', viewport: { width: 1440, height: 900 }, screen: 'work' }));
runs.push(await measure({ name: 'Expert tools, phone, CPU 4× slower', viewport: { width: 390, height: 844 }, cpu: 4, screen: 'work' }));
await browser.close();
server.close();
console.table(runs);
const i = process.argv.indexOf('--out');
if (i > 0) fs.writeFileSync(path.resolve(process.argv[i + 1]), `${JSON.stringify({ measured: new Date().toISOString(), note: 'Headless Chromium (software compositing) in a container: absolute fps is lower than on a GPU device; the paint/layout counts and main-thread time are what show whether animation costs the page anything.', runs }, null, 1)}\n`);
