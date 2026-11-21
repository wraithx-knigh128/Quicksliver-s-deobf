#!/usr/bin/env node
// Builds the landing scene's artwork (art/*.svg): palm silhouettes, a distant skyline, soft clouds, a raised highway and a flock of birds.
// Everything is drawn here from geometry and a seeded random generator, so the art is original, reproducible and small; no photograph,
// screenshot or third-party image is used. The sky, sun, water and their motion are CSS (css/scene.css).
//
//   node tools/art/build-scene.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = path.join(repo, 'art');
fs.mkdirSync(out, { recursive: true });

function rng(seed) { let s = seed >>> 0; return () => { s = (s + 0x6d2b79f5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const f = (n) => (Math.round(n * 10) / 10).toString();
const svg = (w, h, body, extra = '') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" preserveAspectRatio="xMidYMax slice"${extra}>${body}</svg>\n`;

// ---- palms -------------------------------------------------------------------------------------------------------------------------------
// A frond is a drooping quadratic curve from the crown; its blade is a strip along the curve whose edges are cut into leaflets that sweep back
// towards the tip, which is how a coconut palm's pinnate leaf reads in silhouette.
function quad(p0, p1, p2, t) { const u = 1 - t; return [u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]]; }
function quadTan(p0, p1, p2, t) { const x = 2 * (1 - t) * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0]); const y = 2 * (1 - t) * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1]); const l = Math.hypot(x, y) || 1; return [x / l, y / l]; }

function frond(crown, angle, length, droop, width, r) {
  // the rib: a drooping quadratic curve; the blade: individual leaflets, each a thin curved blade that leaves the rib swept towards the tip
  // and hangs under its own weight — long in the middle of the frond, short at both ends
  const a = (angle * Math.PI) / 180;
  const tip = [crown[0] + Math.cos(a) * length, crown[1] - Math.sin(a) * length * 0.55 + droop];
  const ctrl = [crown[0] + Math.cos(a) * length * 0.55, crown[1] - Math.sin(a) * length * 0.75 - length * 0.18];
  let d = '';
  // the rib itself, tapering
  const ribL = []; const ribR = [];
  for (let i = 0; i <= 16; i++) {
    const t = i / 16; const p = quad(crown, ctrl, tip, t); const dd = quadTan(crown, ctrl, tip, t); const n = [-dd[1], dd[0]];
    const w = (width * 0.12) * (1 - t * 0.85);
    ribL.push([p[0] + n[0] * w, p[1] + n[1] * w]); ribR.push([p[0] - n[0] * w, p[1] - n[1] * w]);
  }
  d += `M${[...ribL, ...ribR.reverse()].map((q) => `${f(q[0])} ${f(q[1])}`).join('L')}Z`;
  const M = 24;
  for (let i = 1; i < M; i++) {
    const t = 0.06 + (i / M) * 0.92;
    const p = quad(crown, ctrl, tip, t);
    const dd = quadTan(crown, ctrl, tip, t);
    const len = width * 2.5 * Math.pow(Math.sin(Math.PI * Math.min(1, t * 1.05)), 0.55) * (0.85 + r() * 0.3);
    for (const side of [1, -1]) {
      const n = [-dd[1] * side, dd[0] * side];
      // direction: out from the rib, swept 40° towards the tip, then pulled down by gravity
      const dir = [n[0] * 0.75 + dd[0] * 0.65, n[1] * 0.75 + dd[1] * 0.65 + 0.55];
      const dl = Math.hypot(dir[0], dir[1]);
      const u = [dir[0] / dl, dir[1] / dl];
      const tipL = [p[0] + u[0] * len, p[1] + u[1] * len + len * 0.18];
      const mid = [p[0] + u[0] * len * 0.55 - n[0] * len * 0.08, p[1] + u[1] * len * 0.45];
      const bw = width * 0.11;
      const b1 = [p[0] - dd[0] * bw, p[1] - dd[1] * bw]; const b2 = [p[0] + dd[0] * bw, p[1] + dd[1] * bw];
      d += `M${f(b1[0])} ${f(b1[1])}Q${f(mid[0] - dd[0] * bw)} ${f(mid[1] - dd[1] * bw)} ${f(tipL[0])} ${f(tipL[1])}Q${f(mid[0] + dd[0] * bw * 1.6)} ${f(mid[1] + dd[1] * bw * 1.6)} ${f(b2[0])} ${f(b2[1])}Z`;
    }
  }
  return d;
}

