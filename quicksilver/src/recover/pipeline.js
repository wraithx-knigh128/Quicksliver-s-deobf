// The recovery pipeline.
//
//   parse -> detect -> [ structural passes -> family passes -> fold -> simplify -> evaluate ]* -> clean-up -> rename
//
// Every pass runs against a snapshot of the AST: if it throws, the snapshot is restored and the step
// is reported as failed, so one broken pass can never corrupt the result. Passes that need to execute
// code (decoder evaluation) run only when the caller explicitly enabled sandboxing.

import { parse, LuaSyntaxError } from '../core/parser.js';
import { print } from '../core/printer.js';
import { clone, structuralKey, walk } from '../core/walk.js';
import { detect } from '../detect/detect.js';
import { foldPass } from '../passes/fold.js';
import { simplifyMBA } from '../passes/mba.js';
import { simplifyPass, snapshotUnused } from '../passes/simplify.js';
import { evaluatePass } from '../passes/evaluate.js';
import { renamePass } from '../passes/rename.js';
import { unwrapWrapper, removeUnusedVararg, tidyIfs, whileToIf } from '../passes/structure.js';
import { unwrapLayers } from '../passes/layers.js';
import { dataflowPass } from '../passes/dataflow.js';
import { regionPass } from '../passes/regions.js';
import { booleanResults, orientComparisons, shortCircuits, tableConstructors, methodCalls, bareNils, functionForms, multiResults, numericLoops, loopForms, unsetLocals } from '../passes/idioms.js';
import { removeAntiTamper, removeGuardFlag, removeGuardPrefix, removeSanityCheck, undoProxifyLocals, removeOrphanDecoders, removeUnusedJoiner } from './prometheus.js';
import { propagateStable } from '../passes/stable.js';
import { buildReport, annotate, stripReport } from './annotate.js';
import { profileVm } from './vmprofile.js';
import { liftObscuraVm, ObscuraVmError } from './obscura-vm.js';
import { liftPrometheusBvm, looksLikePrometheusBvm, BvmError } from './prometheus-bvm.js';
import { liftVault, looksLikeVault, VaultVmError } from './vault-vm.js';
import { liftAzureVM, looksLikeAzureVM, AzureVmError } from './azurevm.js';
import { checkAgainstChunk } from './bytecode-check.js';
import { liftIronbrikkedVm, IronbrikkedVmError, looksLikeIronbrikked } from './ironbrikked-vm.js';
import { liftFusgatoVm, FusgatoVmError, looksLikeFusgato } from './fusgato-vm.js';
import { repairRenamedKeyword } from './keyword-repair.js';
import { liftZarthaVm, ZarthaVmError, looksLikeZartha, removeZarthaGuards, repairZarthaSource } from './zartha-vm.js';
import { snapshotNames, joinMoonVeil, unboxCells, JoinError } from './moonveil-join.js';
import { rebuildProgram21, Lift21Error } from './moonveil-vm/lift21.js';
import { liftRealObfuscatorVm, looksLikeRealObfuscatorVm, RealObfuscatorVmError } from './realobfuscator-vm.js';
import { looksLikeLuaq, decodeLuaq, LuaqError } from './luaq.js';
import { looksLikeVolt, decodeVoltConstants, voltHeader, VoltError } from './volt.js';
import { readProgram as readLuaObfProgram, looksLikeLuaObfVm, LuaObfVmError } from './luaobf-vm.js';
import { removeHerculesAntiTamper, removeHerculesAntiTamperFunction, removeHerculesCoinGuard, restoreMethodSelf } from './hercules.js';
import { uninlinePass } from '../passes/uninline.js';
import { splitWebs } from '../passes/webs.js';
import { unwrapCharList } from '../passes/charlist.js';
import { raiseLoops } from '../passes/loopraise.js';
import { analyze as analyzeScopes } from '../core/scope.js';
import { readHerculesVm, findVmCall, replaceVmCall, HerculesVmError } from './hercules-vm.js';
import { removeColisseumGuard } from './colisseum.js';
import { decodePageStrings } from './simple_html.js';
import { unflattenMoonVeil } from './moonveil-cff.js';
import { removeObscuraGuards } from './obscura.js';
import { unwrapXFuscator } from './xfuscator.js';
import { foldMetaArithmetic } from '../passes/metaarith.js';
import { seedDecoderCalls, inlineStringTable, inlineConstantTable } from '../passes/strtable.js';
import { liftMoonVeilVm, VmUnsupported } from './moonveil-vm/index.js';
import { readContainer21, findContainerCall, Container21Error } from './moonveil-vm/container21.js';
import { deriveSchema21, readProgram21, Schema21Error } from './moonveil-vm/schema21.js';
import { decodeMoonVeilConstants, simplifyCells, moonveilShape } from './moonveil.js';
import { assessConfidence } from './confidence.js';
import { AdaptiveEngine } from '../adaptive/engine.js';
import { recoverIronBrew, IronBrewError } from './ironbrew.js';
import { unflattenVmify, envToGlobals, VmifyError } from './vmify.js';
import { parseChunk } from '../sandbox/bytecode.js';
import { runSource } from '../sandbox/sandbox.js';
import { decompile } from '../decompile/decompile.js';

export const DEFAULT_OPTIONS = Object.freeze({
  sandbox: { enabled: false, fuel: 60_000_000, timeMs: 10_000, dialect: 'luau' },
  rename: 'smart',            // 'smart' | 'all' | 'off'
  foldCalls: 'obfuscation',   // 'obfuscation' | 'all'
  maxRounds: 8,
  adaptive: true,             // after the family steps and the generic rounds: read the structure of what is left and recover what can be recovered (src/adaptive/)
  adaptiveBudgetMs: 12000,
  // put a short report in front of the output when the recovery is not complete (what was done, what is left); off keeps the code alone
  annotate: true,
  roleHints: null,            // (ast) => Map<Id node, {name}>: names inferred from relations (src/nexus/roles.js); consulted by the renamer before the initialiser
  moonveilVm: true,           // read a MoonVeil VM program back out of its data (static; falls back to the general passes when the script does not fit)
  reuseInstructions: true,    // lift an instruction once per kind and reuse it (false lifts every one: slower, same result)
  // Prompt XXX: after a VM lift verified against its decoded bytecode, every later step is checked against it again and undone when it
  // changes what the program does. Off only to test a pass on its own (tests/xxxi-evaluate.test.mjs); the site never turns it off.
  vmGuard: true,
  onProgress: null,           // called with { phase, done?, total? } while long steps run
  stringStyle: 'normalize',
  format: { indent: '  ', width: 100 },
});

const now = () => (typeof performance !== 'undefined' ? performance.now() : Date.now());

export class Run {
  constructor(ast, options) {
    this.ast = ast;
    this.options = options;
    this.steps = new Map();
    this.warnings = [];
    this.vmifyLayers = 0;
    // Prompt XXX: once a lifted program has been verified against the VM's own decoded chunk, every later step that changes the program
    // must keep that behaviour; `guard(ast)` returns false when it no longer does, and the step is undone
    this.guard = null;
  }

