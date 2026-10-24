// Recursive-descent parser for Lua 5.1 - 5.4 and Luau.
//
// The grammar is the union of the dialects. While parsing, every dialect-specific construct that is
// encountered is recorded in `ast.features` so that version detection can rest on evidence instead of
// guessing (see detect/dialect.js).
//
// AST conventions (see also walk.js, which lists the child fields of every node type):
//   declarations are `Id` nodes ({type:'Id', name}); uses are `Name` nodes.
//   statements may carry `comments` (leading), `trailing` (same-line comment) and `blankBefore`.

import { tokenize, LuaSyntaxError } from './lexer.js';
import { textToBinary } from './bytes.js';

const BINARY_PRIORITY = {
  'or': [1, 1], 'and': [2, 2],
  '<': [3, 3], '>': [3, 3], '<=': [3, 3], '>=': [3, 3], '~=': [3, 3], '==': [3, 3],
  '|': [4, 4], '~': [5, 5], '&': [6, 6], '<<': [7, 7], '>>': [7, 7],
  '..': [9, 8], '+': [10, 10], '-': [10, 10],
  '*': [11, 11], '/': [11, 11], '//': [11, 11], '%': [11, 11],
  '^': [14, 13],
};
const UNARY_PRIORITY = 12;
const COMPOUND_OPS = new Set(['+=', '-=', '*=', '/=', '//=', '%=', '^=', '..=']);
const BLOCK_END = new Set(['end', 'else', 'elseif', 'until']);

export function binaryPriority(op) { return BINARY_PRIORITY[op]; }
export { UNARY_PRIORITY };

class Parser {
  constructor(src, options) {
    this.src = src;
    this.opts = options;
    const { tokens } = tokenize(src);
    this.tokens = tokens;
    this.p = 0;
    this.features = new Set();
    this.depth = 0;
  }

  // ---- token helpers -------------------------------------------------------
  get tok() { return this.tokens[this.p]; }
  peek(k = 1) { return this.tokens[Math.min(this.p + k, this.tokens.length - 1)]; }
  next() { const t = this.tokens[this.p]; if (t.t !== 'eof') this.p++; return t; }

  is(v) { const t = this.tok; return (t.t === 'op' || t.t === 'keyword') && t.v === v; }
  isAt(k, v) { const t = this.peek(k); return (t.t === 'op' || t.t === 'keyword') && t.v === v; }
  accept(v) { if (this.is(v)) { this.next(); return true; } return false; }

  error(message, tok = this.tok) {
    throw new LuaSyntaxError(message, tok.start, tok.line, tok.col);
  }
  near(tok = this.tok) { return tok.t === 'eof' ? '<eof>' : `'${tok.t === 'string' || tok.t === 'number' ? tok.raw : tok.v}'`; }
  expect(v, what) {
    if (!this.is(v)) this.error(`'${v}' expected${what ? ` (${what})` : ''} near ${this.near()}`);
    return this.next();
  }
  expectName() {
    if (this.tok.t !== 'name') this.error(`name expected near ${this.near()}`);
    return this.next();
  }
  /** `expect(close)` that also reports the opener's line, as the reference Lua parser does. */
  expectMatch(close, open, line) {
    if (this.is(close)) return this.next();
    const where = line === this.tok.line ? '' : ` (to close '${open}' at line ${line})`;
    this.error(`'${close}' expected${where} near ${this.near()}`);
  }

  // ---- chunks and blocks ---------------------------------------------------
  parseChunk() {
    const body = this.parseBlock();
    if (this.tok.t !== 'eof') this.error(`'<eof>' expected near ${this.near()}`);
    return { type: 'Chunk', body, endComments: body.endComments || [], features: this.features };
  }

