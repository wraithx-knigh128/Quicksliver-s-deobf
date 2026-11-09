// The engines the reconstruction service can run, the versions they are meant for, and how an input is matched to them.
//
// This is a catalogue, not a claim. What each engine is known to do comes from data/research/luraph-compat.json (status.js reads it): every
// status shown on the page is derived from recorded runs, and a version with no engine is listed here precisely so that the page can say so.
// `plan()` is the page's preview of what the service will try; the service (api/_engine/luraph/service.py) makes the real decision and a test keeps the two
// in agreement on banner inputs.

export const ENGINES = Object.freeze({
  luraph_v14_7: { id: 'luraph_v14_7', label: 'Luraph v14.7', family: 'luraph', front: 'cli', version: '14.7' },
  luraph_v14_8: { id: 'luraph_v14_8', label: 'Luraph v14.8', family: 'luraph', front: 'cli', version: '14.8' },
  luraph_v14_9: { id: 'luraph_v14_9', label: 'Luraph v14.9', family: 'luraph', front: 'cli', version: '14.9' },
  luraph_v15: { id: 'luraph_v15', label: 'Luraph v15', family: 'luraph', front: 'deob', version: '15' },
  ironbrew1: { id: 'ironbrew1', label: 'IronBrew 1', family: 'ironbrew', front: 'deob', version: '1' },
  generic: { id: 'generic', label: 'Behaviour trace (no specific engine)', family: 'generic', front: 'deob', version: null },
});

/**
 * Every version the project knows to exist or to be worth tracking. `engine: null` means there is none, whatever else the page can do with the input.
 * Adding a version is adding a row; adding an engine is adding a row to ENGINES, the service's table and a plugin in the vendored engine.
 */
export const VERSIONS = Object.freeze([
  { id: 'luraph-13', family: 'luraph', label: 'Luraph v13 and earlier', match: { major: 13 }, engine: null, source: 'luraph-macrosdk-history', note: 'The SDK history dates a generation before v14 (since 2024-02-02). No engine, no sample.' },
  { id: 'luraph-14-early', family: 'luraph', label: 'Luraph v14.0 to v14.6', match: { major: 14, minors: [0, 1, 2, 3, 4, 5, 6] }, engine: null, nearest: 'luraph_v14_7', source: 'luraph-macrosdk-history', note: 'Third-party pages label files v14.3 and v14.4.1. The v14.7 engine is tried on them as an experiment; nothing is claimed.' },
  { id: 'luraph-14.7', family: 'luraph', label: 'Luraph v14.7', match: { major: 14, minors: [7] }, engine: 'luraph_v14_7' },
  { id: 'luraph-14.8', family: 'luraph', label: 'Luraph v14.8', match: { major: 14, minors: [8] }, engine: 'luraph_v14_8' },
  { id: 'luraph-14.9', family: 'luraph', label: 'Luraph v14.9', match: { major: 14, minors: [9] }, engine: 'luraph_v14_9' },
  { id: 'luraph-14-late', family: 'luraph', label: 'Luraph v14.10 and later 14.x', match: { major: 14, minorFrom: 10 }, engine: null, nearest: 'luraph_v14_9', note: 'Named by no source; the nearest engine is tried as an experiment.' },
  { id: 'luraph-15.0', family: 'luraph', label: 'Luraph v15.0', match: { major: 15, minors: [0, null] }, engine: 'luraph_v15' },
  { id: 'luraph-15.1', family: 'luraph', label: 'Luraph v15.1 and later 15.x', match: { major: 15, minorFrom: 1 }, engine: null, nearest: 'luraph_v15', source: 'luraph-macrosdk-history', note: 'The vendor SDK was updated for v15.1 on 2026-10-03; the supplied engine documents v15 only.' },
  { id: 'ironbrew-1', family: 'ironbrew', label: 'IronBrew 1', match: { header: 'ironbrew1' }, engine: 'ironbrew1' },
]);

const BANNER = /This file was protected using Luraph Obfuscator v(\d+)(?:\.(\d+))?(?:\.(\d+))?/;
const IB1 = /--\s*this file was generated using ironbrew1\b/i;

