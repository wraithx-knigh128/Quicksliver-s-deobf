// What may be said about an engine or a version, derived from recorded runs and from nothing else.
//
//   fully-tested      at least GATES.full.minPairs (10) runs lifted by this engine (not a trace) and compared with their originals on a real Luau runtime, every one
//                     identical, and the 95% lower bound of the success rate at least GATES.full.lo
//   partially-tested  at least one such comparison came out identical and none different
//   experimental      the engine exists and ran, but no lifted run was compared with an original (or the comparisons disagree): readable output exists, support is not shown
//   unsupported       no engine, or at least GATES.unsupportedAfter inputs of that version were tried and the engine lifted none of them
//
// A trace is never counted as a lift, an unverified lift is never counted as verified, and a neighbouring engine's success is never credited to a version it was not made for.

import { wilson } from '../research/judge.js';

export const STATUS_ORDER = ['unsupported', 'experimental', 'partially-tested', 'fully-tested'];
// ten, not eight: the 95% lower bound of 8 of 8 is 0.68, so a bound of 0.7 first holds at 10 of 10 (the same arithmetic as src/research/profiles.js)
export const GATES = Object.freeze({ full: { minPairs: 10, lo: 0.7 }, unsupportedAfter: 3 });

/** @param {Array<object>} records the records of data/research/luraph-compat.json whose `engine` is the one in question */
export function engineStatus(records, { hasEngine = true } = {}) {
  const ev = { runs: records.length, lifted: 0, liftedUnverified: 0, traceOnly: 0, liftFailed: 0, pairs: 0, identical: 0, different: 0, inconclusive: 0 };
  for (const r of records) {
    const lifted = r.kind === 'devirtualized' && r.mode === 'lift';
    if (lifted) {
      ev.lifted++;
      const v = r.verification && r.verification.status;
      if (v === 'identical') { ev.pairs++; ev.identical++; } else if (v === 'different') { ev.pairs++; ev.different++; } else if (v === 'inconclusive') ev.inconclusive++;
      else ev.liftedUnverified++;
    } else if (r.kind === 'trace' || r.kind === 'trace-assisted') { ev.traceOnly++; if (r.kind === 'trace') ev.liftFailed++; } else ev.liftFailed++;
  }
  const reasons = [];
  let status;
  if (!hasEngine) { status = 'unsupported'; reasons.push('no engine exists for this version'); }
  else if (ev.pairs >= GATES.full.minPairs && ev.different === 0 && wilson(ev.identical, ev.pairs).lo >= GATES.full.lo) { status = 'fully-tested'; reasons.push(`${ev.identical} of ${ev.pairs} lifted runs behaved identically to their originals on a real Luau runtime`); }
  else if (ev.identical >= 1 && ev.different === 0) { status = 'partially-tested'; reasons.push(`${ev.identical} lifted run${ev.identical === 1 ? '' : 's'} compared identical with the original; ${GATES.full.minPairs} are needed (with a lower bound of ${Math.round(GATES.full.lo * 100)}%) for "fully tested"`); }
  else if (ev.runs >= GATES.unsupportedAfter && ev.lifted === 0) { status = 'unsupported'; reasons.push(`${ev.runs} inputs tried and none was lifted`); }
  else {
    status = 'experimental';
    if (ev.different > 0) reasons.push(`${ev.different} lifted run${ev.different === 1 ? '' : 's'} behaved differently from the original`);
    if (ev.lifted === 0 && ev.runs > 0) reasons.push(`${ev.runs} input${ev.runs === 1 ? '' : 's'} tried; the engine lifted none (${ev.traceOnly} ended as a behaviour trace)`);
    if (ev.liftedUnverified > 0) reasons.push(`${ev.liftedUnverified} lifted run${ev.liftedUnverified === 1 ? ' has' : 's have'} no original to compare with`);
    if (ev.runs === 0) reasons.push('never run on a fixture');
  }
  return { status, evidence: ev, reasons };
}

/** Status of one catalogue row (a version), from the registry. A row with no engine is unsupported by definition; its `nearest` engine is reported separately. */
export function versionStatus(version, registry) {
  if (!version.engine) return { ...engineStatus([], { hasEngine: false }), nearest: version.nearest || null };
  const records = (registry.records || []).filter((r) => r.versionRow === version.id && r.engine === version.engine);
  return { ...engineStatus(records), nearest: null };
}