  /** Statements up to (not including) a block terminator. */
  parseBlock() {
    if (++this.depth > 200) this.error('chunk has too many syntax levels');
    const body = [];
    let prev = null;
    for (;;) {
      const t = this.tok;
      if (t.t === 'eof' || (t.t === 'keyword' && BLOCK_END.has(t.v))) break;
      if (t.t === 'op' && t.v === ';') { this.next(); continue; } // empty statement
      const isReturn = t.t === 'keyword' && t.v === 'return';
      const stmt = isReturn ? this.parseReturn() : this.parseStatement();
      const last = this.tokens[this.p - 1];
      stmt.line = t.line;
      stmt.pos = t.start;
      stmt.endPos = last.end;
      stmt.endLine = last.endLine;
      stmt.blankBefore = prev ? t.line - prev.endLine > 1 : false;
      this.attach(stmt, t, prev);
      body.push(stmt);
      prev = stmt;
      if (isReturn) break; // `return` must be the last statement of its block
    }
    // Comments in front of the terminator belong to the end of this block.
    const term = this.tok;
    if (term.comments) {
      const rest = this.collectComments(term, prev);
      if (rest.length) body.endComments = rest;
    }
    this.depth--;
    return body;
  }

  /** Split a token's leading comments into the previous statement's trailing comment and the rest. */
  collectComments(tok, prevStmt) {
    const list = tok.comments;
    if (!list) return [];
    const rest = [];
    for (const c of list) {
      if (prevStmt && !prevStmt.trailing && c.line === prevStmt.endLine && c.kind === 'line') {
        prevStmt.trailing = c;
      } else if (prevStmt && !prevStmt.trailing && c.line === prevStmt.endLine && c.endLine === c.line) {
        prevStmt.trailing = c;
      } else rest.push(c);
    }
    tok.comments = null;
    return rest;
  }

  attach(stmt, firstTok, prev) {
    if (!firstTok.comments) return;
    const rest = this.collectComments(firstTok, prev);
    if (rest.length) stmt.comments = rest;
  }

  // ---- statements ----------------------------------------------------------
  parseStatement() {
    const t = this.tok;
    if (t.t === 'keyword') {
      switch (t.v) {
        case 'if': return this.parseIf();
        case 'while': return this.parseWhile();
        case 'do': return this.parseDo();
        case 'for': return this.parseFor();
        case 'repeat': return this.parseRepeat();
        case 'function': return this.parseFunctionStatement();
        case 'local': return this.parseLocal();
        case 'break': this.next(); return { type: 'Break' };
        default: break;
      }
    }
    if (t.t === 'op' && t.v === '::') {
      this.next();
      const name = this.expectName().v;
      this.expect('::');
      this.features.add('label');
      return { type: 'Label', name };
    }
    if (t.t === 'op' && t.v === '@') { // Luau attribute: @native / @checked / @deprecated
      this.features.add('attribute');
      const attrs = [];
      while (this.is('@')) { this.next(); attrs.push(this.expectName().v); }
      const stmt = this.is('local') ? this.parseLocal() : this.parseFunctionStatement();
      stmt.attributes = attrs;
      return stmt;
    }
    if (t.t === 'name') {
      const n1 = this.peek();
      if (t.v === 'goto' && n1.t === 'name' && n1.line === t.line) {
        this.next();
        this.features.add('goto');
        return { type: 'Goto', label: this.next().v };
      }
      if (t.v === 'continue' && !(n1.t === 'op' && ['=', '.', ':', '(', '[', ',', '{'].includes(n1.v)) && n1.t !== 'string') {
        this.next();
        this.features.add('continue');
        return { type: 'Continue' };
      }
      if ((t.v === 'type' && n1.t === 'name') || (t.v === 'export' && n1.t === 'name' && n1.v === 'type')) {
        const isTypeDecl = t.v === 'export' || this.isAt(2, '=') || this.isAt(2, '<');
        if (isTypeDecl) return this.parseTypeAlias();
      }
    }
    return this.parseExpressionStatement();
  }

  parseTypeAlias() {
    const first = this.tok;
    const exported = first.v === 'export';
    if (exported) this.next();
    this.next(); // `type`
    this.expectName();
    if (this.is('<')) this.skipAngles();
    this.expect('=');
    this.skipType();
    this.features.add('type-annotation');
    return { type: 'TypeAlias', text: this.src.slice(first.start, this.tokens[this.p - 1].end), exported };
  }

