// What a reconstruction run actually achieved, decided by explicit evidence — never by an HTTP status, a downloaded file, a decoder that
// returned text, a generated output, readable code, or the engine's own confidence estimate on their own.
//
// One classification is shared by the Deobfuscator tab, Loader Intelligence and the tests, so a result means the same thing everywhere.
// Each class has a fixed definition (CRITERIA); `classifyOutcome` returns the class, the criteria it met, and the reasons it fell short of the
// classes above it. The order of the checks is the order of the pipeline: a stage that failed decides the result, and later stages are not
// consulted.
//
//   Loader input → loader analysis → authorisation → retrieval → payload validation → obfuscator detection → deobfuscation
//     → syntax validation → behavioural validation → output

export const OUTCOMES = {
  validated: 'Fully reconstructed and behaviourally validated',
  'syntax-valid-unverified': 'Syntax-valid but behaviourally unverified',
  partial: 'Partially reconstructed',
  'not-deobfuscated': 'Payload retrieved but not successfully deobfuscated',
  'payload-unavailable': 'Payload unavailable',
  'authorization-unavailable': 'Authorization unavailable',
  'unsupported-format': 'Unsupported format',
  'invalid-input': 'Invalid or incomplete input',
};

export const CRITERIA = {
  validated: 'The output parses; no obfuscation is left in it (no residual indicator, nothing the engine lists as unresolved, confidence not low); and the output was run next to a reference — the authorised original when there is one, otherwise the submitted program — and behaved identically, with the reference doing something observable and the run reaching at least half of the output\u2019s statement lines (when that is measured).',
  'syntax-valid-unverified': 'The output parses and no obfuscation is left in it, but its behaviour was not compared (no comparison run, or one that could not settle it). Readable is not the same as correct.',
  partial: 'The output parses, but some obfuscation is still in it (residual indicators, unresolved places, or a low confidence), or it was run next to its reference and behaved differently.',
  'not-deobfuscated': 'A program was received and the pipeline ran, but it produced no output, an output that does not parse, or an output in which the protection is essentially all still present (confidence minimal or none).',
  'payload-unavailable': 'The program the loader runs could not be obtained: no authorised route exists for it, the service answered that it does not exist, the transfer failed, or the response was not code (an error page, a JSON message, an empty body).',
  'authorization-unavailable': 'An authorised route exists in principle, but the credential it needs is not configured on this deployment, or the service refused it.',
  'unsupported-format': 'The content was received and is intact, but it is in a form the pipeline cannot read (for example Luau bytecode or an unknown binary container).',
  'invalid-input': 'The input itself is not a complete program: it is empty, it is cut off, or it does not parse.',
};

/** The share of the recovered program's statement lines a behaviour comparison must reach before "identical" counts as validation. */
export const MIN_COVERAGE = 0.5;

const RETRIEVAL_AUTH = new Set(['not-configured', 'unauthorized']);
const RETRIEVAL_UNAVAILABLE = new Set(['no-route', 'not-found', 'failed', 'empty', 'not-code']);

/**
 * @param {object} ev evidence; every field is optional except where the pipeline reached that stage
 * @param {{status: string, reason?: string}} [ev.retrieval]   status: ok | no-route | not-configured | unauthorized | not-found | failed | empty | not-code
 * @param {{kind: string, parses?: boolean, truncated?: boolean, error?: string}} ev.input   kind: lua | luac | luajit | luau-bytecode | binary | empty | text
 * @param {boolean} [ev.obfuscated]
 * @param {{ok?: boolean, output?: string|null, parses?: boolean, residual?: string[], unresolved?: number, level?: string|null, error?: string}} [ev.recovery]
 * @param {{verdict: 'identical'|'different'|'inconclusive', against: 'original'|'input', note?: string}|null} [ev.behaviour]
 * @returns {{ outcome: string, label: string, success: boolean, reasons: string[], met: string[] }}
 */
