// The ledger of what has been learned about the engines, and how sure we are.
//
// An idea (from a person, from the research assistant, from reading a log) is a `hypothesis`. It becomes `verified` only with a command that reproduces
// the evidence and evidence that names records already in the registry; it becomes `refuted` when an experiment disproved it, and the failed experiment is kept.
// Only a `verified` entry may be cited as the reason for a capability. `validateLedger` is run by the tests so a verified entry cannot lack its evidence.

export const STATES = ['hypothesis', 'verified', 'refuted'];

/** @returns {{ok: boolean, problems: string[]}} */
export function validateLedger(ledger, registry = null) {
  const problems = [];
  const ids = new Set();
  const recordIds = new Set(((registry && registry.records) || []).map((r) => r.id));
  for (const e of ledger.entries || []) {
    const bad = (m) => problems.push(`${e.id}: ${m}`);
    if (!e.id || ids.has(e.id)) bad('id missing or repeated');
    ids.add(e.id);
    if (!STATES.includes(e.state)) bad(`state "${e.state}" is not one of ${STATES.join(', ')}`);
    if (!e.claim) bad('no claim');
    if (!e.origin) bad('no origin (who or what proposed it)');
    if (e.state === 'verified') {
      if (!e.reproduce || !/^(node|python3|npm) /.test(e.reproduce)) bad('verified needs a reproduce command that can be run from the repository');
      if (!(e.evidence && e.evidence.records && e.evidence.records.length)) bad('verified needs evidence.records naming runs in the registry');
      for (const r of (e.evidence && e.evidence.records) || []) if (registry && !recordIds.has(r)) bad(`evidence names record "${r}", which is not in the registry`);
      if (!e.verifiedAt) bad('verified needs verifiedAt');
    }
    if (e.state === 'refuted' && !e.experiment) bad('refuted needs the experiment that disproved it');
    if (e.state === 'hypothesis' && e.usedFor && e.usedFor.length) bad('a hypothesis may not be the reason for a capability');
  }
  return { ok: problems.length === 0, problems };
}
