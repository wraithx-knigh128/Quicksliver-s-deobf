// Lift a MoonVeil-style VM program back to Lua, statically.
//
// The protector turns a script into data for an interpreter that ships with it. Everything the lifter needs is in the file: the interpreter's
// own code says how its data is laid out and what each of its handlers does; the data says what the program is. The pieces:
//
//   profile     what this script calls things: field ids, the opcode map, which cell of the interpreter is which builtin, the helper methods
//   blob        the program's data, decoded (Z85, then the compression the runtime uses), parsed with the profile's layouts
//   stub        the part of the data that is encrypted, decrypted by searching for the one number its key depends on
//   ops         the handlers: one op at a time, then one instruction at a time; the ones that rewrite the program are applied first
//   lift        every instruction, partially evaluated against the interpreter and joined into one graph per function
//   assemble    structured, named, with closures written in place
//
// Nothing here executes the script. If any step does not fit what the script contains, a VmUnsupported error says which, and the caller falls
// back to the general passes.

import { clone, walk } from '../../core/walk.js';
import { z85Decode, findRoot, nameMap, nameMapAfter } from '../moonveil.js';
import { unflattenMoonVeil } from '../moonveil-cff.js';
import { lz } from '../moonveil-crypto.js';
import { deriveProfile, VmUnsupported } from './profile.js';
import { readBlob } from './blob.js';
import { searchStubKey, combinations } from './stub.js';
import { createOps } from './ops.js';
import { createLifter } from './lift.js';
import { createNatives } from './natives.js';
import { createAssembler } from './assemble.js';
import { validateLift } from './validate.js';

export { VmUnsupported };

const now = () => (typeof performance !== 'undefined' ? performance.now() : Date.now());
const asBytes = (s) => { const b = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) b[i] = s.charCodeAt(i) & 255; return b; };

/** The data string of the program: the longest string literal that decodes (Z85, then the runtime's compression) to something the profile parses completely. */
function findBlob(chunk, profile) {
  const strings = [];
  walk(chunk, (n) => { if (n.type === 'String' && n.value.length > 2048) strings.push(n.value); });
  strings.sort((a, b) => b.length - a.length);
  for (const text of strings) {
    let bytes;
    try { bytes = asBytes(lz(z85Decode(text))); } catch { continue; }
    try {
      const parsed = readBlob(bytes, profile);
      if (parsed.end === parsed.length) return { bytes, root: parsed.root };
    } catch { /* not this one */ }
  }
  return null;
}

/**
 * The statement `return (<functions>):build(...)` is the protected program; whatever else the script does around it (a banner, a loader that
 * runs first) stays where it was. The rebuilt program takes the place of that one statement, in a block of its own when there is anything beside it.
 */
function replaceRoot(chunk, call, body) {
  let done = false;
  const visit = (node) => {
    if (done || !node || typeof node !== 'object') return;
    if (Array.isArray(node)) {
      const i = node.findIndex((st) => st && st.type === 'Return' && st.values && st.values.length === 1 && st.values[0] === call);
      if (i >= 0) { node.splice(i, 1, ...(node.length === 1 ? body : [{ type: 'Do', body }])); done = true; return; }
      node.forEach(visit);
      return;
    }
    for (const k of Object.keys(node)) if (k !== 'line' && node[k] && typeof node[k] === 'object') visit(node[k]);
  };
  visit(chunk);
  if (!done) throw new VmUnsupported('the statement that holds the program could not be found again');
}

const protosOf = (root) => { const out = []; (function w(p) { if (p.stub) return; out.push(p); p.children.forEach(w); })(root); return out; };
const stubsOf = (root) => { const out = []; (function w(p) { if (p.stub) { out.push(p); return; } p.children.forEach(w); })(root); return out; };

/**
 * @param {object} chunk  the script after its strings and cells were read (the AST is replaced in place on success)
 * @param {{onProgress?: (e: {phase: string, done?: number, total?: number}) => void, shouldStop?: () => boolean, stubLimit?: number}} [options]
 */