  parseReturn() {
    this.next();
    const values = [];
    const t = this.tok;
    if (!(t.t === 'eof' || (t.t === 'keyword' && BLOCK_END.has(t.v)) || (t.t === 'op' && t.v === ';'))) {
      values.push(...this.parseExprList());
    }
    this.accept(';');
    return { type: 'Return', values };
  }

  parseIf() {
    const clauses = [];
    this.next();
    let cond = this.parseExpr();
    this.expect('then');
    clauses.push({ cond, body: this.parseBlock() });
    let orelse = null;
    for (;;) {
      if (this.is('elseif')) {
        this.next();
        cond = this.parseExpr();
        this.expect('then');
        clauses.push({ cond, body: this.parseBlock() });
      } else if (this.is('else')) {
        this.next();
        orelse = this.parseBlock();
        break;
      } else break;
    }
    this.expect('end');
    return { type: 'If', clauses, orelse };
  }

  parseWhile() {
    this.next();
    const cond = this.parseExpr();
    this.expect('do');
    const body = this.parseBlock();
    this.expect('end');
    return { type: 'While', cond, body };
  }

  parseDo() {
    this.next();
    const body = this.parseBlock();
    this.expect('end');
    return { type: 'Do', body };
  }

  parseRepeat() {
    this.next();
    const body = this.parseBlock();
    this.expect('until');
    const cond = this.parseExpr();
    return { type: 'Repeat', body, cond };
  }

  parseFor() {
    const forTok = this.next();
    const first = this.parseBindingName();
    if (this.is('=')) {
      this.next();
      const start = this.parseExpr();
      this.expect(',');
      const stop = this.parseExpr();
      const step = this.accept(',') ? this.parseExpr() : null;
      this.expect('do');
      const body = this.parseBlock();
      this.expectMatch('end', 'for', forTok.line);
      return { type: 'NumFor', id: first, start, stop, step, body };
    }
    const ids = [first];
    while (this.accept(',')) ids.push(this.parseBindingName());
    this.expect('in');
    const exprs = this.parseExprList();
    this.expect('do');
    const body = this.parseBlock();
    this.expectMatch('end', 'for', forTok.line);
    return { type: 'GenFor', ids, exprs, body };
  }

  /** A declared name with an optional Luau annotation (`x: number`). */
  parseBindingName() {
    const t = this.expectName();
    const id = { type: 'Id', name: t.v };
    if (this.is(':') ) {
      this.next();
      id.annotation = this.captureType();
      this.features.add('type-annotation');
    }
    return id;
  }

  parseFunctionStatement() {
    const fnTok = this.next();
    const first = this.expectName();
    let target = { type: 'Name', name: first.v, line: first.line };
    let method = null;
    while (this.is('.')) {
      this.next();
      const key = this.expectName();
      target = { type: 'Index', obj: target, key: { type: 'String', value: key.v, raw: null }, dot: true };
    }
    if (this.is(':')) {
      this.next();
      method = this.expectName().v;
    }
    const func = this.parseFunctionBody(fnTok, method !== null);
    return { type: 'Function', target, method, func };
  }

  parseLocal() {
    const localTok = this.next();
    if (this.is('function')) {
      this.next();
      const nameTok = this.expectName();
      const func = this.parseFunctionBody(localTok, false);
      return { type: 'LocalFunction', id: { type: 'Id', name: nameTok.v }, func };
    }
    const ids = [];
    do {
      const id = this.parseBindingName();
      if (this.is('<') && this.peek().t === 'name' && this.isAt(2, '>')) { // Lua 5.4 attribute
        this.next();
        id.attrib = this.next().v;
        this.next();
        this.features.add('attrib');
      }
      ids.push(id);
    } while (this.accept(','));
    const values = this.accept('=') ? this.parseExprList() : [];
    return { type: 'Local', ids, values };
  }

