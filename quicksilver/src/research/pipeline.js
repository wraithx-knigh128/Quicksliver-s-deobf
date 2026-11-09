// The research pipeline as gates: Research -> Classification -> Experimental analysis -> Verification -> Compatibility profile -> Integration.
//
// This module does not run anything. It reads the evidence on file for one version of one system and says which stages that evidence reaches and,
// for the first stage it does not reach, what is missing. A later stage is never reported as reached over an unreached earlier one. Integration is
// split in two because they have different evidence: the page may IDENTIFY a system once classification is verified; it may only claim to
// RECONSTRUCT one once verification is. A finding becomes a capability only by passing the stage that requires it.

import { GATES, supportClaim, validateProfile } from './profiles.js';

export const STAGES = ['research', 'classification', 'experimental-analysis', 'verification', 'compatibility-profile', 'integration'];

/**
 * @param {object} profile    a profile from profiles.json
 * @param {string} versionId
 * @param {Array<{id: string, system: string|null, enabled: boolean}>} [capabilities] data/research/capabilities.json (the verified ones)
 * @returns {{system: string, version: string, stages: Array<{stage: string, reached: boolean, evidence: string[], missing: string[]}>, reached: string|null, integration: {identify: boolean, reconstruct: boolean}}}  identify: the page may name the system; reconstruct: the page may claim to rebuild it
 */
export function stagesFor(profile, versionId, capabilities = []) {
  const v = profile.versions.find((x) => x.id === versionId);
  if (!v) throw new Error(`unknown version ${versionId} of ${profile.id}`);
  const res = v.results || {};
  const samples = v.samples || {};
  const verifiedCaps = capabilities.filter((c) => c.enabled && (c.system === profile.id || c.system === null));
  const sys = capabilities.filter((c) => c.enabled && c.system === profile.id);

  const stages = [];
  const add = (stage, evidence, missing) => stages.push({ stage, reached: missing.length === 0, evidence, missing });
  const sourced = (v.characteristics || []).filter((c) => c.sources && c.sources.length);

  add('research', sourced.length ? [`${sourced.length} characteristics with sources`] : [], sourced.length ? [] : ['no characteristic names a source']);

  const methods = (v.identification && v.identification.methods) || [];
  add('classification',
    [...methods.map((m) => `${m.kind} (${m.confidence})`), ...sys.map((c) => `verified capability ${c.id}`)],
    [...(methods.length ? [] : ['no identification method']), ...(sys.length ? [] : ['no verified capability for this system (tools/research/capabilities.mjs)'])]);

  const engineRuns = (v.reconstruction && v.reconstruction.runs) || 0;
  const haveEvidence = (samples.authorizedPairs || 0) + (samples.realOutput || 0) + (res.fixtures || 0) + (res.pairs || 0) + engineRuns;
  add('experimental-analysis',
    haveEvidence ? [`${res.fixtures || 0} fixtures, ${samples.authorizedPairs || 0} authorised pairs, ${engineRuns} engine run${engineRuns === 1 ? '' : 's'} (${(v.reconstruction && v.reconstruction.traceOnly) || 0} ended as behaviour traces; failures are recorded)`] : [],
    haveEvidence ? [] : ['no output of this version has been run through the engine']);

  const realOk = v.verification.status === 'real-output-verified' && res.behaviourChecked >= GATES.real.minBehaviourChecked && res.runtime && res.runtime.source === 'reference';
  const authOk = v.verification.status === 'authorized-sample-verified' && res.runtimeVerified >= GATES.authorized.minRuntimeVerified && res.runtime && res.runtime.source === 'reference';
  add('verification', realOk || authOk ? [`reference runtime: ${authOk ? res.runtimeVerified + ' authorised pairs' : res.behaviourChecked + ' real-output fixtures'}`] : [],
    realOk || authOk ? [] : [`needs a reference-runtime behaviour check on at least ${v.verification.status.startsWith('authorized') || profile.kind === 'commercial' ? GATES.authorized.minPairs + ' authorised pairs' : GATES.real.minBehaviourChecked + ' real-output fixtures'}`]);

  const valid = validateProfile(profile);
  add('compatibility-profile', valid.ok ? [`status ${v.verification.status}`] : [], valid.ok ? [] : valid.problems.slice(0, 3));

  const identifyOk = sys.some((c) => /\b(banner|macro|identify|signature)/.test(c.id)) && methods.length > 0;
  const claim = supportClaim(profile, versionId).claim;
  const reconstructOk = (claim === 'supported' || claim === 'partial') && verifiedCaps.some((c) => /recover|reconstruct/.test(c.id));
  add('integration',
    [identifyOk ? 'identification wired to the page' : null, reconstructOk ? 'reconstruction claim allowed' : null].filter(Boolean),
    identifyOk || reconstructOk ? [] : ['nothing verified to integrate']);

  // order: a stage past an unreached one is not reached. Identification is wired to the page on classification alone, and that is reported in
  // `integration.identify`; the pipeline position (`reached`) stays the last stage with every earlier stage behind it.
  let reached = null;
  let blocked = false;
  for (const s of stages) {
    if (blocked) { s.reached = false; if (!s.missing.length) s.missing.push('an earlier stage is not reached'); continue; }
    if (s.reached) reached = s.stage; else blocked = true;
  }
  return { system: profile.id, version: versionId, stages, reached, integration: { identify: identifyOk, reconstruct: reconstructOk } };
}

/** Every version of every profile. */
export function pipelineReport(profiles, capabilities = []) {
  return profiles.profiles.flatMap((p) => p.versions.map((v) => stagesFor(p, v.id, capabilities)));
}
