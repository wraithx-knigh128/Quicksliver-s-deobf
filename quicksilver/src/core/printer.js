// AST -> source. Used for beautifying, and as the last stage of every recovery pass.
//
// Output is a binary string (see bytes.js). The printer does not trust its input to be well-formed
// Lua: names that are not identifiers are emitted in bracket form, operands are parenthesised by
// priority, and a statement that starts with '(' gets a protective ';' on the statement before it so
// the two can never be merged into one call.

import { binaryPriority, UNARY_PRIORITY } from './parser.js';
import { KEYWORDS } from './lexer.js';
import { utf8SequenceLength } from './bytes.js';

const DEFAULTS = {
  indent: '  ',
  width: 100,
  strings: 'preserve',   // 'preserve' keeps original literal text; 'normalize' re-quotes the decoded value
  numbers: 'preserve',
  comments: true,
  blankLines: 'smart',   // 'preserve' | 'smart' | 'none'
};

const IDENT_RE = /^[A-Za-z_][A-Za-z0-9_]*$/;
const RESERVED = new Set([...KEYWORDS, 'goto', 'continue']);
export const isIdentifier = (s) => IDENT_RE.test(s) && !RESERVED.has(s);

const ATOMS = new Set(['Name', 'Index', 'Call', 'MethodCall', 'Paren']);
const ATOM_PRIORITY = 100;

// ---- literals ------------------------------------------------------------

export function formatNumber(value) {
  if (Number.isNaN(value)) return '(0/0)';
  if (value === Infinity) return 'math.huge';
  if (value === -Infinity) return '-math.huge';
  if (Object.is(value, -0)) return '-0';
  if (Number.isInteger(value) && Math.abs(value) < 1e15) return String(value);
  return String(value).replace('e+', 'e');
}

/** Quote a binary string as a Lua literal that reads back as exactly the same bytes. */
export function quoteString(bin) {
  let newlines = 0;
  let plain = true;
  for (let i = 0; i < bin.length; i++) {
    const c = bin.charCodeAt(i);
    if (c === 10) newlines++;
    else if ((c < 32 && c !== 9) || c === 127) plain = false;
    else if (c >= 128) {
      const len = utf8SequenceLength(bin, i);
      if (!len) plain = false; else i += len - 1;
    }
  }
  // Multi-line prose reads better as a long bracket, if nothing in it needs escaping.
  if (plain && newlines >= 2 && bin.length > 40 && !bin.endsWith(']')) {
    let level = 0;
    while (bin.includes(']' + '='.repeat(level) + ']')) level++;
    const eq = '='.repeat(level);
    return `[${eq}[${bin[0] === '\n' ? '\n' : ''}${bin}]${eq}]`;
  }

  let dq = 0;
  let sq = 0;
  for (let i = 0; i < bin.length; i++) {
    const c = bin.charCodeAt(i);
    if (c === 34) dq++; else if (c === 39) sq++;
  }
  const quote = dq > sq ? "'" : '"';
  let out = quote;
  for (let i = 0; i < bin.length; i++) {
    const c = bin.charCodeAt(i);
    const ch = bin[i];
    if (ch === '\\') out += '\\\\';
    else if (ch === quote) out += '\\' + quote;
    else if (c === 10) out += '\\n';
    else if (c === 13) out += '\\r';
    else if (c === 9) out += '\\t';
    else if (c >= 32 && c < 127) out += ch;
    else if (c >= 128 && utf8SequenceLength(bin, i) > 1) {
      const len = utf8SequenceLength(bin, i);
      out += bin.slice(i, i + len);
      i += len - 1;
    } else {
      const nextIsDigit = bin.charCodeAt(i + 1) >= 48 && bin.charCodeAt(i + 1) <= 57;
      out += '\\' + (nextIsDigit ? String(c).padStart(3, '0') : String(c));
    }
  }
  return out + quote;
}

function commentText(c) {
  if (c.kind === 'line') return '--' + c.text;
  const eq = '='.repeat(c.level || 0);
  return `--[${eq}[${c.text}]${eq}]`;
}

// ---- printer ---------------------------------------------------------------

class Printer {
  constructor(options) {
    this.o = { ...DEFAULTS, ...options };
  }

  pad(level) { return this.o.indent.repeat(level); }
  cols(level) { return level * this.o.indent.length; }

  // -- blocks and statements --

