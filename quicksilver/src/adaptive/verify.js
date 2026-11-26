// Does the recovered program do what the original did?
//
// Nothing in the static checks can say that for certain, so this runs both programs in QuickSilver's own interpreter (never in the
// browser's JavaScript engine, never with access to anything but the stand-in environment of src/trace/) and compares what each one did:
// the calls it made and the properties it set, in order, what it printed, how it ended, and the globals it wrote.
//
// It is a comparison of one run each. Equal runs are evidence, not proof; different runs are a finding the person should look at. A run
// that was cut short by a limit (fuel, time) says nothing about what came after, and a program that waits on events that never come is
// compared up to the point where each stopped.

import { traceScript, TRACE_LIMITS } from '../trace/trace.js';

const strip = (s) => (s == null ? s : String(s).replace(/\btrace:\d+:\s*/g, ''));

function summarise(t) {
  return {
    status: t.status,
    ended: t.ended,
    error: strip(t.error),
    output: t.output,
    events: t.events.filter((e) => e.kind !== 'load').map((e) => ({ kind: e.kind, text: strip(e.text) })),
    loads: t.layers.length,
    writes: [...t.globalWrites].sort(),
    requests: [...t.requests].sort(),
    stats: t.stats,
  };
}

/**
 * @param {string} original binary string
 * @param {string} recovered binary string
 * @param {{fuel?: number, timeMs?: number, maxWaits?: number, originalPrelude?: string[], runtimeGlobals?: {names?: string[], fromSource?: string[]}, needsMainReference?: boolean}} [options]
 *   originalPrelude: events a format's own runtime makes before the program starts (MoonSec V3 calls wait() once); when the original's run
 *   starts with them and the recovered program's does not, they are not counted, the waits among them are not charged to the original's
 *   wait budget, and the note says so.
 *   runtimeGlobals: globals a format's own runtime writes, which the program it protects does not: `names` (exact) and `fromSource`
 *   (regular-expression sources run on the original's text; the first capture is such a name). They are left out of the original's
 *   written globals only when the recovered program does not write them, and the note names them.
 *   needsMainReference: when the original's first event is a call of one of the stand-in arguments the sandbox passes to a script
 *   (`arg1(…)`), the original only ran as a callback of something absent, and its run is no reference for the rebuilt program.
 */