function palm({ seed, w, h, base, height, lean, fronds, scale = 1 }) {
  const r = rng(seed);
  // trunk: a tapered strip along a gentle curve, with growth rings as small notches
  const top = [base[0] + lean, base[1] - height];
  const ctrl = [base[0] + lean * 0.15, base[1] - height * 0.55];
  const L = []; const R = [];
  for (let i = 0; i <= 30; i++) {
    const t = i / 30;
    const p = quad(base, ctrl, top, t);
    const d = quadTan(base, ctrl, top, t);
    const n = [-d[1], d[0]];
    const wid = (22 - 12 * t) * scale + (i % 3 === 0 ? 1.6 * scale : 0);
    L.push([p[0] + n[0] * wid / 2, p[1] + n[1] * wid / 2]);
    R.push([p[0] - n[0] * wid / 2, p[1] - n[1] * wid / 2]);
  }
  const trunk = `M${[...L, ...R.reverse()].map((q) => `${f(q[0])} ${f(q[1])}`).join('L')}Z`;
  const paths = [trunk];
  for (const fr of fronds) paths.push(frond(top, fr.a, fr.l * scale, fr.d * scale, fr.w * scale, r));
  // coconuts / crown knot
  paths.push(`M${f(top[0] - 14 * scale)} ${f(top[1] + 4 * scale)}a${f(14 * scale)} ${f(11 * scale)} 0 1 0 ${f(28 * scale)} 0a${f(14 * scale)} ${f(11 * scale)} 0 1 0 ${f(-28 * scale)} 0Z`);
  return paths;
}

const FRONDS = [
  { a: 172, l: 330, d: 120, w: 34 }, { a: 150, l: 300, d: 40, w: 32 }, { a: 128, l: 250, d: -10, w: 28 }, { a: 100, l: 190, d: -30, w: 24 },
  { a: 72, l: 230, d: -10, w: 27 }, { a: 45, l: 300, d: 30, w: 32 }, { a: 18, l: 340, d: 110, w: 34 }, { a: -8, l: 300, d: 190, w: 30 },
  { a: 192, l: 280, d: 200, w: 30 }, { a: 210, l: 200, d: 230, w: 24 }, { a: -30, l: 190, d: 220, w: 24 },
];

function palmSvg(name, { seed, mirror = false, palms }) {
  const W = 900; const H = 1400;
  let body = '';
  for (const p of palms) {
    const paths = palm({ seed: seed + p.seedOffset, w: W, h: H, base: p.base, height: p.height, lean: p.lean, fronds: FRONDS.map((x) => ({ ...x, a: x.a + p.rot })), scale: p.scale });
    body += `<path fill="${p.fill}" fill-opacity="${p.opacity}" d="${paths.join('')}"/>`;
  }
  const flip = mirror ? ` transform="translate(${W} 0) scale(-1 1)"` : '';
  fs.writeFileSync(path.join(out, name), svg(W, H, `<g${flip}>${body}</g>`).replace('preserveAspectRatio="xMidYMax slice"', 'preserveAspectRatio="xMidYMax meet"'));
}

// two framing groups: big near palms in deep plum, a smaller farther one in a lighter, hazier tone (aerial perspective)
palmSvg('palm-left.svg', { seed: 7, palms: [
  { seedOffset: 1, base: [260, 1420], height: 1120, lean: 150, rot: 0, scale: 1.25, fill: '#2a1638', opacity: 1 },
  { seedOffset: 2, base: [80, 1440], height: 820, lean: -60, rot: 14, scale: 0.85, fill: '#4a2a5e', opacity: 0.75 },
] });
palmSvg('palm-right.svg', { seed: 21, mirror: true, palms: [
  { seedOffset: 3, base: [230, 1420], height: 1240, lean: 170, rot: -6, scale: 1.35, fill: '#2a1638', opacity: 1 },
  { seedOffset: 4, base: [520, 1440], height: 640, lean: 40, rot: 10, scale: 0.7, fill: '#56316a', opacity: 0.6 },
] });