  /** Run one pass under a snapshot. `fn(ast)` returns { changed, ...detail }. */
  step(id, label, fn, { quiet = false } = {}) {
    const snapshot = clone(this.ast);
    const t0 = now();
    let r;
    try {
      r = fn(this.ast) || { changed: 0 };
    } catch (e) {
      this.ast = snapshot;
      this.record(id, label, { status: 'failed', changed: 0, error: String(e && e.message ? e.message : e), ms: now() - t0 });
      return 0;
    }
    const changed = r.changed || 0;
    if (this.guard && changed && !r.skipped) {
      let why = null;
      try { why = this.guard(this.ast); } catch (e) { why = `the check could not run (${e && e.message ? e.message : e})`; }
      if (why) {
        this.ast = snapshot;
        this.record(id, label, { status: 'failed', changed: 0, error: `undone: ${why}`, ms: now() - t0 });
        return 0;
      }
    }
    if (r.skipped) this.record(id, label, { status: 'skipped', changed: 0, detail: r.skipped, ms: now() - t0 });
    else if (changed || !quiet) this.record(id, label, { status: changed ? 'applied' : 'no-op', changed, detail: r, ms: now() - t0 });
    return changed;
  }

  record(id, label, data) {
    const prev = this.steps.get(id);
    if (!prev) { this.steps.set(id, { id, label, rounds: 1, ...data, ...(data.error && data.error.startsWith('undone:') ? { undone: 1, undoneWhy: data.error } : {}) }); return; }
    prev.rounds++;
    prev.changed += data.changed || 0;
    prev.ms += data.ms || 0;
    if (data.status === 'applied') prev.status = 'applied';
    if (data.status === 'failed') { prev.status = 'failed'; prev.error = data.error; }
    // a round undone by the guard stays visible when a later round applies
    if (data.error && data.error.startsWith('undone:')) { prev.undone = (prev.undone || 0) + 1; prev.undoneWhy = data.error; }
    if (data.detail && data.status !== 'skipped') prev.detail = data.detail;
    if (data.status === 'skipped' && prev.status !== 'applied') { prev.status = 'skipped'; prev.detail = data.detail; }
  }
}

/**
 * Prometheus Vmify: the script is a dispatcher over block ids. Rebuild the functions it flattened. Strong applies the
 * pass twice, so go on while another layer turns up.
 */
function rebuildVmify(ast, run) {
  let layers = 0;
  let functions = 0;
  let counted = 0;
  for (; layers < 4; layers++) {
    let r;
    try { r = unflattenVmify(ast, { layer: ++run.vmifyLayers }); } catch (e) {
      if (e instanceof VmifyError) {
        if (layers) break;
        return { skipped: e.message };
      }
      throw e;
    }
    if (!r.changed) break;
    functions += r.functions;
    if (r.counted) counted += r.counted;
  }
  // Cff applied to a VM interpreter alone (Prometheus Strong): the dispatcher is the body of a function inside the script, not the script.
  // Each such function body is read as a script of its own (`...` is the function's, which is what the dispatcher was handed)
  if (!layers) {
    const nested = [];
    walk(ast, (n) => {
      if (n.type !== 'Func' || n.body.length !== 1 || n.body[0].type !== 'Return' || n.body[0].values.length !== 1) return undefined;
      const c = n.body[0].values[0];
      const fn = c && c.type === 'Call' ? (c.fn.type === 'Paren' ? c.fn.expr : c.fn) : null;
      if (fn && fn.type === 'Func' && fn.params.length >= 4 && fn.body.length >= 2) { nested.push(n); return false; }
      return undefined;
    });
    for (const f of nested) {
      const sub = { type: 'Chunk', body: f.body, features: ast.features, endComments: [] };
      let r;
      try { r = unflattenVmify(sub, { layer: ++run.vmifyLayers }); } catch (e) { if (e instanceof VmifyError) continue; throw e; }
      if (!r.changed) continue;
      f.body = sub.body;
      layers++;
      functions += r.functions;
      if (r.counted) counted += r.counted;
    }
  }
  // the layout Prometheus writes since 2026-11 (its old Vmify, renamed Cff: counted value lists, an environment threaded through closures) is read by
  // rewriting it into the earlier one
  if (layers && counted) return { changed: functions, layers, functions, layout: `the Cff layout Prometheus writes since November 2026 (value lists that carry their count, an environment handed to every closure), read by translating it into the earlier Vmify layout (${counted} place(s))` };
  return layers ? { changed: functions, layers, functions } : { skipped: 'not a Vmify script' };
}

/**
 * Obscura's virtual machine: the handlers the script carries say what each opcode of this build does, the program's functions are decoded with the script's own key, and the
 * result goes through the decompiler. Needs the constants, which the profile read in the sandbox. The AST is replaced in place.
 */
function rebuildObscuraVm(ast, vm) {
  if (!vm || vm.kind !== 'obscura') return { skipped: 'not an Obscura virtual machine' };
  if (!vm.constants) return { skipped: 'the constants of the virtual machine need the sandbox' };
  let r;
  try { r = liftObscuraVm(ast, { constants: vm.constants }); } catch (e) {
    if (e instanceof ObscuraVmError) return { skipped: e.message };
    throw e;
  }
  const out = decompile(parseChunk(r.bytes));
  if (out.failures.length) return { skipped: `the decompiler could not structure ${out.failures.length} function(s): ${out.failures[0]}` };
  ast.body = out.ast.body;
  ast.features = out.ast.features || ast.features;
  vm.lifted = true;
  return { changed: r.stats.instructions, ...r.stats };
}

/** Run the original script and a rebuilt one in the sandbox (Luau); null when the sandbox is off, {checked:false} when a run hit a limit. */
function sameRun(source, rebuilt, options) {
  if (!options.sandbox || !options.sandbox.enabled) return null;
  const wrap = (src) => `local __qs_r = {(function(...)\n${src}\nend)()}\nprint("__qs_returned", #__qs_r)`;
  const runOne = (src) => { try { return runSource(wrap(src), { dialect: 'luau', fuel: 20_000_000, timeMs: 4000, maxDepth: 300, chunkName: 'sample' }); } catch (e) { return { ok: false, limit: true, error: e }; } };
  const a = runOne(source);
  const b = runOne(rebuilt);
  if (a.limit || b.limit || a.kind === 'limit' || b.kind === 'limit') return { checked: false };
  return { checked: true, same: a.ok === b.ok && a.output === b.output, a, b };
}

/**
 * RealObfuscator's function VM (src/recover/realobfuscator-vm.js): every function the generator compiled is written back as Lua. With the sandbox on,
 * the rebuilt script must run like the original or the VM stays.
 */
function rebuildRealObfuscatorVm(ast, { source, options, holder }) {
  const work = clone(ast);
  let stats;
  try { stats = liftRealObfuscatorVm(work); } catch (e) {
    if (e instanceof RealObfuscatorVmError) return { skipped: e.message };
    throw e;
  }
  const check = sameRun(source, print(work), options);
  if (check && check.checked && !check.same) return { skipped: `the rebuilt program does not run like the original script (original: ${check.a.ok ? 'ok' : 'error'}; rebuilt: ${check.b.ok ? 'ok' : 'error'} ${JSON.stringify(String((check.b.error && (check.b.error.message || check.b.error)) || check.b.output || '').slice(0, 80))})` };
  ast.body = work.body;
  const result = { ...stats, selfCheck: check ? (check.checked ? 'same' : 'not run') : 'sandbox off' };
  if (holder) holder.stats = result;
  return result;
}

/**
 * MoonVeil 2.1.0: the VM's program rebuilt from its handlers (src/recover/moonveil-vm/lift21.js) and joined with the factories MoonVeil left as Lua.
 * The rebuilt script replaces the interpreter only when every function was read and structured; with the sandbox on, it must also run like the
 * original script (same success, same output, same results), or the interpreter stays.
 */
