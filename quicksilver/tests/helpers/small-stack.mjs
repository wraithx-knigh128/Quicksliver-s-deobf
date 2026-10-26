// Runs a task in a worker thread with a small stack, the way the page's engine worker runs: deep recursion and spreading a huge array into a call
// work on the main thread of Node and fail there.
import { Worker, isMainThread, workerData, parentPort } from 'node:worker_threads';
import { fileURLToPath } from 'node:url';

const self = fileURLToPath(import.meta.url);

export function inSmallStack(task, args, stackSizeMb = 0.5) {
  return new Promise((resolve, reject) => {
    const w = new Worker(self, { workerData: { task, args }, resourceLimits: { stackSizeMb } });
    w.once('message', (m) => (m.ok ? resolve(m.value) : reject(new Error(m.error))));
    w.once('error', reject);
  });
}

if (!isMainThread && workerData && workerData.task) {
  const { task, args } = workerData;
  try {
    let value;
    if (task === 'z85') {
      const { z85Decode } = await import('../../src/recover/moonveil.js');
      value = z85Decode(args.text).length;
    } else if (task === 'recover') {
      const { recover } = await import('../../src/recover/pipeline.js');
      const r = recover(args.source, { sandbox: { enabled: false } });
      value = { ok: r.ok, steps: r.steps.map((s) => [s.id, s.status]), length: r.output ? r.output.length : 0 };
    } else throw new Error(`unknown task ${task}`);
    parentPort.postMessage({ ok: true, value });
  } catch (e) {
    parentPort.postMessage({ ok: false, error: String((e && e.stack) || e) });
  }
}