  parseExpressionStatement() {
    const startTok = this.tok;
    const expr = this.parseSuffixedExpr();
    const t = this.tok;
    if (t.t === 'op' && (t.v === '=' || t.v === ',')) {
      const targets = [expr];
      while (this.accept(',')) targets.push(this.parseSuffixedExpr());
      this.expect('=');
      const values = this.parseExprList();
      for (const tg of targets) {
        if (tg.type !== 'Name' && tg.type !== 'Index') this.error('syntax error (cannot assign to this expression)', startTok);
      }
      return { type: 'Assign', targets, values };
    }
    if (t.t === 'op' && COMPOUND_OPS.has(t.v)) {
      if (expr.type !== 'Name' && expr.type !== 'Index') this.error('syntax error', startTok);
      this.next();
      this.features.add('compound-assign');
      return { type: 'CompoundAssign', op: t.v.slice(0, -1), target: expr, value: this.parseExpr() };
    }
    if (expr.type !== 'Call' && expr.type !== 'MethodCall') {
      this.error(`syntax error near ${this.near()}`, t);
    }
    return { type: 'CallStmt', call: expr };
  }

  // ---- functions -----------------------------------------------------------
  parseFunctionBody(startTok, isMethod) {
    const params = [];
    let vararg = false;
    let generics = null;
    if (this.is('<')) { // Luau generic parameters
      const g = this.tok.start;
      this.skipAngles();
      generics = this.src.slice(g, this.tokens[this.p - 1].end);
      this.features.add('type-annotation');
    }
    const open = this.expect('(');
    if (!this.is(')')) {
      do {
        if (this.is('...')) {
          this.next();
          vararg = true;
          if (this.accept(':')) { vararg = { annotation: this.captureType() }; this.features.add('type-annotation'); }
          break;
        }
        params.push(this.parseBindingName());
      } while (this.accept(','));
    }
    this.expectMatch(')', '(', open.line);
    let returnType = null;
    if (this.is(':')) {
      this.next();
      returnType = this.captureType();
      this.features.add('type-annotation');
    }
    const body = this.parseBlock();
    this.expectMatch('end', 'function', startTok.line);
    return { type: 'Func', params, vararg, body, isMethod, generics, returnType, line: startTok.line };
  }

  // ---- expressions ---------------------------------------------------------
  parseExprList() {
    const list = [this.parseExpr()];
    while (this.accept(',')) list.push(this.parseExpr());
    return list;
  }

  parseExpr(limit = 0) {
    if (++this.depth > 200) this.error('expression too complex (nesting too deep)');
    let left;
    const t = this.tok;
    if ((t.t === 'keyword' && t.v === 'not') || (t.t === 'op' && (t.v === '-' || t.v === '#' || t.v === '~'))) {
      this.next();
      const arg = this.parseExpr(UNARY_PRIORITY);
      left = { type: 'Unary', op: t.v, arg, line: t.line };
      if (t.v === '~') this.features.add('bitops');
    } else {
      left = this.parseSimpleExpr();
    }
    for (;;) {
      const o = this.tok;
      if (!(o.t === 'op' || o.t === 'keyword')) break;
      const pr = BINARY_PRIORITY[o.v];
      if (!pr || pr[0] <= limit) break;
      this.next();
      const right = this.parseExpr(pr[1]);
      left = { type: 'Binary', op: o.v, left, right, line: o.line };
      if (o.v === '//') this.features.add('floordiv');
      else if (o.v === '&' || o.v === '|' || o.v === '<<' || o.v === '>>' || (o.v === '~')) this.features.add('bitops');
    }
    this.depth--;
    return left;
  }

  parseSimpleExpr() {
    const t = this.tok;
    let e;
    switch (t.t) {
      case 'number':
        this.next();
        e = { type: 'Number', value: t.v, raw: t.raw };
        if (/^0[bB]|_/.test(t.raw)) this.features.add('luau-number');
        break;
      case 'string':
        this.next();
        e = { type: 'String', value: t.v, raw: t.raw, long: t.long };
        break;
      case 'interp':
        this.next();
        e = this.buildInterp(t);
        break;
      case 'keyword':
        if (t.v === 'nil') { this.next(); e = { type: 'Nil' }; break; }
        if (t.v === 'true') { this.next(); e = { type: 'True' }; break; }
        if (t.v === 'false') { this.next(); e = { type: 'False' }; break; }
        if (t.v === 'function') { this.next(); e = this.parseFunctionBody(t, false); break; }
        if (t.v === 'if') { e = this.parseIfExpr(); break; }
        return this.parseSuffixedExpr();
      case 'op':
        if (t.v === '...') { this.next(); e = { type: 'Vararg' }; break; }
        if (t.v === '{') { e = this.parseTable(); break; }
        return this.parseSuffixedExpr();
      default:
        return this.parseSuffixedExpr();
    }
    // A literal can only be called or indexed through parentheses, so no suffixes here; but a
    // trailing type assertion applies to any simple expression.
    return this.maybeAssert(e);
  }

