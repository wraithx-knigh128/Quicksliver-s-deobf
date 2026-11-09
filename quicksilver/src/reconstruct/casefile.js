// The case file the research assistant reads: facts about one reconstruction attempt, assembled from the service's result and the compatibility registry.
// The script itself is never included. The log tail is engine output; it can carry strings the script produced, so the assistant treats it as untrusted.

import { VERSIONS, ENGINES, parseBanner, versionFor } from './engines.js';
import { versionStatus } from './status.js';

export function buildCaseFile(result, registry = null, { logLines = 60 } = {}) {
  const banner = result.identification && result.identification.banner;
  const row = banner ? versionFor(parseBanner(banner.text)) : null;
  return {
    input: result.identification ? { bytes: result.identification.bytes, sha256: result.identification.sha256, banner: banner ? banner.text : null, detectorCandidates: result.identification.candidates } : null,
    outcome: { ok: !!result.ok, kind: result.kind, engineUsed: result.engine && result.engine.used ? ENGINES[result.engine.used].label : null, mode: result.engine && result.engine.mode, nearestEngine: !!(result.engine && result.engine.nearest) },
    attempts: ((result.engine && result.engine.attempts) || []).map((a) => ({ engine: a.engine, mode: a.mode, outcome: a.outcome, seconds: a.seconds })),
    quality: result.quality ? { lines: result.quality.lines, functions: result.quality.functions, grade: result.quality.grade, unresolved: result.quality.unresolved } : null,
    syntax: result.checks && result.checks.syntax ? { ok: result.checks.syntax.ok, errors: result.checks.syntax.errors } : null,
    verification: result.verification ? { status: result.verification.status, reason: result.verification.reason } : null,
    diagnostics: (result.diagnostics || []).map((d) => ({ code: d.code, severity: d.severity, message: d.message, evidence: d.evidence })),
    attemptedVersionRow: row ? { id: row.id, label: row.label, engine: row.engine } : null,
    compatibility: registry ? VERSIONS.map((v) => ({ version: v.label, engine: v.engine ? ENGINES[v.engine].label : null, status: versionStatus(v, registry).status, why: versionStatus(v, registry).reasons.join('; ') })) : null,
    engineLogTail: (result.log || []).slice(-logLines),
  };
}
