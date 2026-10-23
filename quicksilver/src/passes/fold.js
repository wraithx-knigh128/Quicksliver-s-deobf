// Constant folding: replaces constant sub-expressions by their value.
//
//   "ab" .. "cd"            -> "abcd"
//   string.char(72, 105)    -> "Hi"
//   (3 * 7) % 5 == 1        -> true
//   not (a == b)            -> a ~= b
//   true and f(x)           -> f(x)
//
// Only the *untouched* standard library is evaluated: `string` must be a global that nothing in the
// script assigns to, otherwise `string.char(...)` could mean anything.

import { transform } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import {
  NOT_CONST, evalBinary, evalUnary, evalLibCall, evalGlobalCall, evalStringMethod,
} from './consteval.js';

export const PURE_LIBS = new Set(['string', 'math', 'bit32', 'bit']);

/**
 * Library calls that obfuscators use to hide literals. Folding them recovers the literal.
 * Everything else (string.format, math.floor, ...) is ordinary program code: folding it would
 * evaluate the program instead of un-obfuscating it, so it is only done when asked for.
 */
const OBFUSCATION_CALLS = new Set([
  'string.char', 'string.byte', 'string.sub', 'string.rep', 'string.reverse', 'string.len',
]);
const foldable = (lib, name, mode) => mode === 'all' || OBFUSCATION_CALLS.has(`${lib}.${name}`) || lib === 'bit32' || lib === 'bit';
const PURE_GLOBAL_FUNCS = new Set(['tostring', 'tonumber', 'type']);

/** Value of a literal expression, or NOT_CONST. */
export function constOf(e) {
  switch (e.type) {
    case 'Nil': return undefined;
    case 'True': return true;
    case 'False': return false;
    case 'Number': return e.value;
    case 'String': return e.value;
    case 'Paren': return constOf(e.expr);
    default: return NOT_CONST;
  }
}

export function makeConst(v) {
  if (v === undefined) return { type: 'Nil' };
  if (v === true) return { type: 'True' };
  if (v === false) return { type: 'False' };
  if (typeof v === 'number') return { type: 'Number', value: v, raw: null };
  return { type: 'String', value: v, raw: null };
}

/** `x and f()` keeps only f's first result; once the `and` is gone we must keep that truncation. */
const single = (e) => (e.type === 'Call' || e.type === 'MethodCall' || e.type === 'Vararg' ? { type: 'Paren', expr: e } : e);

const keyName = (index) => (index.key.type === 'String' ? index.key.value : null);

/** The name of an untouched standard global (`string`, `tostring`, ...), or null. */
function stdGlobal(node, info) {
  if (node.type !== 'Name') return null;
  const v = info.varOf.get(node);
  if (!v || !v.isGlobal || v.writes.length > 0) return null;
  return node.name;
}

/** `string.char` style callee -> ['string', 'char'], else null. */
function libCallee(fn, info) {
  if (fn.type !== 'Index') return null;
  const lib = stdGlobal(fn.obj, info);
  const name = keyName(fn);
  return lib && name && PURE_LIBS.has(lib) ? [lib, name] : null;
}

export function foldPass(chunk, ctx = {}) {
  let total = 0;
  for (let round = 0; round < 16; round++) {
    const info = analyze(chunk);
    let changed = 0;
    const replaced = (node) => { changed++; return node; };

    transform(chunk, {
      stmt(s) {
        // `for i = a, b, 1 do` is `for i = a, b do`: the step defaults to 1
        if (s.type === 'NumFor' && s.step && s.step.type === 'Number' && s.step.value === 1) { s.step = null; changed++; }
        return undefined;
      },
      expr(e) {
        switch (e.type) {
          case 'Paren':
            // Parentheses only matter for calls / varargs, where they truncate to one value.
            if (e.expr.type !== 'Call' && e.expr.type !== 'MethodCall' && e.expr.type !== 'Vararg') return replaced(e.expr);
            return undefined;

          case 'Unary': {
            const v = constOf(e.arg);
            if (v !== NOT_CONST) {
              const r = evalUnary(e.op, v);
              if (r !== NOT_CONST) return replaced(makeConst(r));
            }
            if (e.op === 'not' && e.arg.type === 'Binary' && (e.arg.op === '==' || e.arg.op === '~=')) {
              return replaced({ type: 'Binary', op: e.arg.op === '==' ? '~=' : '==', left: e.arg.left, right: e.arg.right });
            }
            return undefined;
          }

          case 'Binary': {
            const a = constOf(e.left);
            const b = constOf(e.right);
            if (a !== NOT_CONST && b !== NOT_CONST) {
              const r = evalBinary(e.op, a, b);
              if (r !== NOT_CONST) return replaced(makeConst(r));
            }
            if (a !== NOT_CONST && (e.op === 'and' || e.op === 'or')) {
              // The left operand decides which side survives.
              const truthy = a !== undefined && a !== false;
              if (e.op === 'and') return replaced(truthy ? single(e.right) : e.left);
              return replaced(truthy ? e.left : single(e.right));
            }
            return undefined;
          }

          case 'Call': {
            const args = e.args.map(constOf);
            if (args.some((a) => a === NOT_CONST)) return undefined;
            const callee = libCallee(e.fn, info);
            let r = NOT_CONST;
            if (callee) { if (foldable(callee[0], callee[1], ctx.foldCalls)) r = evalLibCall(callee[0], callee[1], args); }
            else {
              const g = stdGlobal(e.fn, info);
              if (g && PURE_GLOBAL_FUNCS.has(g)) r = evalGlobalCall(g, args);
            }
            return r === NOT_CONST ? undefined : replaced(makeConst(r));
          }

          case 'MethodCall': {
            const recv = constOf(e.obj);
            if (typeof recv !== 'string') return undefined;
            const args = e.args.map(constOf);
            if (args.some((a) => a === NOT_CONST)) return undefined;
            if (!foldable('string', e.name, ctx.foldCalls)) return undefined;
            const r = evalStringMethod(e.name, recv, args);
            return r === NOT_CONST ? undefined : replaced(makeConst(r));
          }

          default: return undefined;
        }
      },
    });

    total += changed;
    if (!changed) break;
  }
  if (ctx.log) ctx.log('fold', total);
  return { changed: total };
}