function rebuildMoonVeil21(ast, { snapshot, prog, schema, source, options, holder }) {
  if (!snapshot) return { skipped: 'the names of the factory table were not read before its control flow was rebuilt' };
  const work = clone(ast);
  let stats;
  try { stats = rebuildProgram21(work, { snapshot, prog, schema }); } catch (e) {
    if (e instanceof Lift21Error || e instanceof JoinError) return { skipped: e.message };
    throw e;
  }
  let check = null;
  if (options.sandbox && options.sandbox.enabled) {
    const wrap = (src) => `local __qs_r = {(function(...)\n${src}\nend)()}\nprint("__qs_returned", #__qs_r)`;
    const runOne = (src) => { try { return runSource(wrap(src), { dialect: 'luau', fuel: 20_000_000, timeMs: 4000, maxDepth: 300, chunkName: 'sample' }); } catch (e) { return { ok: false, limit: true, error: e }; } };
    const a = runOne(source);
    const b = runOne(print(work));
    if (a.limit || b.limit || a.kind === 'limit' || b.kind === 'limit') check = { checked: false };
    else {
      check = { checked: true, same: a.ok === b.ok && a.output === b.output };
      if (!check.same) return { skipped: `the rebuilt program does not run like the original script (original: ${a.ok ? 'ok' : 'error'}, ${JSON.stringify(String(a.output || '').slice(0, 60))}; rebuilt: ${b.ok ? 'ok' : 'error'}, ${JSON.stringify(String(b.output || '').slice(0, 60))})` };
    }
  }
  ast.body = work.body;
  ast.features = work.features || ast.features;
  const result = { changed: stats.instructions, ...stats, selfCheck: check ? (check.checked ? 'same' : 'not run') : 'sandbox off' };
  if (holder) holder.stats = result;
  return result;
}

/**
 * Zartha's virtual machine: its functions are chains of per-instruction code written from templates. Each is read as the Lua 5.1 instruction it stands for, the program's constants are
 * decoded with the script's own decryptor, and the result goes through the decompiler. Nothing of the program runs.
 */
function rebuildZarthaVm(ast, state) {
  let r;
  try { r = liftZarthaVm(ast); } catch (e) {
    if (e instanceof ZarthaVmError) return { skipped: e.message };
    throw e;
  }
  const out = decompile(parseChunk(r.bytes));
  if (out.failures.length) return { skipped: `the decompiler could not structure ${out.failures.length} function(s): ${out.failures[0]}` };
  ast.body = out.ast.body;
  ast.features = out.ast.features || ast.features;
  state.zarthaLifted = true;
  state.stats = r.stats;
  return { changed: r.stats.instructions, ...r.stats };
}

/** AzureVM: payload and keys read from the script, opcodes read off its handler templates, the program a standard Lua 5.1 chunk for the decompiler. Nothing runs. */
function rebuildAzureVm(ast, state) {
  let r;
  try { r = liftAzureVM(ast); } catch (e) {
    if (e instanceof AzureVmError) return { skipped: e.message };
    throw e;
  }
  const out = decompile(parseChunk(r.bytes));
  if (out.failures.length) return { skipped: `the decompiler could not structure ${out.failures.length} function(s): ${out.failures[0]}` };
  // the decoded chunk is the VM's own program: the reconstruction has to behave like it (run in the sandbox, when that is allowed)
  let check = null;
  if (state.sandbox) {
    check = checkAgainstChunk(r.bytes, print(out.ast));
    if (check.checked && !check.same) return { skipped: `the decompiled program does not behave like the decoded bytecode (${check.reason}); it is not reported as recovered` };
  }
  ast.body = out.ast.body;
  ast.features = out.ast.features || ast.features;
  if (check && check.checked && check.same) state.verifiedChunk = r.bytes;
  state.stats = { ...r.stats, selfCheck: check ? (check.checked ? 'same as the decoded bytecode in the sandbox' : `not checked: ${check.reason}`) : 'not checked (sandbox off)' };
  return { changed: r.stats.instructions, ...state.stats };
}

/** Vault-Obf's register VM: the payload decoded with the parameters it carries, opcodes read off the handlers, functions lifted to Lua. Nothing runs. */
function rebuildVaultVm(ast, state) {
  let r;
  try { r = liftVault(ast); } catch (e) {
    if (e instanceof VaultVmError) return { skipped: e.message };
    throw e;
  }
  state.stats = r.stats;
  return { changed: r.changed, ...r.stats };
}

/** LuaXen's IronBrikked virtual machine: compressed bytes, a dispatch over the opcode whose handlers are read from the script, the decompiler. Nothing runs. */
function rebuildIronbrikkedVm(ast, state) {
  let r;
  try { r = liftIronbrikkedVm(ast); } catch (e) {
    if (e instanceof IronbrikkedVmError) return { skipped: e.message };
    throw e;
  }
  const out = decompile(parseChunk(r.bytes));
  if (out.failures.length) return { skipped: `the decompiler could not structure ${out.failures.length} function(s): ${out.failures[0]}` };
  ast.body = out.ast.body;
  ast.features = out.ast.features || ast.features;
  state.stats = r.stats;
  return { changed: r.stats.instructions, ...r.stats };
}

/** FusGato's virtual machine: each instruction is told by its handler's text and its operands by the decoded bits; the result goes through the decompiler. Nothing runs. */
function rebuildFusgatoVm(ast, state) {
  let r;
  try { r = liftFusgatoVm(ast); } catch (e) {
    if (e instanceof FusgatoVmError) return { skipped: e.message };
    throw e;
  }
  const out = decompile(parseChunk(r.bytes));
  if (out.failures.length) return { skipped: `the decompiler could not structure ${out.failures.length} function(s): ${out.failures[0]}` };
  ast.body = out.ast.body;
  ast.features = out.ast.features || ast.features;
  state.stats = r.stats;
  return { changed: r.stats.instructions, ...r.stats };
}

/**
 * IronBrew 2: read the program back out of the VM's own data and decompile it. The AST is replaced in place so that
 * the ordinary passes (folding, clean-up, renaming) go on to work on the recovered program.
 */
function rebuildIronBrew(ast) {
  let r;
  try { r = recoverIronBrew(ast); } catch (e) {
    if (e instanceof IronBrewError) return { skipped: e.message };
    throw e;
  }
  const out = decompile(parseChunk(r.bytes));
  if (out.failures.length) throw new Error(`the decompiler could not structure ${out.failures.length} function(s): ${out.failures[0]}`);
  ast.body = out.ast.body;
  ast.features = out.ast.features || ast.features;
  return { changed: r.stats.instructions, ...r.stats };
}

/**
 * Hercules' virtual-machine module: the program is Lua 5.1 bytecode in a text the script carries. It is decoded, decompiled and put where the
 * interpreter was started; the interpreter's own declarations are dropped. Nothing is executed.
 */
