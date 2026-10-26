// What the lifter knows about the interpreter's runtime, so that the partial evaluator can read its handlers as a program instead of as data
// flow: which names stand for the register file, the open-upvalue cache, the argument table; which cells of the interpreter are
// `string.byte`, `table.move` and the rest; what the VM object's helper methods do. Everything it assumes is in the profile, which was read off
// the script's own code; what it is told about a value here is only ever used to fold operations on it, never to run anything.

import { Table, Multi, UNKNOWN, isScalar, lit } from '../block-pe.js';
import { structuralKey, walk } from '../../core/walk.js';

export class Sym { constructor(name) { this.name = name; } }
class Packed { constructor(items, open) { this.items = items; this.open = open; } }
class PackList { constructor(items, open) { this.items = items; this.open = open; } }
class ArrObj { constructor() { this.node = { type: 'Table', fields: [] }; this.n = 0; } }
class Cap { constructor(reg) { this.reg = reg; } }
class UpRef { constructor(idx) { this.idx = idx; } }
class UpPart { constructor(idx, part) { this.idx = idx; this.part = part; } }
class Iter { constructor(s, pos) { this.s = s; this.pos = pos; } }
const name = (n) => ({ type: 'Name', name: n });
const call = (f, args) => ({ type: 'Call', fn: name(f), args, sugar: null });
const regName = (k) => (k < 0 ? `r_${-k}` : `r${k}`);
const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;
const KEYWORDS = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while']);
const u32 = (x) => x >>> 0;
const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const single = (r) => (r.multi ? r.multi.items[0] ?? { type: 'Nil' } : r.expr);

const effectful = (e) => { let hit = false; walk(e, (n) => { if (n.type === 'Call' || n.type === 'MethodCall' || n.type === 'Func' || n.type === 'Vararg') hit = true; }); return hit; };
const tableOf = (items) => ({ type: 'Table', fields: items.map((x) => ({ kind: 'item', value: x })) });
const packExpr = (items, open) => (open && items.some(effectful) ? { type: 'Call', fn: { type: 'Index', obj: name('table'), key: lit('pack'), dot: true }, args: items, sugar: null } : tableOf(items));
const tableUnpack = () => ({ type: 'Index', obj: name('table'), key: lit('unpack'), dot: true });
/** `pack(table.unpack(held))` where `held` is a pack the model made: the same pack again, so name it instead of copying it. */
function packAlias(its, ctx) {
  if (its.length !== 1) return null;
  const c = strip(its[0]);
  if (c.type !== 'Call' || strip(c.fn).type !== 'Index' || strip(c.fn).key.value !== 'unpack' || c.args.length !== 1 || strip(c.args[0]).type !== 'Name') return null;
  const v = ctx.env.get(strip(c.args[0]).name);
  return v instanceof PackList || v instanceof Packed ? { expr: c.args[0], val: v } : null;
}

/** Names of the helpers the profile found on the VM object, as the lifter writes them. */
export const helperName = (profile, member) => profile.helpers.get(member)
  || (profile.crypto.sha256 === member ? 'vm_sha256' : profile.crypto.chacha === member ? 'vm_chacha20' : `vm_${member}`);

