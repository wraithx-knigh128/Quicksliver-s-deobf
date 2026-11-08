// Reconstruction plans: the techniques the laboratory evaluates and the page can apply.
//
// A plan is a configuration of the recovery engine, nothing more. Whether a plan works on a kind of input is not written here; it is measured by
// the laboratory (tools/lab/) and read back by the advisor (advisor.js). The list is data: a new technique is one more entry.

import { recover } from '../recover/pipeline.js';
import { nexusRecover } from '../nexus/pipeline.js';

export const PLANS = Object.freeze([
  { id: 'generic', label: 'Generic passes only', nexus: false, adaptive: false, sandbox: false, needsConsent: false, text: 'Constant folding, simplification, dead-code removal and renaming; no structure reader.' },
  { id: 'adaptive', label: 'Generic + structure reader', nexus: false, adaptive: true, sandbox: false, needsConsent: false, text: 'Adds the structure reader: flattened control flow, opaque conditions, call proxies, constant tables.' },
  { id: 'adaptive+sandbox', label: 'Structure reader + sandboxed decoders', nexus: false, adaptive: true, sandbox: true, needsConsent: true, text: 'Also evaluates decoder functions and computed loadstring payloads in the interpreter sandbox.' },
  { id: 'nexus-generic', label: 'NEXUS, generic passes', nexus: true, adaptive: false, sandbox: false, needsConsent: false, text: 'NEXUS (comment and relation analysis, repeated passes, claims ledger) without the structure reader.' },
  { id: 'nexus', label: 'NEXUS', nexus: true, adaptive: true, sandbox: false, needsConsent: false, text: 'Structure reader inside NEXUS: comment and relation analysis, repeated passes, claims ledger.' },
  { id: 'nexus-generic+sandbox', label: 'NEXUS, generic passes + sandboxed decoders', nexus: true, adaptive: false, sandbox: true, needsConsent: true, text: 'NEXUS without the structure reader, with the sandbox switched on for decoders and computed payloads.' },
  { id: 'nexus+sandbox', label: 'NEXUS + sandboxed decoders', nexus: true, adaptive: true, sandbox: true, needsConsent: true, text: 'NEXUS with the sandbox switched on for decoders and computed payloads.' },
]);

export const planById = (id) => PLANS.find((p) => p.id === id) || null;

/** The options to hand to api.recoverSource for a plan. `base` carries the person's own settings (indent, rename mode, ...). */
export function planOptions(plan, base = {}) {
  return { ...base, adaptive: plan.adaptive, nexus: plan.nexus, sandbox: { ...(base.sandbox || {}), enabled: plan.sandbox } };
}

/**
 * Run a plan on a source. The result carries the recovered code without any report block, so that two plans can be compared on code alone.
 * @returns {{ok: boolean, code: string|null, confidence: object|null, steps: object[], result: object}}
 */
export function runPlan(plan, source, base = {}) {
  // a technique that is not one of the engine's own switches: `run(source)` returns { code } (or { code: null } for "could not")
  if (typeof plan.run === 'function') {
    const r = plan.run(source) || {};
    return { ok: typeof r.code === 'string', code: r.code ?? null, confidence: null, steps: [], result: r };
  }
  const opts = { ...planOptions(plan, base), annotate: false };
  const { nexus, ...rest } = opts;
  const result = nexus ? nexusRecover(source, { recover: rest }) : recover(source, rest);
  return { ok: !!result.ok, code: result.output ?? null, confidence: result.confidence || null, steps: result.steps || [], result };
}
