// What is inside a virtual machine that was not lifted.
//
// A build that keeps the program as bytecode for a generated interpreter cannot be turned back into source by the passes that read syntax, and for most of these formats no
// lifter exists. That does not make the script opaque: the bytecode is data, and the data has a shape that can be read without running any of the program.
//
//   * how many functions the program has, how many bytes of instructions each carries, how many parameters it takes, whether it is variadic, how many registers it needs;
//   * what its constants are. They are encrypted, but the script carries its own decryptor; run in the sandbox (nothing of the program itself is run: only the statements
//     that set the constants up) it hands them over. The constants are the strings the program prints and concatenates, the names it reads (`print`, `string`) and the numbers
//     it computes with, which is most of what a reader needs to know what the program is about.
//
// This is a profile, not a reconstruction: control flow, locals and expressions are not recovered, and the report says so. Obscura's VM (all three revisions run in this project)
// is the format it reads; the shape it looks for (a table of function records `{ bc = {...}, np = n, va = bool, nuv = n, ms = n }`, a table of constants and a function that
// decrypts one entry on demand) is stated in the code, not assumed.

import { createMachine } from '../sandbox/sandbox.js';
import { compileAst, callValue } from '../sandbox/interp.js';
import { LuaTable } from '../sandbox/value.js';

export const unparen = (e) => (e && e.type === 'Paren' ? unparen(e.expr) : e);

/** The statements of the function the whole script is wrapped in (`return (function(...) ... end)(...)`), or the chunk's own. */
export function bodyOf(chunk) {
  if (chunk.body.length === 1) {
    const s = chunk.body[0];
    const call = s.type === 'Return' && s.values.length === 1 ? unparen(s.values[0]) : s.type === 'CallStmt' ? s.call : null;
    const fn = call && call.type === 'Call' ? unparen(call.fn) : null;
    if (fn && fn.type === 'Func') return fn.body;
  }
  return chunk.body;
}

export const fieldOf = (table, name) => table.fields.find((f) => (f.kind === 'named' && f.key === name) || (f.kind === 'keyed' && unparen(f.key).type === 'String' && unparen(f.key).value === name));

/** Function records: `T[k] = { bc = {...}, np = ..., va = ..., nuv = ..., ms = ... }`. */
function functions(body) {
  const out = [];
  for (const s of body) {
    if (s.type !== 'Assign' || s.targets.length !== 1 || s.values.length !== 1 || s.targets[0].type !== 'Index') continue;
    const v = s.values[0];
    if (v.type !== 'Table') continue;
    const bc = fieldOf(v, 'bc');
    if (!bc || unparen(bc.value).type !== 'Table' || !fieldOf(v, 'np') || !fieldOf(v, 'ms')) continue;
    const bytes = unparen(bc.value);
    // plain build: a list of byte values; hardened build: a record { q = {...}, s, a, d }
    const q = fieldOf(bytes, 'q');
    const count = q && unparen(q.value).type === 'Table' ? unparen(q.value).fields.length : bytes.fields.length;
    const num = (name) => { const f = fieldOf(v, name); const x = f && unparen(f.value); return x && x.type === 'Number' ? x.value : null; };
    const flag = (name) => { const f = fieldOf(v, name); const x = f && unparen(f.value); return x ? x.type === 'True' : null; };
    out.push({ bytes: count, params: num('np'), vararg: flag('va'), upvalues: num('nuv'), registers: num('ms'), hardened: !!q, ownConstants: !!fieldOf(v, 'k') });
  }
  return out;
}

/** The constants table: a top-level local list of numbers and strings (the plain build writes them out; the lazy ones leave them encrypted until used). */
function constantsTable(body) {
  const lists = body.map((s, i) => ({ s, i })).filter(({ s }) => s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && unparen(s.values[0]).type === 'Table'
    && unparen(s.values[0]).fields.length >= 3 && unparen(s.values[0]).fields.every((f) => f.kind === 'item')
    && unparen(s.values[0]).fields.some((f) => unparen(f.value).type === 'String') && unparen(s.values[0]).fields.some((f) => unparen(f.value).type === 'Number'));
  return lists.length ? lists[0] : null;
}

export const contains = (node, test) => { let hit = false; const visit = (n) => { if (!n || typeof n !== 'object' || hit) return; if (Array.isArray(n)) { n.forEach(visit); return; } if (test(n)) { hit = true; return; } for (const k of Object.keys(n)) if (k !== 'line' && n[k] && typeof n[k] === 'object') visit(n[k]); }; visit(node); return hit; };

