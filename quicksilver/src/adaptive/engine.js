// The adaptive engine.
//
// Every input is a new case. The engine does not ask which obfuscator made a script; it looks at what the code is made of, writes down what
// it finds as findings with their evidence, lets the strategies that handle those findings act, and keeps a change only if it can show it
// helped:
//
//   survey    every strategy's observer reads the tree and reports findings (each with a weight: how much obscurity it stands for);
//             the sum of the weights is the opacity score of the program
//   act       a strategy whose findings are open runs against a snapshot; the result is kept when it parses and prints back, introduces no
//             name the script did not already use, and does not raise the opacity score; otherwise the snapshot is restored and the reason
//             is recorded
//   repeat    what one strategy uncovers (a decoded string, an unflattened loop, an opened layer) is what the next one works on; the rounds
//             end when nothing changes, or when the budget is spent
//
// What is left is reported as such: each remaining finding with the reason it was not resolved. A strategy is an object with an `observe`
// (what is here) and a `run` (what to do about it); nothing else in the engine changes when one is added.

import { clone, walk } from '../core/walk.js';
import { print } from '../core/printer.js';
import { analyze } from '../core/scope.js';
import { parse, LuaSyntaxError } from '../core/parser.js';
import { snapshotUnused } from '../passes/simplify.js';
import { analyse } from './analysis.js';
import { defaultStrategies } from './strategies/index.js';

const now = () => (typeof performance !== 'undefined' ? performance.now() : Date.now());
const tryParse = (text) => {
  try { return { ok: true, ast: parse(text) }; } catch (e) {
    if (e instanceof LuaSyntaxError) return { ok: false, error: { message: e.message, line: e.line } };
    throw e;
  }
};
const round2 = (x) => Math.round(x * 100) / 100;
const countNodes = (ast) => { let n = 0; walk(ast, () => { n++; }); return n; };

export const DEFAULTS = Object.freeze({
  maxRounds: 6,
  budgetMs: 20000,
  sandbox: { enabled: false },
  foldCalls: 'obfuscation',
});

export class AdaptiveEngine {
  constructor(strategies = defaultStrategies()) {
    this.strategies = [...strategies].sort((a, b) => a.order - b.order);
  }

  register(strategy) {
    this.strategies.push(strategy);
    this.strategies.sort((a, b) => a.order - b.order);
    return this;
  }

  /** What the observers find in the program, and the opacity score that makes of it. Changes nothing. */
  observe(ast, an = analyse(ast)) {
    const findings = [];
    for (const s of this.strategies) {
      if (!s.observe) continue;
      let list = [];
      try { list = s.observe(ast, an) || []; } catch { list = []; }
      for (const f of list) findings.push({ ...f, strategy: s.id });
    }
    const parts = {};
    let score = 0;
    for (const f of findings) { score += f.weight; parts[f.kind] = round2((parts[f.kind] || 0) + f.weight); }
    return { findings, score: round2(score), parts };
  }

