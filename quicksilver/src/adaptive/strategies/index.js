// The strategies the engine starts with. A new one is an object with `id`, `title`, `order`, an `observe(ast, analysis)` that returns
// findings ({kind, line, label, evidence, confidence, weight}) and a `run(ast, context, findings)` that returns {changed, ...}; add it to this
// list (or to an engine with `register`) and nothing else needs to know about it.

import { layers, decoders, cleanups } from './classic.js';
import { proxies } from './proxies.js';
import { tables } from './tables.js';
import { opaque } from './opaque.js';
import { dispatch } from './dispatch.js';
import { interpreter, payload, remote } from './residual.js';

export function defaultStrategies() {
  return [layers, proxies, tables, opaque, decoders, dispatch, interpreter, payload, remote, ...cleanups];
}