export function classifyOutcome(ev) {
  const reasons = [];
  const met = [];
  const notes = [];
  const out = (outcome) => ({ outcome, label: label(outcome, ev), success: outcome === 'validated', reasons, met, notes });
  // what the script downloads when it runs is never part of the result, whatever the class: it is said on every result that has such parts
  const rm = ev.remote;
  if (rm && rm.places && rm.places.length) notes.push(`Not in this file: ${rm.places.length} part(s) the script downloads and runs when it runs (line${rm.places.length === 1 ? '' : 's'} ${rm.places.map((p) => p.line).join(', ')}). Nothing is recovered of them here; the Loader tab says whether they can be retrieved.`);

  // retrieval (only when the program came through a loader)
  const r = ev.retrieval;
  if (r) {
    if (RETRIEVAL_AUTH.has(r.status)) { reasons.push(r.reason || 'The credential this route needs is not available.'); return out('authorization-unavailable'); }
    if (RETRIEVAL_UNAVAILABLE.has(r.status)) { reasons.push(r.reason || 'The payload could not be obtained.'); return out('payload-unavailable'); }
    if (r.status !== 'ok') { reasons.push(`Unknown retrieval status "${r.status}".`); return out('payload-unavailable'); }
    met.push('retrieved through an authorised route');
  }

  // payload / input validation
  const inp = ev.input || { kind: 'empty' };
  if (inp.kind === 'empty') { reasons.push('The program is empty.'); return out('invalid-input'); }
  if (inp.truncated) { reasons.push(inp.error ? `The program is cut off: ${inp.error}.` : 'The program is cut off.'); return out('invalid-input'); }
  if (inp.kind === 'luau-bytecode' || inp.kind === 'binary') { reasons.push(inp.error || 'The content is not in a form the pipeline reads.'); return out('unsupported-format'); }
  if (inp.kind === 'text') { reasons.push(inp.error || 'The content is not Lua code.'); return out(r ? 'payload-unavailable' : 'invalid-input'); }
  if (inp.kind === 'lua' && inp.parses === false) { reasons.push(inp.error ? `The program does not parse: ${inp.error}.` : 'The program does not parse.'); return out('invalid-input'); }
  if (ev.obfuscated === false && ev.recovery) met.push('the input was not obfuscated: there was nothing to deobfuscate in this file');
  // a script that only downloads and runs its program: the program is not in the file, so there is nothing of it to reconstruct
  if (rm && rm.only && !r) { reasons.push(rm.why || 'This file only downloads and runs its program; the program is not in the file, so nothing of it is reconstructed here.'); return out('payload-unavailable'); }
  met.push(inp.kind === 'lua' ? (inp.repaired ? `the input parses as Lua after a documented repair: ${inp.repaired}` : 'the input parses as Lua') : `the input is ${inp.kind}`);

  // deobfuscation and syntax validation
  const rec = ev.recovery;
  if (!rec || (rec.output == null && !rec.hasOutput)) { reasons.push(rec && rec.error ? `The pipeline produced no output: ${rec.error}.` : 'The pipeline produced no output.'); return out('not-deobfuscated'); }
  if (rec.parses === false) { reasons.push('The output does not parse.'); return out('not-deobfuscated'); }
  met.push('the output parses');
  if (ev.obfuscated && ['none', 'minimal'].includes(rec.level)) { reasons.push(`The protection is essentially all still present (engine confidence: ${rec.level}).`); return out('not-deobfuscated'); }
  const residual = rec.residual || [];
  const left = [];
  if (residual.length) left.push(`obfuscation still detected in the output (${residual.join(', ')})`);
  if (rec.unresolved > 0) left.push(`${rec.unresolved} place(s) the engine could not resolve`);
  if (ev.obfuscated && rec.level === 'low') left.push('engine confidence is low');
  // a reconstruction whose functions are mostly signatures without bodies has not recovered them (Prompt XXVI)
  if (rec.bodies && rec.bodies.missingConstants > 0) left.push(`${rec.bodies.missingConstants} constant(s) are missing, written as (nil)[k] (holes, not code)`);
  if (ev.obfuscated && rec.bodies && rec.bodies.total >= 4 && rec.bodies.empty * 2 >= rec.bodies.total) left.push(`${rec.bodies.empty} of its ${rec.bodies.total} functions have no body (a signature is not a recovered function)`);

  // behavioural validation
  const b = ev.behaviour;
  if (b && b.verdict === 'different') {
    reasons.push(`It was run next to ${b.against === 'original' ? 'the authorised original' : 'the submitted program'} and behaved differently${b.note ? `: ${b.note}` : ''}.`);
    if (left.length) reasons.push(`Also: ${left.join('; ')}.`);
    return out('partial');
  }
  if (left.length) { reasons.push(`${left.join('; ')}.`.replace(/^./, (c) => c.toUpperCase())); return out('partial'); }
  met.push('no obfuscation is left in the output');
  if (!b) { reasons.push('Its behaviour was not compared with a reference.'); return out('syntax-valid-unverified'); }
  if (b.verdict !== 'identical') { reasons.push(`The behaviour comparison could not settle it${b.note ? `: ${b.note}` : ''}.`); return out('syntax-valid-unverified'); }
  // an identical run is evidence for what it reached: a run that took an early exit (an unsupported game, a missing key) and reached less than
  // half of the program's statements does not validate the program
  if (b.coverage != null && b.coverage < MIN_COVERAGE) { reasons.push(`The comparison run reached only ${Math.round(b.coverage * 100)}% of the program's statement lines; the rest was never run, so it is not validated.`); return out('syntax-valid-unverified'); }
  met.push(`behaved identically to ${b.against === 'original' ? 'the authorised original' : 'the submitted program'}`);
  return out('validated');
}