  /**
   * @param {object} ast the program (changed in place)
   * @param {object} [userOptions] sandbox, maxRounds, budgetMs, onProgress, unusedAtStart, rebuilt
   */
  run(ast, userOptions = {}) {
    const options = { ...DEFAULTS, ...userOptions, sandbox: { ...DEFAULTS.sandbox, ...(userOptions.sandbox || {}) } };
    const t0 = now();
    const decisions = [];
    const cx = {
      options,
      unusedAtStart: options.unusedAtStart || snapshotUnused(ast),
      rebuilt: !!options.rebuilt,
      cache: null,
      analyse(fresh = false) { if (fresh || !this.cache) this.cache = analyse(ast); return this.cache; },
    };

    const survey = () => {
      cx.cache = null;
      const an = cx.analyse(true);
      return this.observe(ast, an);
    };

    const restore = (snap) => { ast.body = snap.body; ast.endComments = snap.endComments; cx.cache = null; };
    const globalsOf = (chunk) => new Set(analyze(chunk).globals.keys());

    let state = survey();
    const first = state;
    const tried = new Set();
    const blocked = new Map();
    const refusals = new Map();       // line -> why, from strategies that looked and refused
    let accepted = 0;

    const attempt = (strategy, findings) => {
      const before = state.score;
      const snap = { body: clone(ast.body), endComments: ast.endComments };
      const globalsBefore = strategy.mayIntroduceGlobals ? null : globalsOf(ast);
      const nodesBefore = countNodes(ast);
      const started = now();
      cx.cache = null;
      let res;
      const entry = { n: decisions.length + 1, strategy: strategy.id, title: strategy.title, before, findings: findings ? findings.length : 0 };
      try { res = strategy.run(ast, cx, findings) || { changed: 0 }; } catch (e) {
        restore(snap);
        decisions.push({ ...entry, outcome: 'failed', changed: 0, after: before, ms: Math.round(now() - started), note: String(e && e.message ? e.message : e) });
        return 'failed';
      }
      entry.ms = Math.round(now() - started);
      if (res.skipped) { restore(snap); decisions.push({ ...entry, outcome: 'skipped', changed: 0, after: before, note: String(res.skipped) }); return 'skipped'; }
      if (res.notes) for (const n of res.notes) refusals.set(n.line, n.text);
      if (!res.changed) { restore(snap); decisions.push({ ...entry, outcome: 'noop', changed: 0, after: before, note: noteOf(res) }); return 'noop'; }

      // the change must leave a program that is still a program, and that does not talk about names it did not have before
      let reason = null;
      let text = null;
      try { text = print(ast); } catch (e) { reason = `the result cannot be printed: ${e.message}`; }
      if (!reason) {
        const re = tryParse(text);
        if (!re.ok) reason = `the result does not parse: ${re.error.message}`;
      }
      if (!reason && globalsBefore) {
        const after = globalsOf(ast);
        const added = [...after].filter((g) => !globalsBefore.has(g));
        if (added.length) reason = `it introduced names the script did not use (${added.slice(0, 3).join(', ')})`;
      }
      let next = null;
      if (!reason) {
        next = survey();
        // A strategy is judged by the findings it was called for: they must weigh less afterwards. The total may rise when taking one
        // disguise off shows another that was behind it (the opaque test inside a proxy), so it is reported and not used to decide.
        if (!strategy.cleanup) {
          const was = (findings || []).reduce((n, f) => n + f.weight, 0);
          const now_ = next.findings.filter((f) => f.strategy === strategy.id).reduce((n, f) => n + f.weight, 0);
          if (now_ > was + 1e-9 || (was > 0 && !(now_ < was - 1e-9))) reason = `it did not reduce what it was meant to (${round2(was)} \u2192 ${round2(now_)})`;
        }
        if (!reason && !strategy.cleanup && !strategy.mayGrow && countNodes(ast) > 1.6 * nodesBefore + 400) reason = 'the program grew by more than half';
      }
      if (reason) {
        restore(snap);
        decisions.push({ ...entry, outcome: 'rejected', changed: res.changed, after: before, note: reason });
        return 'rejected';
      }
      state = next;
      accepted++;
      if (strategy.rebuilds) cx.rebuilt = true;
      decisions.push({ ...entry, outcome: 'accepted', changed: res.changed, after: state.score, note: noteOf(res), detail: detailOf(res) });
      return 'accepted';
    };

    const cleanupChain = () => {
      let progressed = false;
      for (const s of this.strategies.filter((x) => x.cleanup).sort((a, b) => a.order - b.order)) {
        if (s.rebuilt && !cx.rebuilt) continue;
        const r = attempt(s, null);
        if (r === 'accepted') progressed = true;
      }
      return progressed;
    };

    // a program another reader has already rebuilt and checked is looked at, not touched
    if (options.observeOnly) options.maxRounds = 0;

    // a first look with the cheap clean-ups: constants folded and the outer wrapper gone expose what the observers look for
    if (!options.observeOnly) {
      for (const id of ['cleanup.wrapper', 'cleanup.fold']) {
        const s = this.strategies.find((x) => x.id === id);
        if (s) attempt(s, null);
      }
    }

    let rounds = 0;
    let outOfTime = false;
    for (; rounds < options.maxRounds; rounds++) {
      let progressed = false;
      for (const s of this.strategies) {
        if (s.cleanup || s.observeOnly) continue;
        if (now() - t0 > options.budgetMs) { outOfTime = true; break; }
        const findings = state.findings.filter((f) => f.strategy === s.id);
        if (!findings.length && !s.always) continue;
        if (s.needs && s.needs.includes('sandbox') && !options.sandbox.enabled) { blocked.set(s.id, 'sandbox'); continue; }
        const sig = `${s.id}:${findings.map((f) => `${f.kind}@${f.line}`).join(',')}`;
        if (tried.has(sig)) continue;
        const outcome = attempt(s, findings);
        if (outcome === 'accepted') progressed = true; else tried.add(sig);
        if (options.onProgress) options.onProgress({ phase: 'adaptive', done: rounds + 1, total: options.maxRounds, strategy: s.id });
      }
      if (outOfTime) break;
      if (progressed) for (let again = 0; again < 4 && cleanupChain(); again++);
      if (!progressed) break;
    }

    // ---- what is left ------------------------------------------------------------------------------------------------------
    const byStrategy = new Map(this.strategies.map((s) => [s.id, s]));
    const lastTry = new Map();
    for (const d of decisions) lastTry.set(d.strategy, d);
    const residual = state.findings.map((f) => {
      const s = byStrategy.get(f.strategy);
      let reason;
      if (s && s.observeOnly) reason = f.residual || 'no strategy takes this apart';
      else if (s && s.needs && s.needs.includes('sandbox') && !options.sandbox.enabled) reason = 'needs the sandbox (evaluating the script’s own functions), which is off';
      else if (refusals.has(f.line)) reason = refusals.get(f.line);
      else if (lastTry.get(f.strategy)) { const d = lastTry.get(f.strategy); reason = d.outcome === 'accepted' ? 'the strategy ran and this part remained' : `${d.outcome}${d.note ? `: ${d.note}` : ''}`; }
      else reason = options.observeOnly ? 'this program was rebuilt by another reader and is only looked at here' : outOfTime ? 'the time budget ran out before this was tried' : 'not tried';
      return { kind: f.kind, line: f.line, label: f.label, reason, strategy: f.strategy, weight: f.weight };
    });

    const kinds = new Map();
    for (const f of first.findings) kinds.set(f.kind, { kind: f.kind, found: 0, remaining: 0 });
    for (const f of first.findings) kinds.get(f.kind).found++;
    for (const f of state.findings) { if (!kinds.has(f.kind)) kinds.set(f.kind, { kind: f.kind, found: 0, remaining: 0 }); kinds.get(f.kind).remaining++; }
    for (const k of kinds.values()) k.resolved = Math.max(0, k.found - k.remaining);

    return {
      version: 1,
      ran: true,
      changed: accepted,
      rounds: rounds + 1,
      score: { before: first.score, after: state.score, partsBefore: first.parts, partsAfter: state.parts },
      hypotheses: first.findings.map((f) => ({ kind: f.kind, line: f.line, label: f.label, evidence: f.evidence, confidence: f.confidence, strategy: f.strategy })),
      kinds: [...kinds.values()],
      decisions,
      residual,
      blocked: [...blocked].map(([id, why]) => ({ strategy: id, why })),
      timedOut: outOfTime,
      ms: Math.round(now() - t0),
      rebuilt: cx.rebuilt,
      observeOnly: !!options.observeOnly,
    };
  }
}

function noteOf(res) {
  if (res.loops && res.loops.length) return `${res.loops.length} dispatch loop(s) rebuilt from ${res.loops.reduce((n, l) => n + l.states, 0)} states`;
  if (res.notes && res.notes.length) return res.notes.slice(0, 2).map((n) => `line ${n.line}: ${n.text}`).join('; ');
  if (res.inlined !== undefined) return `${res.inlined} call(s) replaced by their bodies`;
  if (res.decided) return `${res.decided.length} condition(s) decided`;
  if (res.skipped) return String(res.skipped);
  return '';
}

function detailOf(res) {
  const { changed, ...rest } = res;
  const out = {};
  for (const [k, v] of Object.entries(rest)) if (typeof v === 'number' || typeof v === 'string' || typeof v === 'boolean') out[k] = v;
  return out;
}

export function adaptiveRecover(ast, options) { return new AdaptiveEngine().run(ast, options); }
