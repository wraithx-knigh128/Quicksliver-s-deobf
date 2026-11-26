// Server engines from the page (Prompt XXIX). The one Deobfuscate pipeline (src/pipeline/unified.js) asks for one when detection finds a
// format that has a measured adapter (src/pipeline/engines.js); the person never picks an engine. Before a script leaves the browser the
// person is asked, every run, to confirm that they may have it analysed, and told what happens to it: it goes to this site's own
// /api/engine (api/engine.js), is read there by the engine in a separate, isolated process without being run, and only the rebuilt
// bytecode comes back. Declining keeps everything in the browser: QuickSilver's own passes run instead.

import { h, modal } from './dom.js';
import { serverFetch, licenceRefusal } from './server.js';

// what this tab learnt about the server: which engines it offers (GET /api/engine), and a refusal that will not change during the visit
let offered = null;        // Promise<Set<string>>
let blocked = null;        // { outcome, message } once the server refused for a reason that holds for every script (licence, switched off)

const b64 = (bin) => { let s = ''; for (let i = 0; i < bin.length; i += 0x8000) s += String.fromCharCode(...Array.from(bin.slice(i, i + 0x8000), (c) => c.charCodeAt(0) & 255)); return btoa(s); };

function engines() {
  if (!offered) {
    offered = (async () => {
      try {
        const res = await serverFetch('/api/engine', { method: 'GET' });
        const body = await res.json().catch(() => null);
        if (!res.ok || !body || !body.ok) return new Set();
        return new Set((body.engines || []).map((e) => e.id));
      } catch { return new Set(); }
    })();
  }
  return offered;
}

/** Forget what this tab learnt (a licence key was entered, or for tests). */
export function resetEngineState() { offered = null; blocked = null; }

/**
 * Ask the server engine of `adapter` to rebuild `text` (a binary string). Resolves to the server's answer with `bytecode` as a binary
 * string, or `{ok: false, outcome, message}` — declined, not offered, refused, failed — which the pipeline reports and then falls back on.
 */
export async function serverEngineRequest(adapter, text, { confirm = confirmUse } = {}) {
  if (blocked) return { ok: false, ...blocked };
  const ids = await engines();
  if (!ids.has(adapter.id)) return { ok: false, outcome: 'unavailable', message: `this deployment does not offer the ${adapter.familyLabel} engine (its /api/engine function is missing or switched off)` };
  if (!(await confirm(adapter, text))) return { ok: false, outcome: 'declined', message: 'you chose to keep the script in the browser' };
  let res;
  try {
    res = await serverFetch('/api/engine', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ engine: adapter.id, source: b64(text), attest: true }) });
  } catch (e) {
    return { ok: false, outcome: 'unavailable', message: `the site could not be reached: ${e.message || e}` };
  }
  const body = await res.json().catch(() => null);
  if (!body) return { ok: false, outcome: 'unavailable', message: `the server answered ${res.status}` };
  const lic = licenceRefusal(res.status, body);
  if (lic) { blocked = { outcome: 'licence', message: lic }; return { ok: false, ...blocked }; }
  if (body.outcome === 'disabled') blocked = { outcome: 'disabled', message: body.message };
  if (!body.ok) return { ok: false, outcome: body.outcome || `http-${res.status}`, message: body.message || `the server answered ${res.status}` };
  // the engine's answer as a binary string: Lua 5.1 bytecode, or Lua source (api/engine.js says which)
  return { ...body, bytecode: body.bytecode ? atob(body.bytecode) : undefined, source: body.source ? atob(body.source) : undefined };
}

async function confirmUse(adapter, text) {
  const kb = Math.max(1, Math.round(text.length / 1024));
  const r = await modal({
    title: `Rebuild with the ${adapter.familyLabel} engine?`,
    body: [
      h('p', `This script is protected with ${adapter.familyLabel}. QuickSilver's own passes ${adapter.when === 'own-result-keeps-vm' ? 'left its virtual machine in place' : 'cannot take its virtual machine apart'}; a server engine can try.`),
      h('ul', [
        h('li', `The script (${kb} KB) is sent to this site's server, nowhere else. The engine reads it in a separate, isolated process; it does not run it, and nothing is kept once the answer is sent.`),
        h('li', adapter.output === 'lua-source'
          ? 'Only the rebuilt program comes back; QuickSilver uses it only if it behaves like your script in the sandbox here, and keeps its own result otherwise.'
          : 'Only the rebuilt program comes back, as Lua 5.1 bytecode; QuickSilver decompiles and checks it here, like every other result.'),
        h('li', `Engine: ${adapter.licence}.`),
      ]),
      h('p', h('b', 'Send it only if you own this script or are authorised to analyse it.')),
    ],
    buttons: [{ id: 'cancel', label: 'Keep it in the browser' }, { id: 'ok', label: 'I am authorised: use the engine', primary: true }],
  });
  return r === 'ok';
}