  /**
   * `::` after an expression is either a Luau type assertion (`x :: T`) or the start of a Lua 5.2 label (`::done::`) that
   * follows an expression statement. A label sits on its own line or is followed by the end of the block; a type is never
   * followed by `end`, `else`, `elseif`, `until` or the end of the file.
   */
  startsLabel() {
    if (!this.is('::') || this.peek().t !== 'name' || !this.isAt(2, '::')) return false;
    const before = this.tokens[this.p - 1];
    if (before && before.line < this.tok.line) return true;
    const after = this.peek(3);
    return after.t === 'eof' || (after.t === 'keyword' && BLOCK_END.has(after.v));
  }

  maybeAssert(e) {
    while (this.is('::') && !this.startsLabel()) {
      this.next();
      const text = this.captureType();
      this.features.add('type-assert');
      e = { type: 'TypeAssert', expr: e, text };
    }
    return e;
  }

  parseIfExpr() {
    this.next();
    const cond = this.parseExpr();
    this.expect('then');
    const then = this.parseExpr();
    let orelse;
    if (this.is('elseif')) orelse = this.parseIfExpr();
    else { this.expect('else'); orelse = this.parseExpr(); }
    this.features.add('if-expression');
    return { type: 'IfExpr', cond, then, orelse };
  }

  buildInterp(tok) {
    const parts = [];
    for (const part of tok.parts) {
      if ('text' in part) { parts.push(part.text); continue; }
      const sub = new Parser(part.source, this.opts);
      const expr = sub.parseExpr();
      if (sub.tok.t !== 'eof') sub.error(`unexpected token in interpolation near ${sub.near()}`);
      parts.push(expr);
    }
    this.features.add('interp-string');
    return { type: 'Interp', parts };
  }

  /** primaryexp { '.' Name | '[' exp ']' | ':' Name args | args } */
  parseSuffixedExpr() {
    const t = this.tok;
    let e;
    if (t.t === 'name') {
      this.next();
      e = { type: 'Name', name: t.v, line: t.line };
    } else if (t.t === 'op' && t.v === '(') {
      this.next();
      const inner = this.parseExpr();
      this.expectMatch(')', '(', t.line);
      e = { type: 'Paren', expr: inner };
    } else {
      this.error(`unexpected symbol near ${this.near()}`);
    }
    for (;;) {
      const s = this.tok;
      if (s.t === 'op') {
        if (s.v === '.') {
          this.next();
          const key = this.expectName();
          e = { type: 'Index', obj: e, key: { type: 'String', value: key.v, raw: null }, dot: true, line: s.line };
          continue;
        }
        if (s.v === '[') {
          // `a[[x]]` is a long string argument, not an index; the lexer already merged it.
          this.next();
          const key = this.parseExpr();
          this.expectMatch(']', '[', s.line);
          e = { type: 'Index', obj: e, key, dot: false, line: s.line };
          continue;
        }
        if (s.v === ':') {
          // not a method call if followed by something that is not `Name args` (e.g. a Luau cast `::` is its own token)
          this.next();
          const name = this.expectName();
          const { args, sugar } = this.parseArgs();
          e = { type: 'MethodCall', obj: e, name: name.v, args, sugar, line: s.line };
          continue;
        }
        if (s.v === '(' || s.v === '{') {
          const { args, sugar } = this.parseArgs();
          e = { type: 'Call', fn: e, args, sugar, line: s.line };
          continue;
        }
      } else if (s.t === 'string') {
        const { args, sugar } = this.parseArgs();
        e = { type: 'Call', fn: e, args, sugar, line: s.line };
        continue;
      }
      break;
    }
    return this.maybeAssert(e);
  }

