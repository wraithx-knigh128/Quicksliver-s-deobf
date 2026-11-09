// Compatibility profiles: what is known about one transformation system, version by version, and what the engine may claim about it.
//
// A profile is evidence, organised. For each version of a system it records how the version is identified and with what confidence, what is documented
// about it (every item with its sources and how it is known), which samples exist and where they came from, what the engine can do with it and how
// well that was verified, the results, and the limits. The one thing a profile may not do is say more than its evidence allows, and that is enforced here
// and not left to whoever writes the profile:
//
//   verification status  researched < identified < traced < internally-tested < real-output-verified < authorized-sample-verified
//
//   * real-output-verified needs fixtures made by running the real tool (open-source tools only: the lab can run them), a behaviour check on a reference
//     runtime for at least GATES.real.minBehaviourChecked of them, and the results to back it;
//   * authorized-sample-verified needs original-and-protected pairs supplied by someone entitled to supply them, differential-tested on a reference runtime;
//   * nothing else makes a version "supported". Recognising a system's output is `identified`, and says nothing about reconstruction.
//
// `supportClaim` is the only function the interface uses to say "supported". `validateProfile` is run by the build and by the tests.

import { wilson } from './judge.js';

export const STATUSES = ['researched', 'identified', 'traced', 'internally-tested', 'real-output-verified', 'authorized-sample-verified'];
export const KNOWN_AS = ['documented', 'reported', 'observed', 'inferred'];
export const CAP_LEVELS = ['none', 'unverified', 'format-tested', 'vendor-data-tested', 'internally-tested', 'real-output-tested', 'authorized-sample-tested'];
export const GATES = Object.freeze({
  real: { minFixtures: 8, minBehaviourChecked: 8 },
  authorized: { minPairs: 8, minRuntimeVerified: 8 },
  supportedRateLo: 0.7,   // lower bound of the 95% interval of runtime-verified successes
  partialRateLo: 0.3,
});
export const IDENTIFICATION_CAPS = Object.freeze({ banner: 0.7, 'macro-set': 0.8, structure: 0.9, signature: 0.8 });

const rank = (s) => STATUSES.indexOf(s);