function rebuildHerculesVm(ast) {
  const call = findVmCall(ast);
  if (!call) return { changed: 0 };
  let r;
  try { r = readHerculesVm(ast); } catch (e) {
    if (e instanceof HerculesVmError) return { skipped: `the interpreter call was found, but its data is not in the layout this reader knows: ${e.message}` };
    throw e;
  }
  const out = decompile({ version: 0x51, main: r.main });
  if (out.failures.length) throw new Error(`the decompiler could not structure ${out.failures.length} function(s): ${out.failures[0]}`);
  const removed = call.run ? replaceVmCall(ast, call.run, out.ast.body, call.holder) : -1;
  if (removed < 0) return { skipped: 'the interpreter call is part of a larger expression; the program was read but not put in its place' };
  const detail = { changed: r.stats.instructions, ...r.stats, interpreterStatementsRemoved: removed };
  // the tool wrote no bytes for a nil constant; where more than one slot could have been the nil one the choice is a ranking, and is said to be
  if ((r.stats.nilReadings || []).some((n) => n > 1)) detail.inferred = `a nil constant the tool left out of its data was put back in ${r.stats.nilReadings.filter((n) => n > 1).length} function(s) by choosing the likeliest of ${Math.max(...r.stats.nilReadings)} possible slots`;
  // `#` stopped at a nil in the middle of a pool: what came after it is not in the file. The program reads those constants as nil, as the shipped script does.
  if ((r.stats.lostConstants || []).length) {
    const l = r.stats.lostConstants;
    detail.lost = `${l.length} constant(s) the tool never wrote (its serialiser measures the pool with #, which stops at a nil constant) are read as nil, as the shipped script reads them; ${l.map((x) => `slot ${x.slot} (${x.uses.map((u) => `${u.kind === 'number' ? 'an arithmetic operand' : u.kind === 'key' ? 'a table key' : 'a value'} at instruction ${u.pc}`).join(', ')})`).join('; ')}`;
  }
  return detail;
}

/** Parse, or return a structured error. */
export function tryParse(source) {
  try {
    return { ok: true, ast: parse(source) };
  } catch (e) {
    if (e instanceof LuaSyntaxError) return { ok: false, error: { message: e.message, line: e.line, col: e.col } };
    throw e;
  }
}

/**
 * @param {string} source binary string
 * @param {object} [userOptions] see DEFAULT_OPTIONS
 */