// ---- skyline -----------------------------------------------------------------------------------------------------------------------------
function skyline(seed, W, H, { count, minH, maxH, color, opacity, antennas }) {
  const r = rng(seed);
  let x = 0; let d = '';
  while (x < W) {
    const bw = 18 + r() * 46;
    const tall = r() < 0.18;
    const bh = minH + (tall ? (maxH - minH) : (maxH - minH) * 0.45) * r();
    const y = H - bh;
    d += `M${f(x)} ${H}V${f(y)}`;
    if (r() < 0.25) { d += `H${f(x + bw * 0.3)}V${f(y - 10 - r() * 18)}H${f(x + bw * 0.7)}V${f(y)}`; }   // a stepped top
    d += `H${f(x + bw)}V${H}Z`;
    if (tall && antennas && r() < 0.6) d += `M${f(x + bw / 2 - 1)} ${f(y)}V${f(y - 40 - r() * 60)}h2V${f(y)}Z`;
    x += bw + (r() < 0.3 ? r() * 10 : 0);
  }
  return `<path fill="${color}" fill-opacity="${opacity}" d="${d}"/>`;
}
{
  const W = 2400; const H = 360;
  const far = skyline(101, W, H, { minH: 30, maxH: 170, color: '#b86a9c', opacity: 0.45, antennas: false });
  const near = skyline(202, W, H, { minH: 20, maxH: 260, color: '#7b3f7f', opacity: 0.7, antennas: true });
  // a tall radio mast like a coastal city's, left of centre
  const mast = `<path fill="#5e2f66" fill-opacity="0.8" d="M700 ${H}V20h3V${H}Z M694 120h15v3h-15Z M690 220h23v3h-23Z"/>`;
  fs.writeFileSync(path.join(out, 'skyline.svg'), svg(W, H, far + near + mast).replace('preserveAspectRatio="xMidYMax slice"', 'preserveAspectRatio="xMidYMax slice"'));
}

// ---- clouds: soft banks from radial gradients (no filters, so the image is cheap to composite) ------------------------------------------
{
  const W = 2400; const H = 700;
  const r = rng(303);
  let defs = '<defs>';
  let body = '';
  const tones = ['#ffb3c7', '#ff9fb5', '#f6a3d0', '#ffc2a6', '#e79ad8'];
  for (let i = 0; i < 46; i++) {
    const id = `c${i}`;
    const tone = tones[Math.floor(r() * tones.length)];
    defs += `<radialGradient id="${id}"><stop offset="0" stop-color="${tone}" stop-opacity="${f(0.35 + r() * 0.3)}"/><stop offset="1" stop-color="${tone}" stop-opacity="0"/></radialGradient>`;
    const cx = r() * W; const cy = 80 + Math.pow(r(), 1.6) * (H - 160);
    body += `<ellipse cx="${f(cx)}" cy="${f(cy)}" rx="${f(160 + r() * 360)}" ry="${f(26 + r() * 54)}" fill="url(#${id})"/>`;
  }
  defs += '</defs>';
  fs.writeFileSync(path.join(out, 'clouds.svg'), svg(W, H, defs + body).replace('preserveAspectRatio="xMidYMax slice"', 'preserveAspectRatio="none"'));
}

// ---- the raised highway in the foreground ------------------------------------------------------------------------------------------------
{
  const W = 2400; const H = 260;
  let d = `M0 120 C 600 90, 1500 70, 2400 40 L2400 76 C 1500 106, 600 126, 0 156 Z`;
  for (let x = 120; x < W; x += 260) {
    const yTop = 156 - (x / W) * 116 + 2;
    d += `M${x} ${f(yTop)}h26V${H}h-26Z`;
  }
  const rail = `<path fill="none" stroke="#3a1e4a" stroke-width="3" d="M0 116 C 600 86, 1500 66, 2400 36"/>`;
  fs.writeFileSync(path.join(out, 'highway.svg'), svg(W, H, `<path fill="#24112f" d="${d}"/>${rail}`).replace('preserveAspectRatio="xMidYMax slice"', 'preserveAspectRatio="none"'));
}

// ---- birds ---------------------------------------------------------------------------------------------------------------------------------
{
  const r = rng(404);
  let d = '';
  for (let i = 0; i < 5; i++) {
    const x = 20 + i * 38 + r() * 20; const y = 30 + r() * 40; const s = 7 + r() * 6;
    d += `M${f(x - s)} ${f(y - s * 0.3)}Q${f(x - s * 0.4)} ${f(y - s * 0.6)} ${f(x)} ${f(y)}Q${f(x + s * 0.4)} ${f(y - s * 0.6)} ${f(x + s)} ${f(y - s * 0.3)}`;
  }
  fs.writeFileSync(path.join(out, 'birds.svg'), svg(240, 110, `<path fill="none" stroke="#3b2147" stroke-width="2.2" stroke-linecap="round" d="${d}"/>`).replace('preserveAspectRatio="xMidYMax slice"', ''));
}

for (const n of fs.readdirSync(out)) console.log(`art/${n}: ${fs.statSync(path.join(out, n)).size} bytes`);