function label(outcome, ev) {
  // Prompt XXVI: a recognised protector whose interpreter is still in the output is not a reconstruction of any kind: the architecture is
  // known, the program is not. Said in those words, so a list of helper closures or a cleaned-up VM is never read as recovered source.
  if (outcome === 'not-deobfuscated' && ev.architecture) return `Architecture identified (${ev.architecture}); source unresolved`;
  if (outcome === 'not-deobfuscated' && !ev.retrieval) return 'Received but not successfully deobfuscated';
  // a file that was never obfuscated is not "reconstructed": the class is the same, the words say what happened
  if (outcome === 'validated' && ev.obfuscated === false) return 'Not obfuscated; the output behaves like the input (behaviourally validated)';
  return OUTCOMES[outcome];
}

/** Evidence about a submitted text, from the parser. A parse error at the very end of the text is a cut-off program. */
export function inputEvidence(text, parse) {
  if (text == null || !String(text).trim()) return { kind: 'empty' };
  const s = String(text);
  if (s.startsWith('\x1bLua')) return { kind: 'luac' };
  if (s.startsWith('\x1bLJ')) return { kind: 'luajit' };
  try { parse(text); return { kind: 'lua', parses: true }; } catch (e) {
    // raw bytes inside Lua strings are normal in obfuscated sources, so a text is called binary only when it also fails to parse
    let control = 0;
    const n = Math.min(s.length, 4096);
    for (let i = 0; i < n; i++) { const c = s.charCodeAt(i); if (c < 9 || (c > 13 && c < 32) || c === 127) control++; }
    if (control / n > 0.1) {
      const v = s.charCodeAt(0);
      return v >= 3 && v <= 6
        ? { kind: 'luau-bytecode', error: `The content looks like Luau bytecode (version byte ${v}); Luau bytecode is not decompiled here` }
        : { kind: 'binary', error: 'The content is binary data, not Lua source or a compiled Lua 5.1 chunk' };
    }
    const msg = String(e && e.message || e);
    // "near <eof>" (the text ran out inside a construct) or a string / comment that never closes, on the last line: cut off.
    // "'<eof>' expected near 'end'" is the opposite (too much text), and is an ordinary syntax error.
    const atEnd = (/near '?<eof>'?/.test(msg) || /unfinished (string|long string|long comment)/.test(msg)) && endsNear(text, e);
    return { kind: 'lua', parses: false, truncated: atEnd, error: msg };
  }
}

function endsNear(text, e) {
  const lines = String(text).split('\n');
  const line = e && e.line;
  if (!line) return true;
  // the error is reported on the last non-empty line (or the parser ran off the end): the text stops in the middle of something
  let last = lines.length;
  while (last > 1 && !lines[last - 1].trim()) last--;
  return line >= last;
}