export function recover(source, userOptions = {}) {
  const options = { ...DEFAULT_OPTIONS, ...userOptions, sandbox: { ...DEFAULT_OPTIONS.sandbox, ...(userOptions.sandbox || {}) }, format: { ...DEFAULT_OPTIONS.format, ...(userOptions.format || {}) } };
  const t0 = now();
  source = stripReport(source);      // a result of ours that is recovered again: its report is replaced, not repeated
  let parsed = tryParse(source);
  let zarthaRepair = 0;
  if (!parsed.ok) {
    const mended = repairZarthaSource(source);
    if (mended.count) {
      const again = tryParse(mended.source);
      if (again.ok) { parsed = again; source = mended.source; zarthaRepair = mended.count; }
    }
  }
  let keywordRepair = null;
  if (!parsed.ok) {
    const mended = repairRenamedKeyword(source);
    if (mended.count) { parsed = tryParse(mended.source); source = mended.source; keywordRepair = mended; }
  }
  if (!parsed.ok) {
    return { ok: false, stage: 'parse', error: parsed.error, output: null, steps: [], detection: detect(source), warnings: [] };
  }
  let detection = detect(source, parsed.ast);
  // a script that keeps its program as bytecode for a generated interpreter: what the bytecode holds is read before any pass touches the tree (nothing of the program runs)
  let vm = null;
  try { vm = profileVm(parsed.ast, { sandbox: options.sandbox }); } catch { vm = null; }
  const run = new Run(parsed.ast, options);
  if (keywordRepair) run.record('keyword.repair', 'Restore a keyword the generator renamed', { status: 'applied', changed: keywordRepair.count, detail: { keyword: keywordRepair.keyword, name: keywordRepair.name, places: keywordRepair.count, note: `the generator's renamer wrote every \`${keywordRepair.keyword}\` as ${keywordRepair.name}, so the script is not valid Lua as shipped; the name is never declared and stands exactly where \`${keywordRepair.keyword}\` is missing` }, ms: 0 });
  if (zarthaRepair) run.record('zartha.repair', 'Mend the line breaks the Zartha generator wrote as text', { status: 'applied', changed: zarthaRepair, detail: { places: zarthaRepair, note: 'the LOADBOOL template writes `\\n\\t` inside a string where it means a line break, so the script is not valid Lua as shipped' }, ms: 0 });
  // after a layer is unwrapped: add what the payload shows to what the wrapper showed
  const refreshDetection = () => {
    const inner = detect(print(run.ast), run.ast);
    const merged = new Map(detection.families.map((f) => [f.id, f]));
    for (const f of inner.families) if (!merged.has(f.id) || merged.get(f.id).confidence < f.confidence) merged.set(f.id, f);
    const traits = new Map([...detection.traits, ...inner.traits].map((t) => [t.id, t]));
    detection = { ...inner, families: [...merged.values()].sort((a, b) => b.confidence - a.confidence), traits: [...traits.values()], layers: (detection.layers || 0) + 1, wrapper: detection.wrapper || { families: detection.families.map((f) => f.id), traits: detection.traits.map((t) => t.id) } };
  };
  // LuaQ: stage 1 is data (base 93, an LQZ1 container, raw DEFLATE) and is decoded here; what it decodes to is the VM runtime, not the program,
  // which LuaQ delivers at run time from its server or from a seal object in the game (src/recover/luaq.js)
  if (looksLikeLuaq(source)) {
    run.step('luaq.layers', 'Decode LuaQ\u2019s outer layer (base 93, LQZ1, DEFLATE) to the VM runtime it loads', (a) => {
      let d;
      try { d = decodeLuaq(source); } catch (e) { if (e instanceof LuaqError) return { skipped: e.message }; throw e; }
      const inner = tryParse(d.stage2);
      if (!inner.ok) return { skipped: `the decoded stage does not parse: ${inner.error.message}` };
      a.body = inner.ast.body;
      a.features = inner.ast.features || a.features;
      const { stage2, ...info } = d;
      void stage2;
      return { changed: 1, ...info, programInFile: false };
    });
    parsed = { ok: true, ast: run.ast };
  }
  // Voltfuscator: the constant pool is decoded by the file's own decoder in the sandbox, every value accepted only through the file's checksum
  // (src/recover/volt.js); the generic passes then work on the runtime with its strings in place
  if (looksLikeVolt(source)) {
    run.step('volt.constants', 'Decode Voltfuscator\u2019s constant pool with the file\u2019s own decoder (sandbox; checksum-verified)', (a) => {
      try {
        const r = decodeVoltConstants(a, { sandbox: options.sandbox });
        return r.skipped ? r : { ...r, header: voltHeader(source) };
      } catch (e) { if (e instanceof VoltError) return { skipped: e.message }; throw e; }
    });
  }
  if (options.sandbox && options.sandbox.enabled && detection.families.some((f) => f.id === 'luaobfuscator' && f.evidence.some((e) => e.rule === 'vm-prelude'))) {
    // Prompt XXV: LuaObfuscator.com's VM program, read with the script's own deserialiser in the sandbox. Its constants are reported; the VM
    // is not rebuilt (see src/recover/luaobf-vm.js for why), so this changes nothing in the code and the verdict stays "not deobfuscated".
    run.step('luaobf.program', 'Read LuaObfuscator\u2019s VM program with its own deserialiser (sandbox): functions, instructions, constants', () => {
      if (!looksLikeLuaObfVm(parsed.ast)) return { skipped: 'the VM entry `return F("...", getfenv(), ...)` was not found' };
      try { return { changed: 0, ...readLuaObfProgram(source) }; } catch (e) { if (e instanceof LuaObfVmError) return { skipped: e.message }; throw e; }
    });
  }
  let unusedAtStart = snapshotUnused(parsed.ast);

  let decompiled = false;
  let vmified = false;
  let vmTried = false;
  let vmLifted = false;
  let bvmTried = 0;
  let ikTried = false;
  const evalMemory = new Set();          // decoders found by an earlier round of evaluation
  let mvJoined = false;
  if (detection.families.some((f) => f.id === 'ironbrew2' && f.confidence >= 0.5)) {
    // a rebuilt program has no author-written dead code to preserve
    if (run.step('ironbrew2', 'Rebuild the program from the IronBrew 2 VM data', rebuildIronBrew)) { unusedAtStart = new WeakSet(); decompiled = true; }
  }

  if (vm && vm.kind === 'obscura' && vm.constants) {
    if (run.step('obscura.vm', 'Lift the Obscura virtual machine back to source', (a) => rebuildObscuraVm(a, vm))) { unusedAtStart = new WeakSet(); decompiled = true; }
  }

  const zartha = { zarthaLifted: false, stats: null };
  if (!vm && (detection.families.some((f) => f.id === 'zartha' && f.confidence >= 0.5) || looksLikeZartha(parsed.ast))) {
    if (run.step('zartha.vm', 'Lift the Zartha virtual machine back to source', (a) => rebuildZarthaVm(a, zartha))) {
      unusedAtStart = new WeakSet(); decompiled = true;
      vm = { kind: 'zartha', lifted: true, functions: [], instructionBytes: 0, constants: null, stats: zartha.stats };
    }
  }

  if (!vm && !zartha.zarthaLifted && (detection.families.some((f) => f.id === 'fusgato' && f.confidence >= 0.5) || looksLikeFusgato(parsed.ast))) {
    const fg = { stats: null };
    if (run.step('fusgato.vm', 'Lift the FusGato virtual machine back to source', (a) => rebuildFusgatoVm(a, fg))) {
      unusedAtStart = new WeakSet(); decompiled = true;
      vm = { kind: 'fusgato', lifted: true, functions: [], instructionBytes: 0, constants: null, stats: fg.stats };
    }
  }

  if (!vm && !zartha.zarthaLifted && !decompiled && looksLikeIronbrikked(parsed.ast)) {
    const ik = { stats: null };
    if (run.step('ironbrikked.vm', 'Lift the IronBrikked virtual machine back to source', (a) => rebuildIronbrikkedVm(a, ik))) {
      unusedAtStart = new WeakSet(); decompiled = true;
      vm = { kind: 'ironbrikked', lifted: true, functions: [], instructionBytes: 0, constants: null, stats: ik.stats };
    }
  }

  // AzureVM: a Lua 5.1 bytecode VM whose payload, keys and handler table are literals of the script
  if (!vm && !zartha.zarthaLifted && !decompiled && looksLikeAzureVM(parsed.ast)) {
    const az = { stats: null, sandbox: options.sandbox && options.sandbox.enabled };
    if (run.step('azurevm.vm', 'Lift the AzureVM virtual machine back to source', (a) => rebuildAzureVm(a, az))) {
      unusedAtStart = new WeakSet(); decompiled = true;
      // Prompt XXX: the clean-up passes keep what the self-check established. (s04_control_flow__AzureGodUltra: the decoder evaluation
      // read one of two identical `pool[decode(...)]` sites as "" — the lifted program was right, the cleaned one printed something else.)
      if (az.verifiedChunk && options.vmGuard !== false) {
        const bytes = az.verifiedChunk;
        run.guard = (a) => { const c = checkAgainstChunk(bytes, print(a)); return c.checked && !c.same ? `the program no longer behaves like the VM's decoded bytecode (${c.reason})` : null; };
      }
      vm = { kind: 'azurevm', lifted: true, functions: [], instructionBytes: 0, constants: null, stats: az.stats };
    }
  }

  // Vault-Obf's register VM: payload blobs, decode parameters and handlers are all literals of the script
  if (!vm && !zartha.zarthaLifted && !decompiled && looksLikeVault(parsed.ast)) {
    const vs = { stats: null };
    if (run.step('vault.vm', 'Lift the Vault virtual machine back to source', (a) => rebuildVaultVm(a, vs))) {
      unusedAtStart = new WeakSet(); decompiled = true;
      vm = { kind: 'vault', lifted: true, functions: [], instructionBytes: 0, constants: null, stats: vs.stats };
    }
  }

  const maybeVmify = detection.families.some((f) => f.id === 'prometheus' && f.confidence >= 0.5);

  const generic = () => {
    let total = 0;
    total += run.step('unwrap', 'Unwrap outer wrapper function', (a) => unwrapWrapper(a), { quiet: true });
    total += run.step('prometheus.antitamper', 'Remove Prometheus anti-tamper block', (a) => removeAntiTamper(a), { quiet: true });
    total += run.step('prometheus.guardflag', 'Remove an anti-tamper guard that wraps the program in `if flag then`', (a) => removeGuardFlag(a), { quiet: true });
    total += run.step('prometheus.guardprefix', 'Remove an anti-tamper guard that ends in `if not flag then fail() end`', (a) => removeGuardPrefix(a), { quiet: true });
    total += run.step('hercules.coinguard', 'Remove the Hercules 1.x coin-flip guard loop', (a) => removeHerculesCoinGuard(a), { quiet: true });
    total += run.step('hercules.antitamper', 'Remove Hercules anti-tamper block', (a) => removeHerculesAntiTamper(a), { quiet: true });
    if (decompiled || detection.families.some((f) => f.id === 'hercules' && f.confidence >= 0.5)) total += run.step('hercules.antitamper.compiled', 'Remove the Hercules anti-tamper check that was compiled with the script', (a) => removeHerculesAntiTamperFunction(a), { quiet: true });
    total += run.step('colisseum.guard', 'Remove the Colisseum tamper guard', (a) => removeColisseumGuard(a), { quiet: true });
    if (zartha.zarthaLifted) total += run.step('zartha.guards', 'Remove the marker and the anti-tamper block the Zartha generator adds', (a) => removeZarthaGuards(a), { quiet: true });
    total += run.step('obscura.guards', 'Remove the executor-detection guards Obscura puts at the top', (a) => removeObscuraGuards(a), { quiet: true });
    if (detection.families.some((f) => f.id === 'hercules' && f.confidence >= 0.5)) {
      total += run.step('hercules.self', 'Read the renamed `self` of methods as `self` again', (a) => restoreMethodSelf(a, analyzeScopes(a)), { quiet: true });
    }
    // stripped bytecode keeps unrelated values in one register; each value gets its own variable before anything looks for constants
    if (decompiled) total += run.step('webs', 'Give values that shared a register their own variables', (a) => splitWebs(a), { quiet: true });
    // closures pasted at every call site are one function each again; the string decoders among them then have calls the evaluator can see
    total += run.step('uninline', 'Give inlined function bodies back their own functions', (a) => uninlinePass(a, { single: detection.families.some((f) => f.id === 'hercules' && f.confidence >= 0.5) }), { quiet: true });
    {
      const n = run.step('hercules.vm', 'Rebuild the program from the Hercules VM data', rebuildHerculesVm, { quiet: true });
      if (n) { total += n; unusedAtStart = new WeakSet(); decompiled = true; bvmTried = 99; }
    }
    if (maybeVmify) {
      // a rebuilt program has no author-written dead code to preserve; Strong applies the pass twice, so this runs each round
      const n = run.step('prometheus.vmify', 'Rebuild the functions Vmify flattened into a dispatcher', (a) => rebuildVmify(a, run), { quiet: true });
      if (n) {
        total += n; unusedAtStart = new WeakSet(); decompiled = true; vmified = true;
        // the script's own wrapper, compiled into the dispatcher with everything else, comes back as a local function called once
        total += run.step('unwrap', 'Unwrap outer wrapper function', (a) => unwrapWrapper(a), { quiet: true });
      }
    }
    if (decompiled) {
      total += run.step('idioms.results', 'Drop the unpack({ f() }) wrappers around calls', (a) => multiResults(a), { quiet: true });
      total += run.step('idioms.bool', 'Write boolean results as expressions', (a) => booleanResults(a), { quiet: true });
      total += run.step('idioms.shortcircuit', 'Write defaults as `a or b`', (a) => shortCircuits(a), { quiet: true });
      total += run.step('idioms.table', 'Fold field assignments into table constructors', (a) => tableConstructors(a), { quiet: true });
      total += run.step('idioms.method', 'Write o.m(o, ...) as o:m(...)', (a) => methodCalls(a), { quiet: true });
      total += run.step('idioms.unset', 'Read temporaries that were never assigned as nil', (a) => unsetLocals(a), { quiet: true });
      total += run.step('idioms.nil', 'Declare locals without an explicit nil', (a) => bareNils(a), { quiet: true });
      total += run.step('idioms.compare', 'Orient comparisons', (a) => orientComparisons(a), { quiet: true });
    }
    total += run.step('metaarith', 'Evaluate numbers hidden behind metamethod arithmetic', (a) => foldMetaArithmetic(a, { sandbox: options.sandbox }), { quiet: true });
    total += run.step('fold', 'Fold constant expressions', (a) => foldPass(a, { foldCalls: options.foldCalls }));
    total += run.step('mba', 'Simplify mixed boolean-arithmetic identities inside bit32 calls', (a) => simplifyMBA(a), { quiet: true });
    // the text it produces may make `"a" .. "b"` and similar foldable
    const pageStrings = run.step('simple_html.strings', 'Read the _D string calls of the single-page obfuscator', (a) => decodePageStrings(a), { quiet: true });
    if (pageStrings) total += pageStrings + run.step('fold.after', 'Fold constant expressions', (a) => foldPass(a, { foldCalls: options.foldCalls }), { quiet: true });
    // a program kept as a list of one-character strings and run by a compiler the script carries (no `loadstring` to call): the text is the program
    {
      const nChars = run.step('charlist', 'Read the program out of the script\u2019s embedded-compiler loader', (a) => unwrapCharList(a), { quiet: true });
      if (nChars) { total += nChars; unusedAtStart = new WeakSet(); refreshDetection(); }
    }
    // XFuscator keeps the program as an array of scaled character codes; the array spells the program
    {
      const nX = run.step('xfuscator.step2', 'Read the program out of XFuscator\u2019s character array', (a) => unwrapXFuscator(a), { quiet: true });
      if (nX) { total += nX; unusedAtStart = new WeakSet(); refreshDetection(); }
    }
    // the loaded text of `loadstring(...)()` becomes the program; compiled Lua in it is decompiled, so the rebuilt-program clean-ups apply
    let layers = null;
    const nLayers = run.step('layers', 'Unwrap loadstring layers', (a) => { layers = unwrapLayers(a, { sandbox: options.sandbox }); return layers; }, { quiet: true });
    if (nLayers) {
      total += nLayers;
      if (layers.bytecode) { unusedAtStart = new WeakSet(); decompiled = true; }
    }
    // a payload that came out of a layer may be a different obfuscator's output: look again, so that the report names it
    if (nLayers) refreshDetection();
    total += run.step('moonveil.constants', 'Decode MoonVeil strings and numbers', (a) => decodeMoonVeilConstants(a), { quiet: true });
    total += run.step('moonveil.cells', 'Read MoonVeil cell variables as fields', (a) => simplifyCells(a), { quiet: true });
    // a script whose program is data for MoonVeil's interpreter is read back from that data: the result replaces the interpreter and needs no
    // further clean-up (the generic passes would only spend their time on the interpreter that is being thrown away)
    if (options.moonveilVm && !vmTried && moonveilShape(run.ast)) {
      vmTried = true;
      const lifted = run.step('moonveil.vm', 'Read the program out of MoonVeil\u2019s VM data and rebuild it', (a) => {
        try { return liftMoonVeilVm(a, { onProgress: options.onProgress || undefined, stubLimit: options.stubLimit, reuseInstructions: options.reuseInstructions }); } catch (e) { if (e instanceof VmUnsupported) return { skipped: e.message }; throw e; }
      }, { quiet: true });
      if (lifted) { vmLifted = true; return total + lifted; }
      // 2.1.0: the reader above does not fit its interpreter. Its container (base 85, LZSS, string table, function header) is read, so the report can say how far the
      // program is understood; the operand layout of its handlers is not read, so nothing is rebuilt from it
      const mvStep = run.steps.get('moonveil.vm');
      if (mvStep && mvStep.status === 'skipped') {
        let c21 = null;
        try { const call = findContainerCall(run.ast, walk); c21 = call && { call, ...readContainer21(call.data) }; } catch (e) { c21 = e instanceof Container21Error ? { error: e.message } : null; }
        if (c21 && !c21.error) {
          run.mv21 = c21;
          run.record('moonveil.container', 'Read MoonVeil 2.1.0\u2019s program container (not rebuilt)', { status: 'skipped', changed: 0, ms: 0, detail: `the container was read: base-85 text (${c21.call.data.length} digits) to ${c21.packedBytes} bytes, LZSS to ${c21.programBytes} bytes, a table of ${c21.strings.length} string(s) and a main function of ${c21.main.instructions} instruction(s). Its functions are read in the step that reads the build\u2019s own function reader (moonveil.program21)` });
        } else if (c21 && c21.error) {
          run.record('moonveil.container', 'Read MoonVeil 2.1.0\u2019s program container (not rebuilt)', { status: 'skipped', changed: 0, ms: 0, detail: `a container call was found but did not read: ${c21.error}` });
        }
      }
    }
    // a rebuilt function has no author-written dead code to preserve, and the clean-ups for rebuilt programs apply to it
    // the names of the table's positions are read while the builder still has its original shape; the factories are put back together once their control flow is rebuilt
    let mvNames = null;
    if (!mvJoined && options.moonveilJoin !== false && detection.families.some((f) => f.id === 'moonveil' && f.confidence >= 0.5)) { try { mvNames = snapshotNames(run.ast); } catch { mvNames = null; } }
    if (mvNames && !run.mvNames) run.mvNames = mvNames;
    const nCff = run.step('moonveil.cff', 'Take MoonVeil\u2019s control-flow flattening apart', (a) => unflattenMoonVeil(a, { gotoFallback: true }), { quiet: true });
    if (nCff) { total += nCff; unusedAtStart = new WeakSet(); decompiled = true; }
    if (mvNames) {
      mvJoined = true;
      const joined = run.step('moonveil.join', 'Join MoonVeil\u2019s table of factories into one program', (a) => {
        try { return joinMoonVeil(a, mvNames); } catch (e) { if (e instanceof JoinError) return { skipped: e.message }; throw e; }
      });
      if (joined) { total += joined; unusedAtStart = new WeakSet(); decompiled = true; }
    }
    if (mvJoined) total += run.step('moonveil.unbox', 'Read MoonVeil cells as the variables they stand for', (a) => unboxCells(a), { quiet: true });
    total += run.step('simplify', 'Simplify control flow and remove dead code', (a) => simplifyPass(a, { unusedAtStart }));
    // the dispatcher kept its own constants in a table (`__env[K[27]]` is a global): with them in place the globals read as globals
    if (vmified) total += run.step('constants.inline', 'Replace reads of a machine-named table of constants by the constants', (a) => inlineConstantTable(a, { anyName: true }), { quiet: true });
    if (vmified) total += run.step('prometheus.env', 'Read globals from the environment table again', (a) => envToGlobals(a), { quiet: true });
    if (decompiled) total += run.step('regions', 'Evaluate closed constant computations', (a) => regionPass(a), { quiet: true });
    if (decompiled) total += run.step('dataflow', 'Remove dead stores, copies and temporaries', (a) => dataflowPass(a), { quiet: true });
    if (decompiled) total += run.step('idioms.loops', 'Write counting loops as for loops', (a) => numericLoops(a), { quiet: true });
    if (decompiled) total += run.step('idioms.whiles', 'Move loop exit tests into the loop header', (a) => loopForms(a), { quiet: true });
    total += run.step('tidy', 'Tidy flipped tests', (a) => tidyIfs(a), { quiet: true });
    total += run.step('whileonce', 'Write loops whose body always leaves them as conditionals', (a) => whileToIf(a), { quiet: true });
    total += run.step('prometheus.proxify', 'Undo Prometheus ProxifyLocals', (a) => undoProxifyLocals(a), { quiet: true });
    // a rebuilt machine reaches its decoder through copies made at the top of each function; the decoder is only seen once they are gone
    total += run.step('stable', 'Read copies of values that never change as the values', (a) => propagateStable(a), { quiet: true });
    // a string table that decrypts itself in place: the decoder's first argument becomes the stored text so that the evaluator can run it
    total += run.step('strtable.seed', 'Read the strings of a self-decrypting table as the decoder\u2019s arguments', (a) => seedDecoderCalls(a), { quiet: true });
    if (options.sandbox.enabled) {
            total += run.step('evaluate', 'Evaluate string decoders (sandbox)', (a) => evaluatePass(a, { sandbox: options.sandbox, memory: evalMemory }));
    } else {
      run.record('evaluate', 'Evaluate string decoders (sandbox)', { status: 'skipped', changed: 0, detail: 'sandboxed evaluation is not enabled', ms: 0 });
    }
    total += run.step('strtable.inline', 'Replace reads of a self-decrypting string table by its strings', (a) => inlineStringTable(a), { quiet: true });
    // a program that was first obfuscated at the syntax level (LuaXen `both`): the compressed bytes of its VM are a literal only once the layer above has been undone
    if (!vm && !decompiled && !ikTried && looksLikeIronbrikked(run.ast)) {
      ikTried = true;
      const ik = { stats: null };
      const n = run.step('ironbrikked.vm', 'Lift the IronBrikked virtual machine back to source', (a) => rebuildIronbrikkedVm(a, ik), { quiet: true });
      if (n) { unusedAtStart = new WeakSet(); decompiled = true; vm = { kind: 'ironbrikked', lifted: true, functions: [], instructionBytes: 0, constants: null, stats: ik.stats }; total += n; }
    }
    total += run.step('prometheus.orphans', 'Remove the string-decryption machinery nothing reads any more', (a) => removeOrphanDecoders(a), { quiet: true });
    total += run.step('prometheus.joiner', 'Remove the SplitStrings joiner nothing calls any more', (a) => removeUnusedJoiner(a), { quiet: true });
    total += run.step('constants.inline', 'Replace reads of a machine-named table of constants by the constants', (a) => inlineConstantTable(a), { quiet: true });
    // an anti-tamper guard the dispatcher had compiled with everything else, readable now that its strings are
    if (vmified) total += run.step('prometheus.guardprefix', 'Remove an anti-tamper guard that ends in `if not flag then fail() end`', (a) => removeGuardPrefix(a), { quiet: true });
    // Prometheus' register VM: its program is a literal of records, readable once the layers above are undone
    if (bvmTried < 4 && looksLikePrometheusBvm(run.ast)) {
      bvmTried++;
      const n = run.step('prometheus.bvm', 'Lift the Prometheus register VM back to source', (a) => { try { const r = liftPrometheusBvm(a); run.bvm = r.stats; return r; } catch (e) { if (e instanceof BvmError) return { changed: 0, skipped: e.message }; throw e; } }, { quiet: true });
      if (n) { total += n; unusedAtStart = new WeakSet(); decompiled = true; }
    }
    // once decoded names are plain strings, `obj.method(obj, ...)` (what tools that route every call through a lookup write) is `obj:method(...)` again
    if (!decompiled) total += run.step('idioms.method.plain', 'Write o.m(o, ...) as o:m(...)', (a) => methodCalls(a), { quiet: true });
    return total;
  };

  for (let round = 1; round <= options.maxRounds; round++) {
    if (!generic() || vmLifted) break;
  }
  if (vmLifted) decompiled = true;
  // whatever the steps above did not know about: structure-driven strategies that choose themselves from what the code is made of
  let adaptive = null;
  if (options.adaptive) {
    run.step('adaptive', 'Read the structure of the code and recover what can be recovered', (a) => {
      adaptive = new AdaptiveEngine().run(a, {
        sandbox: options.sandbox,
        budgetMs: options.adaptiveBudgetMs,
        foldCalls: options.foldCalls,
        unusedAtStart: decompiled ? new WeakSet() : unusedAtStart,
        rebuilt: decompiled,
        observeOnly: vmLifted,
        onProgress: options.onProgress || undefined,
      });
      return { changed: adaptive.changed, scoreBefore: adaptive.score.before, scoreAfter: adaptive.score.after, left: adaptive.residual.length };
    });
    if (adaptive && adaptive.rebuilt) decompiled = true;
  }
  // loops a dispatcher or a compiler lowered to `while` (the structure reader may have just produced them)
  if ((options.adaptive || decompiled)) {
    const n = run.step('loops.raise', 'Write lowered loops as for loops again', (a) => raiseLoops(a), { quiet: true });
    if (n) run.step('simplify.after-loops', 'Simplify control flow and remove dead code', (a) => simplifyPass(a, { unusedAtStart: new WeakSet() }), { quiet: true });
  }
  // what the structure reader rebuilt exposes what the first rounds could not see: copies of values that never change, and constants now in one place
  if (adaptive && adaptive.rebuilt) {
    const k = run.step('stable.after-adaptive', 'Read copies of values that never change as the values', (a) => propagateStable(a), { quiet: true });
    if (k) {
      run.step('fold.after-adaptive', 'Fold constant expressions', (a) => foldPass(a, { foldCalls: options.foldCalls }), { quiet: true });
      run.step('simplify.after-adaptive', 'Simplify control flow and remove dead code', (a) => simplifyPass(a, { unusedAtStart: new WeakSet() }), { quiet: true });
    }
  }
  if (vmified) run.step('prometheus.guardprefix.late', 'Remove an anti-tamper guard that ends in `if not flag then fail() end`', (a) => removeGuardPrefix(a), { quiet: true });
  if (vmified) run.step('prometheus.sanity', 'Remove the sanity-check loop an anti-tamper guard leaves in front of it', (a) => removeSanityCheck(a), { quiet: true });
  if (vmified) run.step('prometheus.environment', 'Declare the environment the script still reads', (a) => envToGlobals(a, true), { quiet: true });
  if (!vmLifted) run.step('varargs', 'Remove unused vararg parameters', (a) => removeUnusedVararg(a), { quiet: true });
  // the rebuilt program is already named and laid out; the later passes would only rename what was named on purpose
  if (options.rename !== 'off' && !vmLifted) run.step('rename', 'Give obfuscated locals readable names', (a) => renamePass(a, { mode: options.rename, roleHints: options.roleHints ? options.roleHints(a) : null }), { quiet: true });
  if (decompiled && !vmLifted) run.step('idioms.functions', 'Use function and method declarations', (a) => functionForms(a), { quiet: true });

  // MoonVeil 2.1.0: with the reader's flattening undone and the passes done, the layout of a function is read off the build's own reader and the program data is read with it, to the last byte
  if (run.mv21 && !run.mv21.schemaTried) {
    run.mv21.schemaTried = true;
    try {
      const schema = deriveSchema21(run.ast);
      const prog = readProgram21(run.mv21.program, schema);
      run.mv21.read = prog;
      const order = schema.steps.map((x) => x.kind).filter((k) => k !== 'varint' && k !== 'byte').join(', ');
      run.record('moonveil.program21', 'Read MoonVeil 2.1.0\u2019s program with the layout its own reader uses', { status: 'applied', changed: 0, ms: 0, detail: `the program data was read to its last byte with the layout derived from this build\u2019s reader (function marker ${schema.marker}; sections ${order}): ${prog.stats.functions} function(s), ${prog.stats.instructions} instruction(s), ${prog.stats.constants} constant(s), ${prog.strings.length} string(s)` });
      // the handlers: each instruction is run through its handler with its fields known (lift21.js), the result decompiled and joined with the code MoonVeil left as Lua
      const holder = { stats: null };
      const rebuilt = run.step('moonveil.vm21', 'Rebuild MoonVeil 2.1.0\u2019s program from what its handlers do with each instruction', (a) => rebuildMoonVeil21(a, { snapshot: run.mvNames, prog, schema, source, options, holder }), { quiet: true });
      if (rebuilt) {
        vmLifted = true;
        vm = { kind: 'moonveil21', lifted: true, functions: [], instructionBytes: 0, constants: null, stats: holder.stats };
        run.step('moonveil.unbox', 'Read MoonVeil cells as the variables they stand for', (a) => unboxCells(a), { quiet: true });
        run.step('simplify.mv21', 'Simplify control flow and remove dead code', (a) => simplifyPass(a, { unusedAtStart: new WeakSet() }), { quiet: true });
        run.step('dataflow.mv21', 'Remove dead stores, copies and temporaries', (a) => dataflowPass(a), { quiet: true });
        run.step('idioms.whiles.mv21', 'Move loop exit tests into the loop header', (a) => loopForms(a), { quiet: true });
        if (options.rename !== 'off') run.step('rename.mv21', 'Give obfuscated locals readable names', (a) => renamePass(a, { mode: options.rename }), { quiet: true });
        run.step('idioms.functions.mv21', 'Use function and method declarations', (a) => functionForms(a), { quiet: true });
      }
    } catch (e) {
      if (!(e instanceof Schema21Error)) throw e;
      run.record('moonveil.program21', 'Read MoonVeil 2.1.0\u2019s program with the layout its own reader uses (not rebuilt)', { status: 'skipped', changed: 0, ms: 0, detail: `the layout could not be read off this build\u2019s reader: ${e.message}` });
    }
  }

  // RealObfuscator's function VM: read late, once the bank's constants are plain values (the lifter itself does not need them to be)
  if (!vmLifted && options.realobfuscatorVm !== false && detection.families.some((f) => f.id === 'realobfuscator' && f.confidence >= 0.5) && looksLikeRealObfuscatorVm(run.ast)) {
    const holder = { stats: null };
    const lifted = run.step('realobfuscator.vm', 'Lift RealObfuscator\u2019s function VM back to source', (a) => rebuildRealObfuscatorVm(a, { source, options, holder }), { quiet: true });
    if (lifted) {
      vmLifted = true;
      vm = { kind: 'realobfuscator', lifted: true, functions: [], instructionBytes: 0, constants: null, stats: holder.stats };
      // string decoders the VM's constants called are now in plain code: they are evaluated like any other
      if (options.sandbox.enabled) run.step('evaluate.ro', 'Evaluate string decoders (sandbox)', (a) => evaluatePass(a, { sandbox: options.sandbox, memory: evalMemory }), { quiet: true });
      run.step('simplify.ro', 'Simplify control flow and remove dead code', (a) => simplifyPass(a, { unusedAtStart: new WeakSet() }), { quiet: true });
      run.step('orphans.ro', 'Remove the string-decryption machinery nothing reads any more', (a) => removeOrphanDecoders(a), { quiet: true });
      run.step('dataflow.ro', 'Remove dead stores, copies and temporaries', (a) => dataflowPass(a), { quiet: true });
      run.step('idioms.loops.ro', 'Write counting loops as for loops', (a) => numericLoops(a), { quiet: true });
      run.step('idioms.whiles.ro', 'Move loop exit tests into the loop header', (a) => loopForms(a), { quiet: true });
      if (options.rename !== 'off') run.step('rename.ro', 'Give obfuscated locals readable names', (a) => renamePass(a, { mode: options.rename }), { quiet: true });
      run.step('idioms.functions.ro', 'Use function and method declarations', (a) => functionForms(a), { quiet: true });
    }
  }

  // ---- output and validation --------------------------------------------------------------------------------
  let output;
  try {
    output = print(run.ast, printOptions(options));
  } catch (e) {
    return { ok: false, stage: 'print', error: { message: String(e.message || e) }, output: null, steps: [...run.steps.values()], detection, warnings: run.warnings };
  }
  const validation = validateOutput(output, run.ast, options);
  if (!validation.ok) run.warnings.push(validation.message);
  const steps = [...run.steps.values()];
  const confidence = assessConfidence(detection, output, { steps, validation, ast: run.ast, adaptive, vm });
  const report = buildReport({ detection, steps, confidence, adaptive, vm });

  return {
    adaptive,
    vm,
    report,
    ok: validation.ok,
    output: options.annotate ? annotate(output, report) : output,
    steps,
    detection,
    validation,
    confidence,
    warnings: run.warnings,
    ms: now() - t0,
  };
}

/**
 * Re-parse the printed output and check that printing is stable: print(parse(print(ast))) must equal
 * print(ast). Comparing trees directly would flag harmless canonicalisation (a negative literal printed as
 * `-5` reads back as a unary minus), while a text fixpoint catches every case where the printed program is
 * not the one we meant to print.
 */
const printOptions = (o) => ({ ...(o.format || {}), strings: o.stringStyle || 'normalize', numbers: o.stringStyle || 'normalize' });

export function validateOutput(output, ast, options = {}) {
  const re = tryParse(output);
  if (!re.ok) return { ok: false, syntax: false, roundTrip: false, message: `The recovered code does not parse: ${re.error.message}` };
  let again;
  try { again = print(re.ast, printOptions(options)); } catch { again = null; }
  const same = again === output;
  return { ok: same, syntax: true, roundTrip: same, message: same ? 'Recovered code parses and prints back identically.' : 'Recovered code parses, but printing it again gives different text.' };
}
