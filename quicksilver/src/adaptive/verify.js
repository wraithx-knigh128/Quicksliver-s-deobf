// Does the recovered program do what the original did?
//
// Nothing in the static checks can say that for certain, so this runs both programs in QuickSilver's own interpreter (never in the
// browser's JavaScript engine, never with access to anything but the stand-in environment of src/trace/) and compares what each one did:
// the calls it made and the properties it set, in order, what it printed, how it ended, and the globals it wrote.
//
// It is a comparison of one run each. Equal runs are evidence, not proof; different runs are a finding the person should look at. A run
// that was cut short by a limit (fuel, time) says nothing about what came after, and a program that waits on events that never come is
// compared up to the point where each stopped.

import { traceScript } from '../trace/trace.js';

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
 * @param {{fuel?: number, timeMs?: number}} [options]
 */
export function verifyRecovery(original, recovered, options = {}) {
  const limits = { fuel: options.fuel ?? 40_000_000, timeMs: options.timeMs ?? 8000 };
  const t0 = Date.now();
  const a = summarise(traceScript(original, limits));
  const b = summarise(traceScript(recovered, limits));
  const ms = Date.now() - t0;
  const notes = [];
  const cut = (x) => x.status === 'limit' || /^stopped/.test(x.ended || '');

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
  if (a.loads !== b.loads) notes.push(`The original loaded ${a.loads} chunk(s) of code at run time, the recovered program ${b.loads}; code that is loaded is compared by what it does.`);
  const idle = a.events.length === 0 && !a.output;
  if (idle) notes.push('The original did nothing the stand-in environment could observe, so this run is a weak check.');

  const verdict = difference ? 'different' : truncated || idle ? 'inconclusive' : 'identical';
  return {
    ok: true,
    verdict,
    summary: verdict === 'identical'
      ? `Both programs did the same thing in the sandbox: ${a.events.length} recorded event(s)${a.output ? ' and the same printed output' : ''}.`
      : verdict === 'different' ? 'The two programs behaved differently in the sandbox.' : 'The comparison could not settle it.',
    difference,
    notes,
    original: { status: a.status, events: a.events.length, output: a.output.length },
    recovered: { status: b.status, events: b.events.length, output: b.output.length },
    ms,
  };
}