export function liftMoonVeilVm(chunk, options = {}) {
  const progress = options.onProgress || (() => {});
  const t = { start: now() };
  const phase = (name) => { t[name] = now(); progress({ phase: name }); };

  const preRoot = findRoot(chunk);
  const preMap = preRoot && nameMap(preRoot);
  if (!preMap) throw new VmUnsupported('this is not a table of functions in the shape MoonVeil produces');

  phase('profile');
  const after = clone(chunk);
  unflattenMoonVeil(after, { gotoFallback: true });
  const postRoot = findRoot(after);
  const postMap = postRoot && nameMapAfter(preRoot, postRoot, preMap);
  if (!postMap) throw new VmUnsupported('the functions could not be matched up after their control flow was rebuilt');
  const profile = deriveProfile({ map: preMap }, { map: postMap });

  phase('data');
  const blob = findBlob(chunk, profile);
  if (!blob) throw new VmUnsupported('no data string in the script decodes to a program of this layout');

  phase('handlers');
  const ops = createOps(profile);
  const natives = createNatives(new Map([...postMap].filter(([, v]) => v && v.type === 'Func')));
  const lifters = new Map();
  /** a lifter that knows the register count of the blob it is going to read (the first one is for the data that holds the stub) */
  const assemblerFor = (root, { onProto, onStep } = {}) => {
    const registers = protosOf(root).reduce((m, p) => Math.max(m, p.maxreg || 0), 0) + 66;
    const key = `${registers}:${onStep ? 1 : 0}`;
    if (!lifters.has(key)) lifters.set(key, createLifter(profile, ops, { registers, onStep }));
    return createAssembler(profile, lifters.get(key), natives, { onProto });
  };

  // the program itself is behind the stub when there is one
  let program = blob.root;
  let stubInfo = null;
  const stubs = stubsOf(blob.root);
  if (stubs.length) {
    phase('stub');
    // the 32-byte values the key is built from are constants of the function that sets up the runtime; they are encrypted in the data, so that
    // function is lifted (with its constants decrypted) and the 32-byte strings read from the result
    const outer = assemblerFor(blob.root);
    const constants = new Set();
    for (const p of protosOf(blob.root)) {
      if (p.consts.filter((c) => typeof c === 'string' && c.length === 32).length < 2) continue;
      ops.staticOps(p);
      walk(outer.liftBody(p).body, (n) => { if (n.type === 'String' && n.value.length === 32) constants.add(n.value); });
    }
    const bases = combinations([...constants]);
    const found = bases.length ? searchStubKey(stubs[0], bases, {
      constants: profile.crypto.chachaConstants,
      profile,
      limit: options.stubLimit,
      shouldStop: options.shouldStop,
      onProgress: (done, total) => progress({ phase: 'stub', done, total }),
    }) : null;
    if (!found) throw new VmUnsupported('the encrypted part of the program could not be opened: its key was not found among the ways the file can produce it');
    program = found.root;
    stubInfo = { offset: found.offset, combination: found.mask, bytes: found.bytes.length };
  }

  phase('lift');
  const protos = protosOf(program);
  const instructions = protos.reduce((n, p) => n + p.code.length, 0);
  let applied = 0;
  protos.forEach((p, i) => {
    applied += ops.staticOps(p).applied;
    progress({ phase: 'handlers', done: i + 1, total: protos.length });
  });
  // progress is counted in instructions: one function holds most of them, so counting functions would stand still for most of the time
  let instructionsDone = 0;
  const assembler = assemblerFor(program, {
    onProto: (p) => { instructionsDone += p.code.length; progress({ phase: 'lift', done: instructionsDone, total: instructions }); },
    onStep: (n) => progress({ phase: 'lift', done: Math.min(instructionsDone + n, instructions), total: instructions }),
  });
  const stats = { closures: 0, goto: 0, protos: 0 };
  const fn = assembler.assemble(program, 0, stats);

  replaceRoot(chunk, preRoot.call, fn.body);
  const validation = validateLift(chunk, protos, stats, profile.constFields);
  t.end = now();
  return {
    changed: stats.protos,
    protos: stats.protos,
    closures: stats.closures,
    natives: stats.natives || 0,
    notStructured: stats.goto,
    handlersApplied: applied,
    stub: stubInfo,
    validation,
    instructions,
    ms: Math.round(t.end - t.start),
  };
}