export function makeModel(profile) {
  const opField = profile.head.opField;
  const layoutFields = new Map(Object.entries(profile.layouts).map(([cls, fields]) => [Number(cls), new Set(fields.map(([k]) => k))]));
  /** a field of the instruction row that this instruction's class does not store: the interpreter keeps its per-instruction cache there */
  const isCacheField = (row, field) => {
    const cls = profile.opMap[row.get(opField)];
    const own = layoutFields.get(cls);
    return !!own && !own.has(field) && profile.fieldIds.includes(field);
  };
  const model = {
    toExpr(v) {
      if (v instanceof Sym) return name(v.name);
      if (v instanceof Cap) return call('ref', [name(regName(v.reg))]);
      if (v instanceof UpRef) return call('upref', [lit(v.idx)]);
      if (v instanceof ArrObj) return v.node;
      // a pack that holds a call is written out once, where it is made; reading it back by name must not run the call again
      if (v instanceof Packed || v instanceof PackList) return v.items.some(effectful) ? null : tableOf(v.items);
      return null;
    },
    alive: () => false,
    keyOf(v) {
      if (v instanceof Sym) return `S:${v.name}`;
      if (v instanceof Cap) return `C:${v.reg}`;
      if (v instanceof UpRef) return `U:${v.idx}`;
      if (v instanceof UpPart) return `P:${v.idx}.${v.part}`;
      if (v instanceof Iter) return `I:${JSON.stringify(v.s)}@${v.pos}`;
      if (v instanceof Packed || v instanceof PackList) return `K:${v.open ? 'o' : 'c'}:${v.items.map((x) => structuralKey(x)).join(';')}`;
      return null;
    },
    index(o, k, node, ctx) {
      const ov = o.val;
      const kv = k.val;
      if (ov instanceof Sym) {
        switch (ov.name) {
          case 'M': if (typeof kv === 'number') { const n = regName(kv); if (ctx.env.has(n)) { const v = ctx.env.get(n); return { expr: isScalar(v) ? lit(v) : name(n), val: v }; } return { expr: name(n), val: UNKNOWN }; } break;
          case 'ENV': if (typeof kv === 'string') return { expr: IDENT.test(kv) && !KEYWORDS.has(kv) ? name(kv) : { type: 'Index', obj: name('_ENV'), key: lit(kv), dot: false }, val: UNKNOWN }; break;
          case 'UPVALS': if (typeof kv === 'number') return { expr: call('upref', [lit(kv)]), val: new UpRef(kv) }; break;
          case 'Ib': if (typeof kv === 'number') return { expr: call('ref', [name(regName(kv))]), val: new Cap(kv) }; break;
          default: break;
        }
      }
      if ((ov instanceof PackList || ov instanceof Packed) && kv === 'n' && !ov.open) return { expr: lit(ov.items.length), val: ov.items.length };
      if (ov instanceof UpRef && (kv === 1 || kv === 2)) return { expr: node, val: new UpPart(ov.idx, kv) };
      if (ov instanceof UpPart && ov.part === 2 && kv instanceof UpPart && kv.part === 1 && kv.idx === ov.idx) return { expr: name(`up${ov.idx}`), val: UNKNOWN };
      if (ov instanceof ArrObj && typeof kv === 'number') { const f = ov.node.fields[kv - 1]; return f ? { expr: f.value, val: UNKNOWN } : { expr: { type: 'Nil' }, val: null }; }
      return null;
    },
    store(o, k, r, node, ctx) {
      const ov = o.val;
      const kv = k.val;
      if (ov instanceof Sym && ov.name === 'M' && typeof kv === 'number') {
        const n = regName(kv);
        ctx.emit({ type: 'Assign', targets: [name(n)], values: [single(r)] });
        ctx.invalidate(n);
        if (r.val !== UNKNOWN) ctx.env.set(n, r.val); else ctx.env.delete(n);
        return true;
      }
      if (ov instanceof UpPart && ov.part === 2 && kv instanceof UpPart && kv.part === 1) { ctx.emit({ type: 'Assign', targets: [name(`up${ov.idx}`)], values: [single(r)] }); return true; }
      if (ov instanceof Sym && ov.name === 'ENV' && typeof kv === 'string') {
        ctx.emit({ type: 'Assign', targets: [IDENT.test(kv) && !KEYWORDS.has(kv) ? { ...name(kv), global: true } : { type: 'Index', obj: name('_ENV'), key: lit(kv), dot: false }], values: [single(r)] });
        return true;
      }
      if (ov instanceof Sym && ov.name === 'Ib') return true; // the cache of open upvalues: not part of the program
      if (ov instanceof Table && typeof kv === 'number' && isCacheField(ov, kv)) return true; // the interpreter's own cache, held in the instruction's row
      if (ov instanceof ArrObj && typeof kv === 'number') {
        // a list under construction is shared by reference (a closure may already hold it): fill the one table expression in place
        while (ov.node.fields.length < kv) ov.node.fields.push({ kind: 'item', value: { type: 'Nil' } });
        ov.node.fields[kv - 1] = { kind: 'item', value: single(r) };
        return true;
      }
      return false;
    },
    call(f, args, node, ctx) {
      const fv = f.val;
      const val = (i) => (args[i] ? args[i].val : null);
      if (fv instanceof Iter) {
        const fn = strip(node.fn);
        const ch = fv.pos < fv.s.length ? fv.s[fv.pos] : null;
        if (fn.type === 'Name') ctx.env.set(fn.name, new Iter(fv.s, fv.pos + 1));
        return { expr: lit(ch), val: ch };
      }
      if (!(fv instanceof Sym)) return null;
      const items = () => args.map((a) => a.expr);
      const lastOpen = () => !!(args.length && args[args.length - 1].open);
      switch (fv.name) {
        case 'RANGE': {
          const a = val(1), b = val(2);
          if (!(val(0) instanceof Sym && val(0).name === 'M' && typeof a === 'number' && typeof b === 'number')) return null;
          const regs = []; for (let i = a; i <= b; i++) regs.push(name(regName(i)));
          return { expr: regs[0] || { type: 'Nil' }, val: UNKNOWN, multi: new Multi(regs, false) };
        }
        case 'pack': { const al = packAlias(items(), ctx); if (al) return { expr: al.expr, val: al.val }; const p = new Packed(items(), lastOpen()); return { expr: packExpr(p.items, p.open), val: p }; }
        case 'unpack': {
          const p = val(0);
          if (!(p instanceof Packed)) return null;
          // held in a name: read it back from there; made on the spot: its items are used directly
          if (strip(args[0].expr).type === 'Name' && p.items.some(effectful)) { const c = { type: 'Call', fn: tableUnpack(), args: [args[0].expr], sugar: null }; return { expr: c, val: UNKNOWN, multi: new Multi([c], true) }; }
          return { expr: p.items[0] || { type: 'Nil' }, val: UNKNOWN, multi: new Multi(p.items, p.open) };
        }
        case 'PACKN': {
          // returns the list and how many values went into it
          const al = packAlias(items(), ctx);
          if (al) { const m = new Multi([al.expr, al.val.open ? { type: 'PackCount' } : lit(al.val.items.length)], false); m.vals = [al.val, al.val.open ? UNKNOWN : al.val.items.length]; return { expr: al.expr, val: al.val, multi: m }; }
          const p = new PackList(items(), lastOpen());
          const list = packExpr(p.items, p.open);
          const count = p.open ? { type: 'PackCount' } : lit(p.items.length);
          const multi = new Multi([list, count], false);
          multi.vals = [p, p.open ? UNKNOWN : p.items.length];
          return { expr: list, val: p, multi };
        }
        case 'table_create': { const a = new ArrObj(); return { expr: a.node, val: a }; }
        case 'table_move': {
          const src = val(0), from = val(1), to = val(2), dst = val(3), into = val(4);
          if (!((src instanceof PackList || src instanceof Packed) && from === 1 && typeof dst === 'number' && into instanceof Sym && into.name === 'M')) return null;
          const held = strip(args[0].expr).type === 'Name' && src.items.some(effectful);
          // the number of values moved: given, or all of them when the pack's own count is known
          const n = typeof to === 'number' ? to : null;
          if (n === null) return null;
          if (n <= 0) return { skip: true, expr: null, val: UNKNOWN };
          const targets = []; for (let i = 0; i < n; i++) targets.push(name(regName(dst + i)));
          let values;
          if (held) values = [{ type: 'Call', fn: tableUnpack(), args: [args[0].expr], sugar: null }];
          else if (src.items.length >= n && !(src.open && src.items.length === n && n > 1)) values = src.items.slice(0, n);
          else values = src.items;
          ctx.emit({ type: 'Assign', targets, values });
          for (const t of targets) { ctx.invalidate(t.name); ctx.env.delete(t.name); }
          return { skip: true, expr: null, val: UNKNOWN };
        }
        case 'type': { const v = val(0); if (v === UNKNOWN || !isScalar(v)) return null; const t = v === null ? 'nil' : typeof v === 'boolean' ? 'boolean' : typeof v; return { expr: lit(t), val: t }; }
        case 'tonumber': { const v = val(0); if (typeof v === 'number') return { expr: lit(v), val: v }; return null; }
        case 'gmatch': { const s = val(0); if (typeof s !== 'string' || val(1) !== '.') return null; const it = new Iter(s, 0); return { expr: call('gmatch', [lit(s), lit('.')]), val: it }; }
        case 'iter': {
          const v = val(0);
          if (v instanceof Iter) return { expr: args[0].expr, val: v };
          // walking the cache of open upvalues when a function returns: there is nothing in it that belongs to the program
          if (v instanceof Sym && v.name === 'Ib') return { expr: args[0].expr, val: new Iter('', 0) };
          return null;
        }
        case 'byte': { const s = val(0), i = val(1); if (typeof s === 'string' && typeof i === 'number' && i >= 1 && i <= s.length) { const b = s.charCodeAt(i - 1); return { expr: lit(b), val: b }; } return null; }
        case 'band': case 'bor': case 'bxor': { const a = val(0), b = val(1); if (typeof a !== 'number' || typeof b !== 'number') return null; const r = fv.name === 'band' ? u32(a) & u32(b) : fv.name === 'bor' ? u32(a) | u32(b) : u32(a) ^ u32(b); return { expr: lit(u32(r)), val: u32(r) }; }
        case 'lshift': { const a = val(0), b = val(1); if (typeof a !== 'number' || typeof b !== 'number') return null; return { expr: lit(u32(a << (b & 31))), val: u32(a << (b & 31)) }; }
        case 'char': { const n = args.map((a) => a.val); if (!n.every((x) => typeof x === 'number')) return null; const s = String.fromCharCode(...n); return { expr: lit(s), val: s }; }
        default: return null;
      }
    },
  };
  return model;
}

/** The values the partial evaluator starts a handler with: the program, where it is, and the interpreter's own variables as symbols. */
export function initialEnv(profile, code, pc) {
  const { roles } = profile;
  const cells = new Table();
  for (const [k, role] of profile.cells) { const c = new Table(); c.set(3, new Sym(role)); cells.set(k, c); }
  const vm = new Table();
  const members = new Set(profile.members);
  for (const m of members) vm.set(m, new Sym(helperName(profile, m)));
  return new Map([
    [roles.code, code], [roles.pc, pc], [roles.cells, cells], [roles.vm, vm],
    [roles.regs, new Sym('M')], [roles.upvalueCache, new Sym('Ib')], [roles.children, new Sym('CHILDREN')], [roles.varargs, new Sym('VARARGS')],
  ]);
}
