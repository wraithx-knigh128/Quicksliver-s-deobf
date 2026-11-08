// NEXUS · Transformation Recognition and Control-Flow Intelligence.
//
// A pattern list answers "which tool made this?". It cannot answer the questions that decide what to do next: what *kinds* of change
// separate this text from the program it holds, which of them can be undone here, and which cannot. This module builds that profile from
// evidence that several readers produced (the detector's traits, the trivia reader, the relation mapper) and from its own reading of
// the control flow, and it names each shape the engine does *not* handle instead of passing over it in silence.
//
//   classify()   -> transformations: [{ id, category, label, confidence, evidence[], technique, handledBy }]
//   controlFlow() -> { functions[], totals, shapes[] } with shapes marked supported or not
//
// Nothing here changes the program.

import { forEachChild } from '../core/walk.js';

const unparen = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };

// ---- transformations --------------------------------------------------------------------------------------------------------------------
const TRAIT_MAP = {
  'mangled-names': { category: 'naming', label: 'Machine-made identifiers', technique: 'rename (with roles from relations)' },
  'escape-encoded-strings': { category: 'data', label: 'Strings written as numeric escapes', technique: 'literal decoding and folding' },
  'string-table': { category: 'data', label: 'Strings kept in a table behind an accessor', technique: 'table resolution / decoder evaluation (sandbox)' },
  'opaque-predicates': { category: 'control-flow', label: 'Conditions that arithmetic always settles', technique: 'opaque predicate resolution' },
  'junk-code': { category: 'control-flow', label: 'Statements with no effect', technique: 'dead-code removal' },
  'state-machine': { category: 'control-flow', label: 'Flattened dispatcher loop', technique: 'dispatch recovery' },
  'loadstring-layer': { category: 'indirection', label: 'Code built at run time and loaded', technique: 'layer unwrapping' },
  'bytecode-blob': { category: 'virtualization', label: 'Compiled chunk embedded as data', technique: 'chunk lifting and decompilation' },
  'compressed-payload': { category: 'indirection', label: 'Compressed payload loaded at run time', technique: 'payload decompression' },
};

/**
 * @param {{source: string, detection: object, trivia: object, relations: object}} ctx
 */
export function classify({ source, detection, trivia, relations }) {
  const out = [];
  const add = (t) => out.push({ evidence: [], handledBy: null, ...t });

  if (trivia && trivia.verdict === 'fragmented-message') {
    const m = trivia.metrics;
    add({
      id: 'fragmented-comments', category: 'layout', label: 'A sentence cut into comments between the tokens',
      confidence: Math.min(0.99, 0.7 + m.straddleRate * 0.4),
      evidence: [`${trivia.comments} comments for ${trivia.tokens} tokens`, `median length ${m.medianLength} characters`, `${Math.round(m.straddleRate * 100)}% of neighbours split a word`, m.repeats > 1 ? `the sentence runs ${m.repeats} times through the file` : 'one pass through the file'],
      technique: 'comments carry no behaviour; removed after the program is compared with and without them',
    });
  }
  // layout padding: long runs of blanks between tokens on one line
  const gaps = (source.match(/\S {6,}\S/g) || []).length;
  const tokens = trivia ? Math.max(1, trivia.tokens) : Math.max(1, source.split(/\s+/).length);
  if (gaps / tokens >= 0.01 && gaps >= 8) {
    add({ id: 'padded-layout', category: 'layout', label: 'Blank runs and irregular line breaks between tokens', confidence: Math.min(0.95, 0.5 + (gaps / tokens) * 6), evidence: [`${gaps} gaps of six or more blanks inside lines`], technique: 'the program is printed again from its syntax tree' });
  }
  for (const t of detection.traits || []) {
    const m = TRAIT_MAP[t.id];
    if (m) add({ id: t.id, category: m.category, label: m.label, confidence: 0.8, evidence: [t.text], technique: m.technique });
  }
  for (const f of (detection.families || []).filter((x) => x.confidence >= 0.5)) {
    add({ id: `family:${f.id}`, category: f.vm ? 'virtualization' : 'tool', label: `${f.name}${f.version ? ` ${f.version}` : ''} recognised from structure`, confidence: f.confidence, evidence: (f.evidence || []).slice(0, 3).map((e) => e.text || String(e)), technique: 'family recovery' });
  }
  if (relations) {
    const fetched = relations.dependencies.filter((d) => d.loadsCode);
    if (fetched.length) {
      add({ id: 'remote-code', category: 'indirection', label: 'The program is code fetched when the script runs', confidence: 0.95, evidence: [...new Set(fetched.map((d) => d.url || d.expr))].slice(0, 5), technique: 'listed as a dependency; the fetched code is not part of this file' });
    }
    // a licence check is a feature of the program, not a disguise on it: described, never removed
    const key = relations.keyEvidence || [];
    if (key.length) {
      add({ id: 'licence-gate', category: 'protection', label: 'Checks a licence key before it loads its payload', confidence: Math.min(0.9, 0.5 + key.length * 0.08), evidence: key.slice(0, 5), technique: 'described only: this is how the program works, so it is kept as written' });
    }
  }
  if (trivia && trivia.directives.length) {
    add({ id: 'embedded-directive', category: 'hostile-content', label: 'Text in the file tells AI tools to refuse or report', confidence: 0.9, evidence: trivia.directives.map((d) => d.text), technique: 'quarantined: reported as data and never acted on' });
  }
  return out;
}