  /** Statements of one block, each already indented, joined by newlines. */
  block(stmts, level) {
    const cores = stmts.map((s) => this.stmtCore(s, level));
    const lines = [];
    stmts.forEach((s, i) => {
      const multi = cores[i].includes('\n');
      const prevMulti = i > 0 && cores[i - 1].includes('\n');
      let text = cores[i];
      // A line starting with '(' would be read as a call of the previous statement.
      if (i + 1 < stmts.length && cores[i + 1].startsWith('(')) text += ';';
      if (s.trailing && this.o.comments) text += ' ' + commentText(s.trailing);

      let blank = false;
      if (i > 0) {
        if (this.o.blankLines === 'preserve') blank = !!s.blankBefore;
        else if (this.o.blankLines === 'smart') blank = !!s.blankBefore || multi || prevMulti;
      }
      if (blank) lines.push('');
      if (s.comments && this.o.comments) {
        for (const c of s.comments) lines.push(this.pad(level) + commentText(c));
      }
      lines.push(this.pad(level) + text);
    });
    if (stmts.endComments && this.o.comments) {
      for (const c of stmts.endComments) lines.push(this.pad(level) + commentText(c));
    }
    return lines.join('\n');
  }

  /** Body of a compound statement, including the closing indentation, or ' ' if empty. */
  body(stmts, level) {
    const hasContent = stmts.length > 0 || (stmts.endComments && stmts.endComments.length && this.o.comments);
    if (!hasContent) return ' ';
    return '\n' + this.block(stmts, level + 1) + '\n' + this.pad(level);
  }

  attrs(s) {
    return s.attributes ? s.attributes.map((a) => '@' + a).join(' ') + ' ' : '';
  }

  stmtCore(s, level) {
    const base = this.cols(level);
    switch (s.type) {
      case 'Local': {
        const head = `${this.attrs(s)}local ${s.ids.map((id) => this.id(id)).join(', ')}`;
        if (!s.values.length) return head;
        return `${head} = ${this.exprList(s.values, level, base + head.length + 3)}`;
      }
      case 'LocalFunction':
        return `${this.attrs(s)}local function ${s.id.name}${this.funcRest(s.func, level)}`;
      case 'Function': {
        let name = this.expr(s.target, level);
        if (s.method) name += ':' + s.method;
        return `${this.attrs(s)}function ${name}${this.funcRest(s.func, level)}`;
      }
      case 'Assign': {
        const lhs = s.targets.map((t) => this.expr(t, level)).join(', ');
        return `${lhs} = ${this.exprList(s.values, level, base + lhs.length + 3)}`;
      }
      case 'CompoundAssign': {
        const lhs = `${this.expr(s.target, level)} ${s.op}= `;
        return lhs + this.expr(s.value, level, base + lhs.length);
      }
      case 'CallStmt':
        return this.expr(s.call, level, base);
      case 'Do':
        return 'do' + this.body(s.body, level) + 'end';
      case 'While':
        return `while ${this.expr(s.cond, level, base + 6)} do${this.body(s.body, level)}end`;
      case 'Repeat':
        return `repeat${this.body(s.body, level)}until ${this.expr(s.cond, level, base + 6)}`;
      case 'If': {
        let out = '';
        s.clauses.forEach((c, i) => {
          const kw = i === 0 ? 'if' : 'elseif';
          out += `${kw} ${this.expr(c.cond, level, base + kw.length + 1)} then${this.body(c.body, level)}`;
        });
        const hasElse = s.orelse && (s.orelse.length || (s.orelse.endComments && s.orelse.endComments.length));
        if (hasElse) out += `else${this.body(s.orelse, level)}`;
        return out + 'end';
      }
      case 'NumFor': {
        const parts = [this.expr(s.start, level), this.expr(s.stop, level)];
        if (s.step) parts.push(this.expr(s.step, level));
        return `for ${this.id(s.id)} = ${parts.join(', ')} do${this.body(s.body, level)}end`;
      }
      case 'GenFor': {
        const head = `for ${s.ids.map((id) => this.id(id)).join(', ')} in `;
        return `${head}${this.exprList(s.exprs, level, base + head.length)} do${this.body(s.body, level)}end`;
      }
      case 'Return':
        return s.values.length ? 'return ' + this.exprList(s.values, level, base + 7) : 'return';
      case 'Break': return 'break';
      case 'Continue': return 'continue';
      case 'Goto': return 'goto ' + s.label;
      case 'Label': return '::' + s.name + '::';
      case 'TypeAlias': return s.text;
      default:
        throw new Error('printer: unknown statement type ' + s.type);
    }
  }

  id(id) {
    let out = id.name;
    if (id.attrib) out += ` <${id.attrib}>`;
    if (id.annotation) out += ': ' + id.annotation;
    return out;
  }

