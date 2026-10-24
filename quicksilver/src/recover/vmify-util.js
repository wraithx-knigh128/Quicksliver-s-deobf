// Small helpers shared by the Vmify modules.

export class VmifyError extends Error {}

export const fail = (msg) => { throw new VmifyError(msg); };

export const stripParens = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
export const isName = (e, v, info) => !!v && !!e && e.type === 'Name' && info.varOf.get(e) === v;
export const num = (value) => ({ type: 'Number', value, raw: null });
export const nameNode = (name) => ({ type: 'Name', name });

/** The Var behind a Name node, or undefined. */
export const varOf = (info, e) => (e && e.type === 'Name' ? info.varOf.get(e) : undefined);