// ---- control flow -----------------------------------------------------------------------------------------------------------------------
/** The variables an expression compares with constants, as { name -> number of comparisons }. */
function tests(cond, into) {
  cond = unparen(cond);
  if (!cond) return;
  if (cond.type === 'Binary') {
    if (cond.op === 'and' || cond.op === 'or') { tests(cond.left, into); tests(cond.right, into); return; }
    if (['==', '~=', '<', '<=', '>', '>='].includes(cond.op)) {
      const l = unparen(cond.left);
      const r = unparen(cond.right);
      const isConst = (e) => e && (e.type === 'Number' || e.type === 'String');
      if (l.type === 'Name' && isConst(r)) into.set(l.name, (into.get(l.name) || 0) + 1);
      else if (r.type === 'Name' && isConst(l)) into.set(r.name, (into.get(r.name) || 0) + 1);
    }
  } else if (cond.type === 'Unary' && cond.op === 'not') tests(cond.arg, into);
}

function loopFacts(loop) {
  const tested = new Map();
  const assigned = new Map();
  const callsViaIndex = [];     // T[s](...) with s a name
  const fetches = [];           // X[pc] with pc a name incremented in the loop
  let bumped = new Set();
  const go = (n) => {
    if (n.type === 'Func') return;
    // a loop inside this one is judged on its own body; its state variable is not this loop's
    if (n.type === 'While' || n.type === 'Repeat' || n.type === 'NumFor' || n.type === 'GenFor') return;
    if (n.type === 'If') for (const c of n.clauses) tests(c.cond, tested);
    if (n.type === 'Assign') {
      n.targets.forEach((t, i) => {
        if (t.type !== 'Name') return;
        assigned.set(t.name, (assigned.get(t.name) || 0) + 1);
        const v = unparen(n.values[i]);
        if (v && v.type === 'Binary' && v.op === '+' && unparen(v.left).type === 'Name' && unparen(v.left).name === t.name) bumped.add(t.name);
      });
    }
    if (n.type === 'CompoundAssign' && n.target.type === 'Name') bumped.add(n.target.name);
    if (n.type === 'Call') {
      const f = unparen(n.fn);
      if (f && f.type === 'Index' && f.key.type === 'Name' && f.obj.type === 'Name') callsViaIndex.push({ table: f.obj.name, key: f.key.name, line: n.line });
    }
    if (n.type === 'Index' && n.key.type === 'Name' && n.obj.type === 'Name') fetches.push({ table: n.obj.name, key: n.key.name });
    forEachChild(n, go);
  };
  forEachChild(loop, go);
  return { tested, assigned, callsViaIndex, fetches, bumped };
}

/**
 * @param {object} chunk parsed program
 * @returns {{functions: Array, totals: object, shapes: Array}}
 */