/** @returns {{ok: boolean, problems: string[]}} */
export function validateProfile(p) {
  const problems = [];
  const bad = (m) => problems.push(`${p && p.id}: ${m}`);
  if (!p || typeof p.id !== 'string' || !/^[a-z0-9][a-z0-9_.-]*$/.test(p.id)) { bad('id must be lower-case letters, digits, _ . -'); return { ok: false, problems }; }
  if (!p.name) bad('name is required');
  if (!['commercial', 'open-source', 'custom', 'lab-made', 'unknown'].includes(p.kind)) bad(`kind "${p.kind}" is not one of commercial, open-source, custom, lab-made, unknown`);
  if (!Array.isArray(p.versions) || !p.versions.length) { bad('at least one version (even "unversioned") is required'); return { ok: false, problems }; }
  const seen = new Set();
  for (const v of p.versions) {
    const at = `${p.id}@${v.id}`;
    const vbad = (m) => problems.push(`${at}: ${m}`);
    if (!v.id || seen.has(v.id)) vbad('version id missing or repeated');
    seen.add(v.id);
    if (!STATUSES.includes(v.verification && v.verification.status)) { vbad('verification.status is not a known status'); continue; }
    // identification
    const idn = v.identification || {};
    if (typeof idn.confidence !== 'number' || idn.confidence < 0 || idn.confidence > 1) vbad('identification.confidence must be between 0 and 1');
    for (const m of idn.methods || []) {
      const cap = IDENTIFICATION_CAPS[m.kind];
      if (cap === undefined) vbad(`identification method "${m.kind}" is unknown`);
      else if (m.confidence > cap) vbad(`identification by ${m.kind} claims ${m.confidence}, above the ${cap} that kind of evidence can support`);
      if (m.kind === 'structure' && !(v.samples && (v.samples.authorizedPairs > 0 || v.samples.realOutput > 0))) vbad('identification by structure needs samples the structure was read from');
    }
    if (idn.confidence > Math.max(0, ...(idn.methods || []).map((m) => IDENTIFICATION_CAPS[m.kind] || 0))) vbad('identification confidence is above that of its best method');
    // characteristics: every one says how it is known and what for
    for (const c of v.characteristics || []) {
      if (!KNOWN_AS.includes(c.knownAs)) vbad(`characteristic "${String(c.text).slice(0, 40)}" has no valid knownAs`);
      if ((c.knownAs === 'documented' || c.knownAs === 'observed' || c.knownAs === 'reported') && !(c.sources && c.sources.length)) vbad(`characteristic "${String(c.text).slice(0, 40)}" is ${c.knownAs} but names no source`);
      if (c.knownAs === 'inferred' && !c.basis) vbad(`characteristic "${String(c.text).slice(0, 40)}" is inferred but gives no basis`);
    }
    // capabilities
    for (const [name, cap] of Object.entries(v.capabilities || {})) {
      if (!CAP_LEVELS.includes(cap.verified)) vbad(`capability ${name}: verified level "${cap.verified}" is unknown`);
      if (cap.available === false && cap.verified !== 'none') vbad(`capability ${name} is unavailable but has a verification level`);
      if (cap.verified === 'real-output-tested' && p.kind !== 'open-source' && p.kind !== 'lab-made') vbad(`capability ${name}: real-output testing is only possible for tools the lab can run (open-source or lab-made)`);
      if (cap.verified === 'authorized-sample-tested' && !(v.samples && v.samples.authorizedPairs >= GATES.authorized.minPairs)) vbad(`capability ${name}: authorized-sample testing needs at least ${GATES.authorized.minPairs} authorised pairs`);
    }
    // gates
    const st = v.verification.status;
    const res = v.results || {};
    if (rank(st) >= rank('real-output-verified')) {
      if (st === 'real-output-verified') {
        if (p.kind !== 'open-source' && p.kind !== 'lab-made') vbad('real-output-verified is only available to tools the lab can run');
        if (!(res.fixtures >= GATES.real.minFixtures)) vbad(`real-output-verified needs at least ${GATES.real.minFixtures} real-output fixtures (has ${res.fixtures || 0})`);
        if (!(res.behaviourChecked >= GATES.real.minBehaviourChecked)) vbad(`real-output-verified needs a behaviour check on at least ${GATES.real.minBehaviourChecked} fixtures (has ${res.behaviourChecked || 0})`);
        if (!res.runtime || res.runtime.source !== 'reference') vbad('real-output-verified needs the behaviour decided on a reference runtime');
      }
      if (st === 'authorized-sample-verified') {
        if (!(v.samples && v.samples.authorizedPairs >= GATES.authorized.minPairs)) vbad(`authorized-sample-verified needs at least ${GATES.authorized.minPairs} authorised pairs`);
        if (!(res.runtimeVerified >= GATES.authorized.minRuntimeVerified)) vbad(`authorized-sample-verified needs ${GATES.authorized.minRuntimeVerified} runtime-verified results`);
        if (!res.runtime || res.runtime.source !== 'reference') vbad('authorized-sample-verified needs the behaviour decided on a reference runtime');
      }
    }
    if (rank(st) >= rank('identified') && !(v.capabilities && v.capabilities.identify && v.capabilities.identify.available)) vbad(`status ${st} needs an identify capability`);
    if (v.capabilities && v.capabilities.recover && v.capabilities.recover.available && rank(st) < rank('internally-tested')) vbad('recover is claimed available but the version is not even internally tested');
    if (!Array.isArray(v.limitations) || !v.limitations.length) vbad('limitations may not be empty: say what is not known or not done');
  }
  return { ok: problems.length === 0, problems };
}

/**
 * What the interface may say about a version. Derived, never stored.
 * @returns {{claim: 'supported'|'partial'|'identification-only'|'unknown', why: string}}
 */
export function supportClaim(profile, versionId) {
  const v = profile.versions.find((x) => x.id === versionId);
  if (!v) return { claim: 'unknown', why: 'This version is not in the profile.' };
  const st = v.verification.status;
  const r = v.results || {};
  if (st === 'real-output-verified' || st === 'authorized-sample-verified') {
    const n = st === 'authorized-sample-verified' ? r.runtimeVerified : r.behaviourChecked;
    const ok = st === 'authorized-sample-verified' ? r.runtimeSuccess : r.behaviourSame;
    const lo = wilson(ok ?? 0, n ?? 0).lo;
    if (lo >= GATES.supportedRateLo) return { claim: 'supported', why: `${ok} of ${n} ${st === 'authorized-sample-verified' ? 'authorised pairs' : 'real-tool fixtures'} reconstructed with identical behaviour on a reference runtime (lower bound ${Math.round(lo * 100)}%).` };
    if (lo >= GATES.partialRateLo) return { claim: 'partial', why: `${ok} of ${n} reconstructed with identical behaviour (lower bound ${Math.round(lo * 100)}%).` };
    return { claim: 'identification-only', why: `Verified, but only ${ok} of ${n} reconstructed with identical behaviour.` };
  }
  if (rank(st) >= rank('identified')) return { claim: 'identification-only', why: 'The output can be recognised. No reconstruction has been verified against real or authorised samples.' };
  return { claim: 'unknown', why: 'Researched only: the engine has no capability for it.' };
}