export function verifyRecovery(original, recovered, options = {}) {
  const limits = { fuel: options.fuel ?? 40_000_000, timeMs: options.timeMs ?? 8000, ...(options.maxWaits ? { maxWaits: options.maxWaits } : {}) };
  const t0 = Date.now();
  const prelude = Array.isArray(options.originalPrelude) ? options.originalPrelude : [];
  // Prompt XXX: a wait the obfuscator's runtime makes before the program starts also spends one of the sandbox's waits. A program that
  // waits in a loop (`while true do wait() … end`) is stopped when they run out, so the original's loop ran one round fewer than the
  // rebuilt program's and every later event moved: MoonSec V3 sample 3fed8cb5 was reported as "different" for that alone (with one more
  // wait for the original, the two runs are identical event for event at 400, 200 and 50 waits). The original gets one more wait for
  // each wait in the prelude; if the prelude turns out not to apply, it is traced again with the ordinary budget.
  const preludeWaits = prelude.filter((p) => /^(?:task\.)?wait\(/.test(p)).length;
  const traceOriginal = (extra) => summarise(traceScript(original, extra ? { ...limits, maxWaits: (options.maxWaits ?? TRACE_LIMITS.maxWaits) + extra } : limits));
  let a = traceOriginal(preludeWaits);
  // the recovered program's run is the one whose claim is being checked: how much of it the run reached is recorded with the verdict
  const tb = traceScript(recovered, { ...limits, coverage: true });
  const b = summarise(tb);
  const coverage = tb.coverage || null;
  const notes = [];
  const cut = (x) => x.status === 'limit' || /^stopped/.test(x.ended || '');
  const startsWith = (x) => prelude.every((p, i) => x.events[i] && x.events[i].text === p);
  const preludeApplies = prelude.length > 0 && startsWith(a) && !startsWith(b);
  if (preludeWaits && !preludeApplies) a = traceOriginal(0);
  const ms = Date.now() - t0;
  if (preludeApplies) {
    a.events = a.events.slice(prelude.length);
    notes.push(`The original's first event${prelude.length > 1 ? 's' : ''} (${prelude.join(', ')}) ${prelude.length > 1 ? 'are' : 'is'} made by the obfuscator's own runtime before the program starts, so ${prelude.length > 1 ? 'they were' : 'it was'} not compared${preludeWaits ? ` and the original was given ${preludeWaits} more wait${preludeWaits > 1 ? 's' : ''} in the sandbox to make up for ${preludeWaits > 1 ? 'them' : 'it'}` : ''}.`);
  }
  // Prompt XXX: the protection's own globals (MoonSec V3: the name its banner line assigns, and MoonSec_StringsHiddenAttr) were counted as
  // a difference in every keyless MoonSec result, so none could be verified (the XXIX batch script did not compare globals and
  // reported 31 identical; the product's comparison reported those 31 as "wrote globals" differences)
  const rg = options.runtimeGlobals;
  if (rg && (rg.names || rg.fromSource)) {
    const own = new Set(rg.names || []);
    for (const src of rg.fromSource || []) {
      let re;
      try { re = new RegExp(src, 'g'); } catch { continue; }
      for (const m of String(original).matchAll(re)) if (m[1]) own.add(m[1]);
    }
    const mine = new Set(b.writes);
    const dropped = a.writes.filter((w) => own.has(w) && !mine.has(w));
    if (dropped.length) {
      a.writes = a.writes.filter((w) => !dropped.includes(w));
      notes.push(`The original also wrote ${dropped.join(', ')}: global${dropped.length > 1 ? 's' : ''} of the obfuscator's own runtime, not of the program, so ${dropped.length > 1 ? 'they were' : 'it was'} not compared.`);
    }
  }
  if (options.needsMainReference && a.events[0] && /^arg\d+\(/.test(a.events[0].text)) {
    return {
      ok: true,
      verdict: 'inconclusive',
      summary: 'The comparison could not settle it: the original did not run as a program in the sandbox.',
      difference: null,
      notes: [...notes, `The original's first act was to call one of the stand-in arguments the sandbox passes to a script (${a.events[0].text}): it runs only when something outside it calls it in a particular way, so its run is no reference for the rebuilt program.`],
      coverage,
      original: { status: a.status, events: a.events.length, output: a.output.length },
      recovered: { status: b.status, events: b.events.length, output: b.output.length },
      ms: Date.now() - t0,
      reference: 'none',
    };
  }

  // a run that ran out of fuel or time only tells us how far it got; compare the part both did
  let n = Math.min(a.events.length, b.events.length);
  const truncated = cut(a) || cut(b);
  if (truncated) notes.push(`${cut(a) ? 'The original' : 'The recovered program'} was stopped by a limit (${(cut(a) ? a : b).ended}); only the events both runs reached were compared.`);
  if (!truncated) n = Math.max(a.events.length, b.events.length);

  let difference = null;
  for (let i = 0; i < n; i++) {
    const x = a.events[i];
    const y = b.events[i];
    if (!x || !y || x.kind !== y.kind || x.text !== y.text) {
      difference = { index: i, original: x ? x.text : '(the original does nothing more)', recovered: y ? y.text : '(the recovered program does nothing more)' };
      break;
    }
  }
  if (!difference && !truncated) {
    if (a.output !== b.output) difference = { index: -1, original: `printed ${JSON.stringify(a.output.slice(0, 120))}`, recovered: `printed ${JSON.stringify(b.output.slice(0, 120))}` };
    else if (a.status !== b.status) difference = { index: -1, original: `ended: ${a.ended}`, recovered: `ended: ${b.ended}` };
    else if (a.error !== b.error) difference = { index: -1, original: `error: ${a.error}`, recovered: `error: ${b.error}` };
    else if (a.writes.join() !== b.writes.join()) difference = { index: -1, original: `wrote globals: ${a.writes.join(', ') || 'none'}`, recovered: `wrote globals: ${b.writes.join(', ') || 'none'}` };
  }
  // Prompt XXIX: a rebuilt VM program has none of the original's variable names, so the same error names a different variable; the verdict
  // stays "different" (the check is not loosened), and the note says what the difference is
  const unnamed = (e) => String(e || '').replace(/\s*\((?:local|global|field|upvalue|method|constant) '[^']*'\)/g, '');
  if (difference && difference.index === -1 && a.error && b.error && a.error !== b.error && unnamed(a.error) === unnamed(b.error)) {
    notes.push(`Both runs did the same ${a.events.length} thing(s) and stopped with the same error (${unnamed(a.error)}); the messages differ only in the variable they name, which a rebuilt program does not keep.`);
  }
  if (a.loads !== b.loads) notes.push(`The original loaded ${a.loads} chunk(s) of code at run time, the recovered program ${b.loads}; code that is loaded is compared by what it does.`);
  const idle = a.events.length === 0 && !a.output;
  if (idle) notes.push('The original did nothing the stand-in environment could observe, so this run is a weak check.');

  if (coverage && coverage.ratio < 1) notes.push(`The run reached ${coverage.linesRun} of the recovered program's ${coverage.statementLines} statement lines (${Math.round(coverage.ratio * 100)}%); what it did not reach was not compared.`);
  const verdict = difference ? 'different' : truncated || idle ? 'inconclusive' : 'identical';
  return {
    ok: true,
    verdict,
    summary: verdict === 'identical'
      ? `Both programs did the same thing in the sandbox: ${a.events.length} recorded event(s)${a.output ? ' and the same printed output' : ''}.`
      : verdict === 'different' ? 'The two programs behaved differently in the sandbox.' : 'The comparison could not settle it.',
    difference,
    notes,
    coverage,
    original: { status: a.status, events: a.events.length, output: a.output.length },
    recovered: { status: b.status, events: b.events.length, output: b.output.length },
    ms,
  };
}
