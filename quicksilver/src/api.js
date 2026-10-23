// The engine's public surface. Every function takes a binary string (see core/bytes.js) and returns
// plain, structured-clone-safe data, so the same calls work on the main thread, in the web worker and
// from Node (tests, tooling).

import { parse, LuaSyntaxError } from './core/parser.js';
import { print } from './core/printer.js';
import { formatTokens } from './core/format-tokens.js';
import { detect } from './detect/detect.js';
import { FAMILIES } from './detect/families.js';
import { analyzeScript } from './analyze/report.js';
import { toLuast } from './analyze/luast.js';
import { recover } from './recover/pipeline.js';
import { diffLines, toRows } from './core/diff.js';
import { traceScript } from './trace/trace.js';

export const ENGINE_VERSION = '1.0.0';

const now = () => (typeof performance !== 'undefined' ? performance.now() : Date.now());
const timed = (fn) => { const t = now(); const r = fn(); r.ms = Math.round(now() - t); return r; };

/** Classify raw input before doing anything with it. */
export function inspectInput(source) {
  if (source.charCodeAt(0) === 27) {
    const d = detect(source);
    return { kind: 'bytecode', detail: d.bytecode, message: 'This is a compiled Lua chunk, not source text.' };
  }
  let ctrl = 0;
  const n = Math.min(source.length, 4096);
  for (let i = 0; i < n; i++) { const c = source.charCodeAt(i); if (c < 9 || (c > 13 && c < 32)) ctrl++; }
  if (n && ctrl / n > 0.05) return { kind: 'binary', message: 'The input contains many control characters and does not look like Lua source.' };
  return { kind: 'text' };
}

export function detectScript(source) {
  return timed(() => ({ ok: true, detection: detect(source) }));
}

/**
 * Format only: nothing is decoded or removed. Parseable code goes through the AST printer; code that does
 * not parse is re-flowed token by token, and the result says which of the two happened.
 * @param {{indent?: string, width?: number, blankLines?: string}} [options]
 */
export function beautifyScript(source, options = {}) {
  return timed(() => {
    const printOptions = {
      indent: options.indent ?? '  ',
      width: options.width ?? 100,
      blankLines: options.blankLines ?? 'smart',
      strings: 'preserve',
      numbers: 'preserve',
    };
    try {
      const ast = parse(source);
      return { ok: true, mode: 'ast', output: print(ast, printOptions), warnings: [] };
    } catch (e) {
      if (!(e instanceof LuaSyntaxError)) throw e;
      const text = formatTokens(source, { indent: printOptions.indent });
      if (text === null) return { ok: false, mode: 'none', error: { message: e.message, line: e.line, col: e.col }, output: null, warnings: [] };
      return {
        ok: true,
        mode: 'tokens',
        output: text,
        parseError: { message: e.message, line: e.line, col: e.col },
        warnings: [`The code does not parse (${e.message}), so only its layout was repaired token by token.`],
      };
    }
  });
}

export function analyzeSource(source) {
  return timed(() => analyzeScript(source));
}

export function recoverSource(source, options = {}) {
  return timed(() => recover(source, options));
}

export function luast(source, options = {}) {
  return timed(() => {
    try {
      return { ok: true, ...toLuast(parse(source), options) };
    } catch (e) {
      if (!(e instanceof LuaSyntaxError)) throw e;
      return { ok: false, error: { message: e.message, line: e.line, col: e.col } };
    }
  });
}

/**
 * Run the script in the instrumented sandbox and report what it did (see trace/trace.js). This is the only
 * operation that executes anything; the interface asks the user first.
 */
export function traceSource(source, options = {}) {
  return timed(() => traceScript(source, options));
}

/** Line diff of two texts, as side-by-side rows (see core/diff.js). */
export function diffSources(a, b) {
  return timed(() => {
    const A = a.split(/\r?\n/);
    const B = b.split(/\r?\n/);
    return { ok: true, ...toRows(diffLines(A, B)), aLines: A.length, bLines: B.length };
  });
}

/** Static description of every known family, for the compatibility dashboard. */
export function familyRegistry() {
  return Object.entries(FAMILIES).map(([id, f]) => ({ id, ...f }));
}