  funcRest(f, level) {
    const params = f.params.map((id) => this.id(id));
    if (f.vararg) params.push(typeof f.vararg === 'object' ? `...: ${f.vararg.annotation}` : '...');
    const head = `${f.generics || ''}(${params.join(', ')})${f.returnType ? ': ' + f.returnType : ''}`;
    return head + this.body(f.body, level) + 'end';
  }

  // -- expressions --

  exprList(list, level, col = 0) {
    return list.map((e) => this.expr(e, level, col)).join(', ');
  }

  /** Binding strength of the outermost operator of `e` (atoms bind tightest). */
  prec(e) {
    switch (e.type) {
      case 'Binary': return binaryPriority(e.op)[0];
      case 'Unary': return UNARY_PRIORITY;
      case 'IfExpr': return -1;
      case 'Number': return e.value < 0 || Object.is(e.value, -0) ? UNARY_PRIORITY : ATOM_PRIORITY;
      case 'TypeAssert': return ATOM_PRIORITY;
      default: return ATOM_PRIORITY;
    }
  }

  /** Prefix of a call or index must be an atom; anything else is parenthesised. */
  prefix(e, level, col) {
    if (ATOMS.has(e.type)) return this.expr(e, level, col);
    return '(' + this.expr(e, level, col + 1) + ')';
  }