/**
 * The first top-level statement that holds the interpreter: a loop (`while true do`, or `while pc <= #code do` in the stack machine of the first revision) around a long chain
 * of tests on the opcode. Everything before it is set-up.
 */
function interpreterAt(body, from) {
  const loop = (n) => n.type === 'While' || n.type === 'Repeat' || n.type === 'NumFor' || n.type === 'GenFor';
  for (let i = from; i < body.length; i++) {
    if (contains(body[i], (n) => loop(n) && contains(n.body, (m) => m.type === 'If' && m.clauses.length >= 8))) return i;
  }
  return -1;
}

/** The function that decrypts one entry on demand: it reads `K[i]` for its parameter. Returns its name, or null. */
function lazyDecryptor(body, listName, until) {
  for (let i = 0; i < until; i++) {
    const s = body[i];
    const f = s.type === 'LocalFunction' ? { name: s.id.name, func: s.func }
      : s.type === 'Assign' && s.targets.length === 1 && s.targets[0].type === 'Name' && s.values.length === 1 && unparen(s.values[0]).type === 'Func' ? { name: s.targets[0].name, func: unparen(s.values[0]) } : null;
    if (!f || f.func.params.length !== 1) continue;
    const param = f.func.params[0].name;
    if (contains(f.func.body, (n) => n.type === 'Index' && n.obj.type === 'Name' && n.obj.name === listName && n.key.type === 'Name' && n.key.name === param)) return f.name;
  }
  return null;
}

const machine = (sandbox) => createMachine({ fuel: Math.min(sandbox.fuel ?? 20_000_000, 20_000_000), timeMs: Math.min(sandbox.timeMs ?? 5_000, 5_000), dialect: 'luau' });
const run = (m, chunk) => callValue(m, compileAst(m, chunk, 'vm-constants', m.globals), [], '')[0];
const nameNode = (name) => ({ type: 'Name', name });
const num = (value) => ({ type: 'Number', value, raw: String(value) });

