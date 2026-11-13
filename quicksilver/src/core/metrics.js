// The categories a result is measured in, each with one definition that can be run again.
//
// A tool's name being recognised is not a recovered program, and a recovered program that prints the right text is not necessarily the program. So a result is described by
// six numbers that mean different things and are never averaged into one:
//
//   identification        the detector names the tool (confidence >= 0.5) and, where the fixture knows it, the version             tests/tools-scorecard.mjs  (`detected`)
//   structural recovery   structureScore(original, recovered): F1 of the multiset of parent>child node-type edges of the two syntax trees. Identifier names, string
//                         and number values and comments are ignored; so is the order of siblings. 1.0 = the same shape of program (the same statements nested the same way)
//   semantic recovery     fidelity(original, recovered) (src/core/fidelity.js): Dice coefficient of the longest common subsequence of the semantic-token streams (node kinds,
//                         operators, literal values, locals by order of declaration, globals by name), over at most the first 6000 tokens of each
//   runtime equivalence   the recovered script, run on a real runtime (PUC Lua 5.1 / LuaJIT / Lua 5.4 through lupa, Luau 0.739), prints what the original program prints on
//                         the same runtime: same | different | error | not checked
//   completeness          residualIndicators(recovered) is empty (the detector finds in the OUTPUT no tool with unrecoverable evidence, no state loop, no embedded bytecode, no
//                         string-table rotation, no junk code, no opaque predicates, no escape-encoded strings and no VM interpreter) AND the engine's report lists nothing
//                         unresolved. A count, not a percentage
//   stability             wall-clock milliseconds of the whole recovery, whether it threw, and whether the recovered text parses (an exception or an unparsable output is a failure)
//
// Every function here is pure and deterministic.

import { parse } from './parser.js';
import { detect } from '../detect/detect.js';
import { profileVm } from '../recover/vmprofile.js';

const SKIP = new Set(['type', 'line', 'pos', 'endPos', 'endLine', 'comments', 'trailing', 'endComments', 'features', 'raw', 'value', 'name', 'dot']);

/** parent>child edges of a syntax tree, as a multiset, with the operator kept where the node has one. Names, values and comments take no part. */
export function treeEdges(ast) {
  const edges = new Map();
  const label = (n) => (n.type === 'Binary' || n.type === 'Unary' || n.type === 'CompoundAssign' ? `${n.type}${n.op || ''}` : n.type === 'MethodCall' ? 'MethodCall' : n.type);
  const add = (a, b) => edges.set(`${a}>${b}`, (edges.get(`${a}>${b}`) || 0) + 1);
  const visit = (n, parent) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { for (const x of n) visit(x, parent); return; }
    if (typeof n.type !== 'string') {
      // clauses of an if, fields of a table: look through them
      for (const k of Object.keys(n)) if (!SKIP.has(k) && n[k] && typeof n[k] === 'object') visit(n[k], parent);
      return;
    }
    if (n.type === 'Paren') { visit(n.expr, parent); return; }       // parentheses carry no structure
    if (n.type === 'Name' || n.type === 'Id') return;                // names take no part
    const l = label(n);
    if (parent) add(parent, l);
    for (const k of Object.keys(n)) if (!SKIP.has(k) && n[k] && typeof n[k] === 'object') visit(n[k], l);
  };
  visit(ast, null);
  return edges;
}

/** F1 of two edge multisets: 1 for the same shape, 0 for nothing in common. */
export function structureScore(reference, recovered) {
  const a = treeEdges(parse(reference));
  const b = treeEdges(parse(recovered));
  let na = 0; let nb = 0; let both = 0;
  for (const v of a.values()) na += v;
  for (const v of b.values()) nb += v;
  if (!na && !nb) return 1;
  for (const [k, v] of a) both += Math.min(v, b.get(k) || 0);
  return (2 * both) / (na + nb);
}

/** The distinct string literals of a program (the values, after escapes are read). */
export function stringLiterals(source) {
  const out = new Set();
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { for (const x of n) visit(x); return; }
    if (n.type === 'String' && typeof n.value === 'string') out.add(n.value);
    for (const k of Object.keys(n)) if (k !== 'line' && n[k] && typeof n[k] === 'object') visit(n[k]);
  };
  visit(parse(source));
  return out;
}

