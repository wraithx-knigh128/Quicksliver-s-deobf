// Line diff for the Compare view.
//
// Myers' O(ND) algorithm finds a minimal edit script, but its cost grows with the number of differences, and
// a recovered script can differ from its input on nearly every line. So the work is bounded:
//
//   1. strip the common prefix and suffix;
//   2. anchor on lines that occur exactly once on each side (patience diff), keeping the longest increasing run;
//   3. run Myers between anchors, with a cap on the edit distance; a gap that exceeds the cap is reported
//      as one replaced block instead of being searched further.
//
// The result is always a correct edit script (applying it to `a` gives `b`); only minimality is given up
// when a region is too different to be worth aligning.

const MAX_D = 1500;

/** @returns {Array<{op: 'eq'|'del'|'add', a?: number, b?: number}>} indices are 0-based line numbers */
export function diffLines(a, b, { maxD = MAX_D } = {}) {
  const ids = new Map();
  const intern = (s) => { let v = ids.get(s); if (v === undefined) { v = ids.size; ids.set(s, v); } return v; };
  const A = a.map(intern);
  const B = b.map(intern);
  const ops = [];
  let lo = 0;
  let hiA = A.length;
  let hiB = B.length;
  while (lo < hiA && lo < hiB && A[lo] === B[lo]) { ops.push({ op: 'eq', a: lo, b: lo }); lo++; }
  const tail = [];
  while (hiA > lo && hiB > lo && A[hiA - 1] === B[hiB - 1]) { hiA--; hiB--; tail.push({ op: 'eq', a: hiA, b: hiB }); }
  region(A, B, lo, hiA, lo, hiB, ops, maxD);
  for (let i = tail.length - 1; i >= 0; i--) ops.push(tail[i]);
  return ops;
}

function region(A, B, a0, a1, b0, b1, out, maxD) {
  if (a0 === a1 && b0 === b1) return;
  if (a0 === a1) { for (let j = b0; j < b1; j++) out.push({ op: 'add', b: j }); return; }
  if (b0 === b1) { for (let i = a0; i < a1; i++) out.push({ op: 'del', a: i }); return; }

  const anchors = uniqueAnchors(A, B, a0, a1, b0, b1);
  if (anchors.length) {
    let pa = a0;
    let pb = b0;
    for (const [i, j] of anchors) {
      gap(A, B, pa, i, pb, j, out, maxD);
      out.push({ op: 'eq', a: i, b: j });
      pa = i + 1;
      pb = j + 1;
    }
    gap(A, B, pa, a1, pb, b1, out, maxD);
    return;
  }
  gap(A, B, a0, a1, b0, b1, out, maxD);
}

/** Between two anchors: trim, then Myers, then (if the region has anchors of its own) recurse. */
function gap(A, B, a0, a1, b0, b1, out, maxD) {
  while (a0 < a1 && b0 < b1 && A[a0] === B[b0]) { out.push({ op: 'eq', a: a0++, b: b0++ }); }
  const tail = [];
  while (a1 > a0 && b1 > b0 && A[a1 - 1] === B[b1 - 1]) { a1--; b1--; tail.push({ op: 'eq', a: a1, b: b1 }); }
  if (a0 === a1 || b0 === b1) {
    for (let i = a0; i < a1; i++) out.push({ op: 'del', a: i });
    for (let j = b0; j < b1; j++) out.push({ op: 'add', b: j });
  } else {
    const inner = uniqueAnchors(A, B, a0, a1, b0, b1);
    // Recursing is only productive when new anchors appear that the outer call did not already use.
    if (inner.length && (a1 - a0) * (b1 - b0) > 4 * maxD * maxD) region(A, B, a0, a1, b0, b1, out, maxD);
    else {
      const script = myers(A, B, a0, a1, b0, b1, maxD);
      if (script) out.push(...script);
      else {
        for (let i = a0; i < a1; i++) out.push({ op: 'del', a: i });
        for (let j = b0; j < b1; j++) out.push({ op: 'add', b: j });
      }
    }
  }
  for (let i = tail.length - 1; i >= 0; i--) out.push(tail[i]);
}