/** The banner in the first 4 KiB of a script, or null. It is text the file's owner controls. */
export function parseBanner(text) {
  const m = BANNER.exec(String(text).slice(0, 4096));
  if (!m) return null;
  return { text: m[0], version: [m[1], m[2], m[3]].filter((x) => x !== undefined).join('.'), major: Number(m[1]), minor: m[2] === undefined ? null : Number(m[2]) };
}

export function hasIronbrewHeader(text) { return IB1.test(String(text).slice(0, 4096)); }

/** The catalogue row a banner (or header) falls in. */
export function versionFor(banner, text = '') {
  if (banner) {
    return VERSIONS.find((v) => v.match.major === banner.major && (
      v.match.minors ? v.match.minors.includes(banner.minor) : v.match.minorFrom !== undefined ? (banner.minor !== null && banner.minor >= v.match.minorFrom) : true)) || null;
  }
  if (hasIronbrewHeader(text)) return VERSIONS.find((v) => v.id === 'ironbrew-1');
  return null;
}

/**
 * The attempts the service will make, first the choice and then the fallbacks. A fallback to a neighbouring engine is marked `nearest`
 * and a trace is marked as such: neither is ever presented as support for the version the input names.
 */
export function plan(input, requested = 'auto', allowFallback = true) {
  const banner = input.banner || null;
  const candidates = input.candidates || [];
  if (requested && requested !== 'auto') {
    if (!ENGINES[requested]) throw new Error(`unknown engine ${requested}`);
    const steps = [{ engine: requested, mode: 'lift', why: 'chosen by you' }];
    if (requested !== 'generic') steps.push({ engine: requested, mode: 'trace', why: 'same engine, behaviour trace only' });
    return steps;
  }
  const steps = [];
  const top = candidates[0];
  if (banner && banner.major === 14) {
    const own = [7, 8, 9].includes(banner.minor) ? `luraph_v14_${banner.minor}` : null;
    const near = ['luraph_v14_9', 'luraph_v14_8', 'luraph_v14_7'].filter((e) => e !== own);
    if (own) {
      steps.push({ engine: own, mode: 'lift', why: `banner names v${banner.version}` });
      if (allowFallback) for (const e of near) steps.push({ engine: e, mode: 'lift', nearest: true, why: `neighbouring v14 engine (the three are close relatives; used only because ${own} produced no source)` });
    } else {
      steps.push({ engine: near[0], mode: 'lift', nearest: true, why: `banner names v${banner.version}, which has no engine; the nearest engine is tried and the result is experimental` });
      if (allowFallback) for (const e of near.slice(1)) steps.push({ engine: e, mode: 'lift', nearest: true, why: 'neighbouring v14 engine' });
    }
    if (allowFallback) steps.push({ engine: steps[0].engine, mode: 'trace', why: 'behaviour trace of the first engine (what one run did, not the program)' });
  } else if (banner && banner.major === 15) {
    steps.push({ engine: 'luraph_v15', mode: 'lift', nearest: banner.minor !== null && banner.minor !== 0, why: `banner names v${banner.version}` });
    if (allowFallback) steps.push({ engine: 'luraph_v15', mode: 'trace', why: 'behaviour trace (what one run did, not the program)' });
  } else if (top && top.confidence >= 0.5) {
    steps.push({ engine: top.engine, mode: 'lift', why: `the engine's own detector (${top.confidence.toFixed(2)}), no usable banner` });
    if (allowFallback) steps.push({ engine: top.engine, mode: 'trace', why: 'behaviour trace (what one run did, not the program)' });
  } else if (!banner && hasIronbrewHeader(input.text || '')) {
    steps.push({ engine: 'ironbrew1', mode: 'lift', why: 'the header names IronBrew 1' });
    if (allowFallback) steps.push({ engine: 'ironbrew1', mode: 'trace', why: 'behaviour trace (what one run did, not the program)' });
  } else {
    steps.push({ engine: 'generic', mode: 'trace', why: 'no engine recognised the input; only a behaviour trace is possible' });
  }
  return steps;
}