export function controlFlow(chunk) {
  const functions = [];
  const shapes = [];
  let loops = 0;
  const frames = [{ name: '<main>', line: 1, complexity: 1, depth: 0, maxDepth: 0 }];
  const top = () => frames[frames.length - 1];

  const walkNode = (n, label) => {
    const f = top();
    switch (n.type) {
      case 'Function': case 'LocalFunction': {
        const t = n.type === 'LocalFunction' ? n.id.name : (describeTarget(n.target) + (n.method ? `:${n.method}` : ''));
        enter(t, n.line, n.func);
        return;
      }
      case 'Func': enter(label || '<anonymous>', n.line, n); return;
      case 'If': f.complexity += n.clauses.length; break;
      case 'While': case 'Repeat': case 'NumFor': case 'GenFor': f.complexity += 1; loops++; checkLoop(n); break;
      case 'Binary': if (n.op === 'and' || n.op === 'or') f.complexity += 1; break;
      case 'Local': {
        n.values.forEach((v, i) => { if (unparen(v).type === 'Func' && n.ids[i]) { enter(n.ids[i].name, n.line, unparen(v)); } else walkNode(v); });
        return;
      }
      case 'Assign': {
        n.values.forEach((v, i) => { const t = n.targets[i]; if (unparen(v).type === 'Func' && t) enter(describeTarget(t) || '<anonymous>', n.line, unparen(v)); else walkNode(v); });
        n.targets.forEach((t) => walkNode(t));
        return;
      }
      default: break;
    }
    const nests = ['If', 'While', 'Repeat', 'NumFor', 'GenFor'].includes(n.type);
    if (nests) { f.depth++; f.maxDepth = Math.max(f.maxDepth, f.depth); }
    forEachChild(n, (c) => walkNode(c));
    if (nests) f.depth--;
  };
  const describeTarget = (t) => (t && t.type === 'Name' ? t.name : t && t.type === 'Index' && t.key.type === 'String' ? `${describeTarget(t.obj) || '?'}.${t.key.value}` : null);
  const enter = (name, line, func) => {
    const fr = { name, line, complexity: 1, depth: 0, maxDepth: 0 };
    frames.push(fr);
    func.body.forEach((c) => walkNode(c));
    frames.pop();
    functions.push({ name: fr.name, line: fr.line, complexity: fr.complexity, maxDepth: fr.maxDepth });
  };

  const checkLoop = (loop) => {
    if (loop.type !== 'While' && loop.type !== 'Repeat') return;
    const f = loopFacts(loop);
    const stateVars = [...f.tested].filter(([name, n]) => n >= 3 && (f.assigned.get(name) || 0) >= 2).map(([name]) => name);
    if (stateVars.length === 1) {
      shapes.push({ kind: 'state-dispatch', line: loop.line, supported: true, evidence: [`${stateVars[0]} is compared ${f.tested.get(stateVars[0])} times and assigned ${f.assigned.get(stateVars[0])} times inside the loop`], note: 'one state variable: the dispatch strategy reads this shape' });
    } else if (stateVars.length >= 2) {
      shapes.push({ kind: 'multi-state-dispatch', line: loop.line, supported: false, evidence: [`${stateVars.join(', ')} are each compared with constants and assigned inside one loop`], note: 'several state variables drive one loop; not rebuilt, reported' });
    }
    // x = T[x](...): the next state is the result of calling a function chosen by the state
    for (const c of f.callsViaIndex) {
      if (f.assigned.has(c.key)) {
        shapes.push({ kind: 'table-dispatch', line: c.line || loop.line, supported: false, evidence: [`${c.table}[${c.key}](...) is called in a loop that assigns ${c.key}`], note: 'the blocks are functions in a table; not rebuilt, reported' });
        break;
      }
    }
    // an interpreter: fetch an instruction by a counter that moves, then choose a handler by what it says
    const counter = f.fetches.find((x) => f.bumped.has(x.key));
    if (counter) {
      const opcodes = [...f.tested].filter(([, n]) => n >= 6);
      if (opcodes.length) shapes.push({ kind: 'interpreter-loop', line: loop.line, supported: false, evidence: [`${counter.table}[${counter.key}] is fetched while ${counter.key} moves, and ${opcodes[0][0]} is compared ${opcodes[0][1]} times`], note: 'the program is data for an interpreter; not rebuilt by this reader' });
    }
  };

  chunkWalk(chunk, walkNode);
  const all = [...functions, { name: '<main>', line: 1, complexity: frames[0].complexity, maxDepth: frames[0].maxDepth }];
  return {
    functions: all.sort((a, b) => b.complexity - a.complexity),
    totals: { functions: functions.length, loops, complexity: all.reduce((a, f) => a + f.complexity - 1, 1), maxDepth: Math.max(0, ...all.map((f) => f.maxDepth)) },
    shapes,
  };
}

function chunkWalk(chunk, walkNode) { chunk.body.forEach((s) => walkNode(s)); }