/**
 * Of the strings the original program contains, the share that appears among the constants read out of a virtual machine's data: what a profile of bytecode that was not lifted
 * still tells a reader about the program. Strings of one character are left out (a separator is in any constant table), and so is every string the compiler would have no
 * reason to keep as a constant (none: all literals are constants). null when the original has no string worth counting.
 */
export function vmConstantsRecall(original, constants) {
  const wanted = [...stringLiterals(original)].filter((x) => x.length >= 2);
  if (!wanted.length) return null;
  const have = new Set((constants || []).filter((v) => typeof v === 'string'));
  return wanted.filter((x) => have.has(x)).length / wanted.length;
}

const HARD_TRAITS = ['state-machine', 'bytecode-blob', 'string-table', 'junk-code', 'opaque-predicates', 'escape-encoded-strings'];

/** What the output still shows of an obfuscator: ids of the traits and of the families with unrecoverable evidence. Empty = complete. */
export function residualIndicators(output, detection = null) {
  const d = detection || detect(output);
  const out = [];
  for (const t of d.traits || []) if (HARD_TRAITS.includes(t.id)) out.push(`trait:${t.id}`);
  for (const f of d.families || []) if (f.confidence >= 0.5 && f.evidence.some((e) => e.unrecoverable)) out.push(`family:${f.id}`);
  // a virtual machine left in the output is recognised by its data and its interpreter, not by a banner or a name, so that renaming cannot hide it
  try { if (profileVm(parse(output), { sandbox: { enabled: false } })) out.push('vm:interpreter'); } catch { /* an output that does not parse is reported by the caller */ }
  return out;
}

/** The whole description of one result against its reference. `behaviour` is whatever the caller observed on a runtime (or null when it was not checked). */
export function describeResult({ original, input, output, detected, expected, expectedVersion, version, ms, threw, behaviour, unresolved = 0 }) {
  const parses = (() => { try { parse(output); return true; } catch { return false; } })();
  const row = { identified: !!detected, versionRight: expectedVersion ? version === expectedVersion : null, runtime: behaviour == null ? 'not checked' : behaviour, stability: { ms, threw: !!threw, parses } };
  if (parses && original) {
    try { row.structure = structureScore(original, output); } catch { row.structure = null; }
  } else row.structure = null;
  row.residual = parses ? residualIndicators(output) : ['unparsable'];
  row.complete = parses && row.residual.length === 0 && !unresolved;
  return row;
}

/** One definition per category, in words, shared by the database, the compatibility page and the documentation. */
export const METHODS = {
  identification: 'The detector names the tool with confidence >= 0.5 on the obfuscated fixture (and, where the fixture records a version, the version it reads equals it). Reported as detected / fixtures.',
  structure: 'structureScore(original, recovered): F1 of the multiset of parent>child node-type edges of the two syntax trees; names, literal values, comments, parentheses and sibling order are ignored. 1.0 = the same shape of program. Mean over fixtures whose output parses.',
  semantic: 'fidelity(original, recovered): Dice coefficient of the longest common subsequence of the semantic-token streams (node kinds, operators, literal values, locals by order of declaration, globals by name), over the first 6000 tokens of each. Mean over fixtures whose output parses.',
  runtime: 'The recovered script and the original program are run on the same real runtime (PUC Lua 5.1 / LuaJIT / Lua 5.4 through lupa, or Luau 0.739) and their captured output compared. Counted only where the obfuscator\u2019s own output behaved like the original, so a tool defect is never charged to the engine. same / judged.',
  completeness: 'Both of: residualIndicators(recovered) is empty (the detector finds in the recovered text no tool with unrecoverable evidence, none of the traits state-machine, bytecode-blob, string-table, junk-code, opaque-predicates, escape-encoded-strings, and no virtual machine\u2019s function records and interpreter), and the engine\u2019s own report lists nothing left unresolved. complete / fixtures.',
  vmConstants: 'Only for builds that keep the program as VM bytecode and were not lifted: vmConstantsRecall(original, vm.constants), the share of the original\u2019s string literals (two characters or more) that appear among the constants read from the script\u2019s own decryptor, with none of the program run. A profile of the data, not a reconstruction. Mean over VM fixtures.',
  stability: 'Wall-clock milliseconds of one recover() call (sandboxed evaluation on) on the reference machine; failures = fixtures whose recovery threw or whose output does not parse.',
};