/** Lines that occur exactly once in both ranges, reduced to the longest chain that keeps both orders. */
function uniqueAnchors(A, B, a0, a1, b0, b1) {
  const countA = new Map();
  const posA = new Map();
  for (let i = a0; i < a1; i++) { countA.set(A[i], (countA.get(A[i]) || 0) + 1); posA.set(A[i], i); }
  const countB = new Map();
  const posB = new Map();
  for (let j = b0; j < b1; j++) { countB.set(B[j], (countB.get(B[j]) || 0) + 1); posB.set(B[j], j); }
  const pairs = [];
  for (let j = b0; j < b1; j++) {
    const v = B[j];
    if (countB.get(v) === 1 && countA.get(v) === 1) pairs.push([posA.get(v), j]);
  }
  if (!pairs.length) return [];
  // longest increasing subsequence on the A index (pairs are already ordered by B index)
  const tails = [];
  const prev = new Array(pairs.length).fill(-1);
  const tailIdx = [];
  for (let k = 0; k < pairs.length; k++) {
    let lo = 0;
    let hi = tails.length;
    while (lo < hi) { const mid = (lo + hi) >> 1; if (tails[mid] < pairs[k][0]) lo = mid + 1; else hi = mid; }
    tails[lo] = pairs[k][0];
    tailIdx[lo] = k;
    prev[k] = lo > 0 ? tailIdx[lo - 1] : -1;
  }
  const chain = [];
  for (let k = tailIdx[tails.length - 1]; k !== -1; k = prev[k]) chain.push(pairs[k]);
  return chain.reverse();
}

/** Myers' greedy algorithm with a cap; returns null when more than maxD edits would be needed. */
function myers(A, B, a0, a1, b0, b1, maxD) {
  const N = a1 - a0;
  const M = b1 - b0;
  const max = Math.min(N + M, maxD);
  const size = 2 * max + 3;
  const offset = max + 1;
  let v = new Int32Array(size);
  const trace = [];
  let found = -1;
  for (let d = 0; d <= max; d++) {
    trace.push(v.slice());
    for (let k = -d; k <= d; k += 2) {
      let x;
      if (k === -d || (k !== d && v[offset + k - 1] < v[offset + k + 1])) x = v[offset + k + 1];
      else x = v[offset + k - 1] + 1;
      let y = x - k;
      while (x < N && y < M && A[a0 + x] === B[b0 + y]) { x++; y++; }
      v[offset + k] = x;
      if (x >= N && y >= M) { found = d; break; }
    }
    if (found >= 0) break;
  }
  if (found < 0) return null;

  const script = [];
  let x = N;
  let y = M;
  for (let d = found; d > 0; d--) {
    const vv = trace[d];
    const k = x - y;
    let prevK;
    if (k === -d || (k !== d && vv[offset + k - 1] < vv[offset + k + 1])) prevK = k + 1;
    else prevK = k - 1;
    const prevX = vv[offset + prevK];
    const prevY = prevX - prevK;
    while (x > prevX && y > prevY) { x--; y--; script.push({ op: 'eq', a: a0 + x, b: b0 + y }); }
    if (x === prevX) { y--; script.push({ op: 'add', b: b0 + y }); }
    else { x--; script.push({ op: 'del', a: a0 + x }); }
  }
  while (x > 0 && y > 0) { x--; y--; script.push({ op: 'eq', a: a0 + x, b: b0 + y }); }
  return script.reverse();
}

/**
 * Turn an edit script into side-by-side rows. Runs of deletions followed by additions are paired up as
 * "changed" rows so a modified line sits next to its replacement.
 * @returns {{rows: Array<{kind: 'eq'|'del'|'add'|'chg', a: number, b: number}>, stats: {added: number, removed: number, changed: number, same: number}}}
 *   a / b are 0-based line indices, or -1 when that side has no line
 */
export function toRows(ops) {
  const rows = [];
  const stats = { added: 0, removed: 0, changed: 0, same: 0 };
  for (let i = 0; i < ops.length;) {
    if (ops[i].op === 'eq') { rows.push({ kind: 'eq', a: ops[i].a, b: ops[i].b }); stats.same++; i++; continue; }
    const dels = [];
    const adds = [];
    while (i < ops.length && ops[i].op !== 'eq') { (ops[i].op === 'del' ? dels : adds).push(ops[i]); i++; }
    const pairs = Math.min(dels.length, adds.length);
    for (let k = 0; k < pairs; k++) { rows.push({ kind: 'chg', a: dels[k].a, b: adds[k].b }); stats.changed++; }
    for (let k = pairs; k < dels.length; k++) { rows.push({ kind: 'del', a: dels[k].a, b: -1 }); stats.removed++; }
    for (let k = pairs; k < adds.length; k++) { rows.push({ kind: 'add', a: -1, b: adds[k].b }); stats.added++; }
  }
  return { rows, stats };
}

/**
 * Hide long runs of unchanged rows. Returns row indices to show, with -1 marking "N unchanged lines".
 * @param {number} context unchanged lines kept around each change
 */
export function collapseRows(rows, context = 3) {
  const keep = new Uint8Array(rows.length);
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].kind === 'eq') continue;
    for (let k = Math.max(0, i - context); k <= Math.min(rows.length - 1, i + context); k++) keep[k] = 1;
  }
  const out = [];
  for (let i = 0; i < rows.length;) {
    if (keep[i]) { out.push(rows[i]); i++; continue; }
    let j = i;
    while (j < rows.length && !keep[j]) j++;
    out.push({ kind: 'fold', count: j - i, a: rows[i].a, b: rows[i].b });
    i = j;
  }
  return out;
}