  parseArgs() {
    const t = this.tok;
    if (t.t === 'string') {
      this.next();
      return { args: [{ type: 'String', value: t.v, raw: t.raw, long: t.long }], sugar: 'string' };
    }
    if (t.t === 'op' && t.v === '{') return { args: [this.parseTable()], sugar: 'table' };
    if (t.t === 'op' && t.v === '(') {
      this.next();
      let args = [];
      if (!this.is(')')) args = this.parseExprList();
      this.expectMatch(')', '(', t.line);
      return { args, sugar: null };
    }
    return this.error(`function arguments expected near ${this.near()}`);
  }

  parseTable() {
    const open = this.expect('{');
    const fields = [];
    while (!this.is('}')) {
      const t = this.tok;
      if (t.t === 'name' && this.isAt(1, '=') ) {
        this.next();
        this.next();
        fields.push({ kind: 'named', key: t.v, value: this.parseExpr() });
      } else if (t.t === 'op' && t.v === '[') {
        this.next();
        const key = this.parseExpr();
        this.expect(']');
        this.expect('=');
        fields.push({ kind: 'keyed', key, value: this.parseExpr() });
      } else {
        fields.push({ kind: 'item', value: this.parseExpr() });
      }
      if (!this.accept(',') && !this.accept(';')) break;
    }
    this.expectMatch('}', '{', open.line);
    return { type: 'Table', fields, line: open.line };
  }

  // ---- Luau types (captured as text, not modelled) --------------------------
  captureType() {
    const start = this.tok.start;
    this.skipType();
    return this.src.slice(start, this.tokens[this.p - 1].end).replace(/\s*\n\s*/g, ' ');
  }

  skipAngles() {
    this.expect('<');
    let depth = 1;
    while (depth > 0) {
      const t = this.next();
      if (t.t === 'eof') this.error('unfinished generic list');
      if (t.t === 'op') {
        if (t.v === '<') depth++;
        else if (t.v === '>') depth--;
        else if (t.v === '>>') depth -= 2;
        else if (t.v === '<<') depth += 2;
      }
    }
  }

  skipBalanced(open, close) {
    this.expect(open);
    let depth = 1;
    while (depth > 0) {
      const t = this.next();
      if (t.t === 'eof') this.error(`unfinished '${open}'`);
      if (t.t === 'op' && t.v === open) depth++;
      else if (t.t === 'op' && t.v === close) depth--;
    }
  }

  skipSimpleType() {
    const t = this.tok;
    if (t.t === 'op' && t.v === '(') {
      this.skipBalanced('(', ')');
      if (this.accept('->')) this.skipType();
    } else if (t.t === 'op' && t.v === '{') {
      this.skipBalanced('{', '}');
    } else if (t.t === 'op' && t.v === '<') { // generic function type
      this.skipAngles();
      this.skipSimpleType();
    } else if (t.t === 'string') {
      this.next();
    } else if (t.t === 'keyword' && (t.v === 'nil' || t.v === 'true' || t.v === 'false')) {
      this.next();
    } else if (t.t === 'name') {
      this.next();
      if (t.v === 'typeof' && this.is('(')) this.skipBalanced('(', ')');
      else {
        while (this.is('.') && this.peek().t === 'name') { this.next(); this.next(); }
        if (this.is('<')) this.skipAngles();
      }
    } else {
      this.error(`type expected near ${this.near()}`);
    }
    if (this.is('...')) this.next(); // variadic pack
    while (this.is('?')) this.next();
  }

  skipType() {
    this.skipSimpleType();
    while (this.is('|') || this.is('&')) {
      this.next();
      this.skipSimpleType();
    }
  }
}

/**
 * Parse Lua/Luau source.
 * @param {string} src binary string (use textToBinary for real text)
 * @returns {{type:'Chunk', body:Array, features:Set<string>}}
 */
export function parse(src, options = {}) {
  return new Parser(src, options).parseChunk();
}

export function parseText(text, options = {}) {
  return parse(textToBinary(text), options);
}

export { LuaSyntaxError };