/** The hardened build keeps each function's constants in its own record, opened by a function that takes the record (`pending`, `ck`, `ready` are its fields). */
function readRecordConstants(body, sandbox) {
  const targets = body.filter((s) => s.type === 'Assign' && s.targets.length === 1 && s.targets[0].type === 'Index' && s.targets[0].obj.type === 'Name' && s.values.length === 1 && unparen(s.values[0]).type === 'Table' && fieldOf(unparen(s.values[0]), 'bc'));
  if (!targets.length) return null;
  const tableName = targets[0].targets[0].obj.name;
  // the set-up is everything up to the interpreter's first function: the records, then the integrity check and the loop that salts every record with the hash of its code
  // (the opener needs that salt). The interpreter and the final call are the program itself and never run here.
  const lastRecord = Math.max(...targets.map((s) => body.indexOf(s)));
  const interp = interpreterAt(body, 0);
  let upTo = lastRecord + 1;
  while (upTo < body.length && ['Local', 'If', 'NumFor', 'GenFor', 'Assign', 'CallStmt'].includes(body[upTo].type) && !contains(body[upTo], (n) => n.type === 'While')) upTo++;
  if (interp >= 0 && interp < upTo) upTo = Math.max(interp, lastRecord + 1);
  let opener = null;
  for (let i = 0; i < upTo && !opener; i++) {
    const s = body[i];
    const f = s.type === 'LocalFunction' ? { name: s.id.name, func: s.func } : null;
    if (f && f.func.params.length === 1 && contains(f.func.body, (n) => n.type === 'Index' && n.key.type === 'String' && n.key.value === 'pending') && contains(f.func.body, (n) => n.type === 'Index' && n.key.type === 'String' && n.key.value === 'ready')) opener = f.name;
  }
  if (!opener) return null;
  const idx = { type: 'Index', obj: nameNode(tableName), key: nameNode('__qs_i'), dot: false };
  const open = { type: 'NumFor', id: { type: 'Id', name: '__qs_i' }, start: num(1), stop: { type: 'Unary', op: '#', arg: nameNode(tableName) }, step: null, body: [{ type: 'CallStmt', call: { type: 'Call', fn: nameNode(opener), args: [idx] } }] };
  const chunk = { type: 'Chunk', body: [...body.slice(0, upTo), open, { type: 'Return', values: [nameNode(tableName)] }], endComments: [], features: new Set() };
  const t = run(machine(sandbox), chunk);
  if (!(t instanceof LuaTable)) return null;
  const out = [];
  for (let i = 1; i <= targets.length; i++) {
    const rec = t.get(i);
    const k = rec instanceof LuaTable ? rec.get('k') : null;
    if (k instanceof LuaTable) for (let j = 1; ; j++) { const v = k.get(j); if (v === undefined) break; out.push(typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean' ? v : null); }
  }
  return out;
}

/** Run only the set-up statements in the sandbox (never the interpreter) and read the constants table back; decrypt entries one by one when the build leaves that to use. */
function readConstants(body, found, sandbox) {
  const name = found.s.ids[0].name;
  // the set-up ends at the loop that decrypts the list (when there is one: `for ... do ... K ... end`), else where the interpreter starts
  const loopAt = body.findIndex((s, i) => i > found.i && (s.type === 'NumFor' || s.type === 'GenFor') && contains(s, (n) => n.type === 'Name' && n.name === name));
  const stop = interpreterAt(body, found.i + 1);
  const upTo = loopAt >= 0 && (stop < 0 || loopAt < stop) ? loopAt + 1 : stop < 0 ? body.length : stop;
  const n = found.s.values[0].fields.length;
  const set = body.slice(0, upTo);
  const wrap = (stmts) => ({ type: 'Chunk', body: stmts, endComments: [], features: new Set() });
  let t = run(machine(sandbox), wrap([...set, { type: 'Return', values: [nameNode(name)] }]));
  const read = (table) => { const out = []; for (let i = 1; i <= n; i++) out.push(table.get(i)); return out; };
  if (!(t instanceof LuaTable)) return null;
  let values = read(t);
  const stillCipher = values.filter((v) => typeof v === 'string' && v.length >= 3 && !printable(v)).length;
  const lazy = stillCipher ? lazyDecryptor(body, name, upTo) : null;
  if (lazy) {
    // r = {}; for i = 1, n do r[i] = decrypt(i) end; return r
    const loop = { type: 'NumFor', id: { type: 'Id', name: '__qs_i' }, start: num(1), stop: num(n), step: null, body: [{ type: 'Assign', targets: [{ type: 'Index', obj: nameNode('__qs_r'), key: nameNode('__qs_i'), dot: false }], values: [{ type: 'Call', fn: nameNode(lazy), args: [nameNode('__qs_i')] }] }] };
    t = run(machine(sandbox), wrap([...set, { type: 'Local', ids: [{ type: 'Id', name: '__qs_r' }], values: [{ type: 'Table', fields: [] }] }, loop, { type: 'Return', values: [nameNode('__qs_r')] }]));
    if (t instanceof LuaTable) values = read(t);
  }
  return values;
}

const printable = (s) => typeof s === 'string' && s.length >= 2 && /^[\x20-\x7e\t\n]+$/.test(s);

/**
 * @returns {null | {kind: string, functions: object[], instructionBytes: number, constants: (string|number|boolean|null)[]|null, strings: string[], hardened: boolean, note: string|null}}
 */
export function profileVm(chunk, options = {}) {
  const body = bodyOf(chunk);
  const fns = functions(body);
  const found = constantsTable(body);
  // a script that merely has a list of strings and numbers is not a VM: without function records the interpreter itself has to be there
  if (!fns.length && !(found && interpreterAt(body, found.i + 1) >= 0)) return null;
  const hardened = fns.some((f) => f.hardened || f.ownConstants);       // the constants live in the function records, opened one record at a time
  const profile = {
    kind: 'obscura',
    functions: fns,
    instructionBytes: fns.reduce((a, f) => a + f.bytes, 0),
    constants: null, strings: [], hardened, note: null,
  };
  if (!options.sandbox || !options.sandbox.enabled) { profile.note = 'the constants are encrypted; switch on sandboxed evaluation to read them'; return profile; }
  try {
    // hardened build first: its constants are in the function records
    const values = (hardened || !found) ? readRecordConstants(body, options.sandbox) : readConstants(body, found, options.sandbox);
    if (!values && !found) { profile.note = 'no table of constants was found in the shape this reader knows'; return profile; }
    if (values) {
      profile.constants = values.map((v) => (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean' ? v : null));
      profile.strings = [...new Set(profile.constants.filter(printable))];
      if (hardened && !profile.strings.length) profile.note = 'this is the hardened build: the constants sit in keyed records, and none could be opened';
    }
  } catch (e) {
    profile.note = `the constants could not be read: ${String(e.message || e).split('\n')[0]}`;
  }
  return profile;
}
