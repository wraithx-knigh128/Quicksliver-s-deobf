// Checks on a rebuilt program that need no run of it. They cannot show that it behaves like the original; they show that it is not obviously
// wrong: every readable constant the program's instructions use is in the text, nothing refers to a register that was never declared, and
// every function was structured into statements (none left as labels and jumps).

import { walk } from '../../core/walk.js';
import { analyze } from '../../core/scope.js';

const READABLE = /^[\x20-\x7e\n\t]*$/;
/** Names the lifter gives to registers and captured variables, as they would look if one were read without ever being assigned. */
const LIFTER_NAME = /^(?:[rstuvwxyzqo]\d+|d\d+_\d+|up\d+|va_list|va_n)$/;

/**
 * @param {object} chunk   the script with the rebuilt program in place
 * @param {object[]} protos  the prototypes that were rebuilt
 * @param {{protos: number, goto: number}} stats
 */
export function validateLift(chunk, protos, stats, constFields) {
  const present = new Set();
  // a constant the program uses as a name appears as a global, a method name or a field name rather than as a string
  walk(chunk, (n) => {
    if (n.type === 'String') present.add(n.value);
    else if (n.type === 'Name') present.add(n.name);
    else if (n.type === 'MethodCall') present.add(n.name);
    else if (n.type === 'Table') for (const f of n.fields) if (f.kind === 'named') present.add(f.key);
  });
  const used = new Set();
  for (const p of protos) for (const ins of p.code) for (const k of constFields) { const f = ins[k]; if (f && typeof f === 'object' && typeof f.v === 'string' && f.v.length >= 3 && READABLE.test(f.v)) used.add(f.v); }
  const missing = [...used].filter((s) => !present.has(s));
  const undeclared = [...analyze(chunk).globals.keys()].filter((n) => LIFTER_NAME.test(n));
  return {
    constants: { readable: used.size, missing: missing.length, sample: missing.slice(0, 5) },
    undeclared,
    functions: stats.protos,
    unstructured: stats.goto,
    ok: !missing.length && !undeclared.length && !stats.goto,
  };
}
