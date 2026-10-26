// Runs engine operations off the main thread so a large script never freezes the interface, and so a run
// can be cancelled by terminating the worker. One message in, one message out.

import * as api from './api.js';

const OPS = {
  inspect: api.inspectInput,
  detect: api.detectScript,
  beautify: api.beautifyScript,
  analyze: api.analyzeSource,
  recover: api.recoverSource,
  luast: api.luast,
  trace: api.traceSource,
  rename: api.renameScript,
  dump: api.dumpSource,
  origin: api.originCheck,
  diff: (source, options) => api.diffSources(source, options.other),
};

self.onmessage = (event) => {
  const { id, op, source, options } = event.data;
  try {
    const fn = OPS[op];
    if (!fn) throw new Error(`unknown operation "${op}"`);
    // long steps report how far they are; the interface shows it while the worker is busy
    const opts = op === 'recover' ? { ...options, onProgress: (progress) => self.postMessage({ id, progress }) } : options;
    self.postMessage({ id, ok: true, result: fn(source, opts) });
  } catch (e) {
    self.postMessage({ id, ok: false, error: String((e && e.stack) || e) });
  }
};