  expr(e, level, col = 0) {
    switch (e.type) {
      case 'Nil': return 'nil';
      case 'True': return 'true';
      case 'False': return 'false';
      case 'Vararg': return '...';
      case 'Number': return this.o.numbers === 'preserve' && e.raw ? e.raw : formatNumber(e.value);
      case 'String': return this.o.strings === 'preserve' && e.raw ? e.raw : quoteString(e.value);
      case 'Name': return e.name;
      case 'Paren': return '(' + this.expr(e.expr, level, col + 1) + ')';
      case 'Func': return 'function' + this.funcRest(e, level);
      case 'Table': return this.table(e, level, col);
      case 'Index': {
        const obj = this.prefix(e.obj, level, col);
        const k = e.key;
        const bareName = k.type === 'String' && isIdentifier(k.value);
        if (bareName && (e.dot !== false || this.o.strings === 'normalize')) return `${obj}.${k.value}`;
        return `${obj}[${this.expr(k, level, col + obj.length + 1)}]`;
      }
      case 'Call': {
        const fn = this.prefix(e.fn, level, col);
        return fn + this.callArgs(e, fn.length, level, col);
      }
      case 'MethodCall': {
        const head = `${this.prefix(e.obj, level, col)}:${e.name}`;
        return head + this.callArgs(e, head.length, level, col);
      }
      case 'Unary': {
        const op = e.op === 'not' ? 'not ' : e.op;
        let inner = this.expr(e.arg, level, col + op.length);
        if (this.prec(e.arg) < UNARY_PRIORITY) inner = '(' + inner + ')';
        if (op === '-' && inner[0] === '-') return '- ' + inner; // never emit "--" (a comment)
        return op + inner;
      }
      case 'Binary': return this.binary(e, level, col);
      case 'IfExpr': {
        let out = `if ${this.expr(e.cond, level, col)} then ${this.expr(e.then, level, col)} `;
        let tail = e.orelse;
        while (tail.type === 'IfExpr') {
          out += `elseif ${this.expr(tail.cond, level, col)} then ${this.expr(tail.then, level, col)} `;
          tail = tail.orelse;
        }
        return out + `else ${this.expr(tail, level, col)}`;
      }
      case 'TypeAssert': {
        const wrapped = this.prec(e.expr) < ATOM_PRIORITY;
        const inner = this.expr(e.expr, level, col);
        return `${wrapped ? '(' + inner + ')' : inner} :: ${e.text}`;
      }
      case 'Interp': {
        let out = '`';
        for (const part of e.parts) {
          if (typeof part === 'string') out += part.replace(/[`{\\]/g, '\\$&').replace(/\n/g, '\\n');
          else out += '{' + this.expr(part, level, col) + '}';
        }
        return out + '`';
      }
      default:
        throw new Error('printer: unknown expression type ' + e.type);
    }
  }

  binary(e, level, col) {
    const [l, r] = binaryPriority(e.op);
    const leftAssoc = l === r;

    // Flatten a run of the same operator so that a long chain can be wrapped at its operators.
    // `..` and `^` are right associative (the run hangs off the right child); the rest hang off the left.
    const chain = [];
    if (leftAssoc) {
      let node = e;
      const rights = [];
      while (node.type === 'Binary' && node.op === e.op) { rights.push(node.right); node = node.left; }
      chain.push(node, ...rights.reverse());
    } else {
      let node = e;
      while (node.type === 'Binary' && node.op === e.op) { chain.push(node.left); node = node.right; }
      chain.push(node);
    }

    const parts = chain.map((node, idx) => {
      const isRightChild = leftAssoc ? idx > 0 : idx === chain.length - 1;
      const p = this.prec(node);
      // A unary operator on the right never needs parentheses: `a ^ -b`, `a - -b`.
      const wrap = isRightChild ? node.type !== 'Unary' && p <= r : p < l || (p === l && !leftAssoc);
      const text = this.expr(node, level, col);
      return wrap ? '(' + text + ')' : text;
    });

    const flat = parts.join(` ${e.op} `);
    if (!flat.includes('\n') && col + flat.length <= this.o.width) return flat;
    if (parts.length > 2 && !parts.some((x) => x.includes('\n'))) {
      return parts.join(`\n${this.pad(level + 1)}${e.op} `);
    }
    return flat;
  }

  callArgs(e, headLen, level, col) {
    const args = e.args;
    if (args.length === 0) return '()';
    if (e.sugar === 'string' && this.o.strings === 'preserve' && args.length === 1 && args[0].type === 'String') {
      return ' ' + this.expr(args[0], level);
    }
    if (e.sugar === 'table' && args.length === 1 && args[0].type === 'Table') {
      return this.expr(args[0], level, col + headLen);
    }
    const rendered = args.map((a) => this.expr(a, level, col + headLen + 1));
    const flat = '(' + rendered.join(', ') + ')';
    const anyMulti = rendered.some((r) => r.includes('\n'));
    if (!anyMulti) {
      if (col + headLen + flat.length <= this.o.width) return flat;
    } else {
      // Hug style, f(a, b, function() ... end): fine while only trailing arguments span lines.
      const firstMulti = rendered.findIndex((r) => r.includes('\n'));
      const lead = rendered.slice(0, firstMulti).join(', ');
      if (col + headLen + lead.length < this.o.width) return flat;
    }
    const pad = this.pad(level + 1);
    const inner = args.map((a) => pad + this.expr(a, level + 1, pad.length));
    return '(\n' + inner.join(',\n') + '\n' + this.pad(level) + ')';
  }

  tableItem(f, level, col) {
    if (f.kind === 'item') return this.expr(f.value, level, col);
    if (f.kind === 'named') {
      const key = isIdentifier(f.key) ? f.key : `[${quoteString(f.key)}]`;
      return `${key} = ${this.expr(f.value, level, col)}`;
    }
    if (f.key.type === 'String' && isIdentifier(f.key.value) && this.o.strings === 'normalize') {
      return `${f.key.value} = ${this.expr(f.value, level, col)}`;
    }
    return `[${this.expr(f.key, level, col)}] = ${this.expr(f.value, level, col)}`;
  }

  table(e, level, col) {
    if (e.fields.length === 0) return '{}';
    const items = e.fields.map((f) => this.tableItem(f, level, col + 2));
    const flat = '{ ' + items.join(', ') + ' }';
    if (!flat.includes('\n') && col + flat.length <= this.o.width) return flat;

    const pad = this.pad(level + 1);
    const literal = (f) => f.kind === 'item' && ['Number', 'String', 'True', 'False', 'Nil'].includes(f.value.type);
    if (e.fields.every(literal) && !items.some((x) => x.includes('\n'))) {
      // A long literal array is packed several elements per line.
      const lines = [];
      let line = '';
      for (const it of items) {
        const piece = it + ',';
        if (line && pad.length + line.length + 1 + piece.length > this.o.width) { lines.push(pad + line); line = piece; }
        else line = line ? line + ' ' + piece : piece;
      }
      if (line) lines.push(pad + line);
      return '{\n' + lines.join('\n') + '\n' + this.pad(level) + '}';
    }
    const inner = e.fields.map((f) => pad + this.tableItem(f, level + 1, pad.length));
    return '{\n' + inner.join(',\n') + ',\n' + this.pad(level) + '}';
  }
}

/**
 * @param {object} ast Chunk node
 * @param {object} [options] see DEFAULTS
 * @returns {string} binary string, newline-terminated
 */
export function print(ast, options = {}) {
  const pr = new Printer(options);
  let out = pr.block(ast.body, 0);
  if (!ast.body.endComments && ast.endComments && ast.endComments.length && pr.o.comments) {
    out += (out ? '\n' : '') + ast.endComments.map(commentText).join('\n');
  }
  return out.replace(/^\n+/, '') + '\n';
}

export function printExpression(expr, options = {}) {
  return new Printer(options).expr(expr, 0, 0);
}
