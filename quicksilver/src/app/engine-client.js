// Talks to the engine worker. One operation at a time; cancel() terminates the worker (the only reliable
// way to stop a script that is stuck in a long pass) and the next call starts a fresh one.

export class EngineError extends Error {
  constructor(message, kind) { super(message); this.kind = kind; }
}

export class Engine {
  constructor() {
    this.worker = null;
    this.seq = 0;
    this.pending = null;
    this.onbusy = () => {};
    this.onprogress = () => {};
  }

  get busy() { return this.pending !== null; }

  start() {
    if (this.worker) return;
    this.worker = new Worker(new URL('../engine.worker.js', import.meta.url), { type: 'module' });
    this.worker.onmessage = (e) => {
      const p = this.pending;
      if (!p || e.data.id !== p.id) return;
      if (e.data.progress) { this.onprogress(e.data.progress, p.op); return; }
      this.finish();
      if (e.data.ok) p.resolve(e.data.result);
      else p.reject(new EngineError(e.data.error, 'engine'));
    };
    this.worker.onerror = (e) => {
      const p = this.pending;
      this.stop();
      if (p) { this.finish(); p.reject(new EngineError(e.message || 'The engine worker failed to start.', 'worker')); }
    };
  }

  stop() { if (this.worker) { this.worker.terminate(); this.worker = null; } }

  finish() {
    if (this.pending) clearTimeout(this.pending.timer);
    this.pending = null;
    this.onbusy(false);
  }

  /**
   * @param {string} op inspect | detect | beautify | analyze | recover | luast | diff
   * @param {string} source binary string
   * @param {object} [options]
   * @param {{timeoutMs?: number}} [limits]
   */
  run(op, source, options = {}, { timeoutMs = 120_000 } = {}) {
    if (this.pending) return Promise.reject(new EngineError('The engine is busy.', 'busy'));
    this.start();
    const id = ++this.seq;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (!this.pending || this.pending.id !== id) return;
        const p = this.pending;
        this.stop();
        this.finish();
        p.reject(new EngineError(`Stopped after ${Math.round(timeoutMs / 1000)} s. The input is too large or too tangled for this operation.`, 'timeout'));
      }, timeoutMs);
      this.pending = { id, resolve, reject, timer, op, started: performance.now() };
      this.onbusy(true, op);
      this.worker.postMessage({ id, op, source, options });
    });
  }

  cancel() {
    const p = this.pending;
    if (!p) return;
    this.stop();
    this.finish();
    p.reject(new EngineError('Cancelled.', 'cancelled'));
  }
}
