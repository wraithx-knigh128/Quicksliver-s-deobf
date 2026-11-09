// Lab: behaviour, observed on the reference runtimes and cross-checked against QuickSilver's own interpreter.
//
// Two kinds of evidence, kept apart:
//   reference   a real runtime (PUC Lua 5.1, LuaJIT, ...) ran the program: this is what decides an experiment when it is available
//   sandbox     QuickSilver's interpreter ran it: always run, used as a cross-check, and the fallback when no reference runtime is installed
// When the two disagree about whether a reconstruction behaves like its original, that is not averaged away: the record says `disagreement`, and the
// knowledge base counts it, because each one is a bug in one of the two.

import { runSource } from '../../src/sandbox/sandbox.js';
import { oracle } from '../runtime/oracle.mjs';

const LIMITS = { fuel: 30_000_000, timeMs: 6000 };

/** The runtimes that decide experiments, among those installed. The programs are plain Lua 5.1 style, so the 5.1 family. */
export async function referenceRuntimes(want = ['lua51', 'luajit']) {
  const found = await oracle().detect();
  return want.filter((id) => found.find((r) => r.id === id && r.available));
}

export function sandboxRun(source) {
  const r = runSource(source, LIMITS);
  return { ok: r.ok, output: r.output, error: r.error || null, limited: r.kind === 'limit' };
}

/** Run a program everywhere it is to be checked. @returns {{sandbox: object, reference: Object<string, object>}} */
export async function observeBehaviour(source, runtimes) {
  const reference = {};
  for (const id of runtimes) {
    const r = await oracle().run(id, source, { timeoutMs: 20_000 });
    reference[id] = { ok: r.ok, output: r.stdout, error: r.error, limited: !!(r.timedOut || /instruction budget/.test(r.error || '')), unavailable: !!r.unavailable };
  }
  return { sandbox: sandboxRun(source), reference };
}

const verdictOf = (original, got) => {
  if (!original.ok || !original.output.trim() || original.limited || got.limited || got.unavailable || original.unavailable) return 'inconclusive';
  return got.ok === original.ok && got.output === original.output ? 'identical' : 'different';
};

/**
 * Compare a program's behaviour with its original's.
 * @returns {{verdict: string, source: 'reference'|'sandbox', per: Object<string,string>, disagreement: boolean, difference: object|null}}
 */
export function compareBehaviour(original, got) {
  const per = { sandbox: verdictOf(original.sandbox, got.sandbox) };
  for (const id of Object.keys(original.reference)) per[id] = verdictOf(original.reference[id], got.reference[id]);
  const refs = Object.keys(original.reference);
  let verdict;
  let source;
  if (refs.length) {
    source = 'reference';
    const v = refs.map((id) => per[id]);
    verdict = v.includes('different') ? 'different' : v.every((x) => x === 'identical') ? 'identical' : 'inconclusive';
  } else { source = 'sandbox'; verdict = per.sandbox; }
  const conclusive = (x) => x === 'identical' || x === 'different';
  const disagreement = refs.length > 0 && conclusive(per.sandbox) && conclusive(verdict) && per.sandbox !== verdict;
  let difference = null;
  if (verdict === 'different') {
    const id = source === 'reference' ? refs.find((r) => per[r] === 'different') : 'sandbox';
    const a = id === 'sandbox' ? original.sandbox : original.reference[id];
    const b = id === 'sandbox' ? got.sandbox : got.reference[id];
    difference = { runtime: id, original: a.output.slice(0, 160), got: b.ok ? b.output.slice(0, 160) : `error: ${b.error}` };
  }
  return { verdict, source, per, disagreement, difference };
}
