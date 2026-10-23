// Licence state for the interface: loads the stored key, verifies it offline, optionally asks the
// revocation endpoint, and derives what the interface may do. The key itself is only ever kept in this
// browser's localStorage.

import { PUBLIC_KEY, POLICY, REVOCATION_ENDPOINT } from '../license/config.js';
import { verifyToken, entitlements, checkRevocation, describeLicense } from '../license/license.js';
import { h, modal } from './dom.js';

const KEY = 'qs.license.v1';
const read = () => { try { return localStorage.getItem(KEY) || ''; } catch { return ''; } };
const write = (v) => { try { if (v) localStorage.setItem(KEY, v); else localStorage.removeItem(KEY); } catch { /* ignore */ } };

export class LicenseState {
  constructor() {
    this.token = read();
    this.state = { status: PUBLIC_KEY ? 'missing' : 'unconfigured' };
    this.ent = entitlements(this.state, POLICY);
    this.revocation = { revoked: false, checked: false };
    this.onchange = () => {};
  }

  get configured() { return !!PUBLIC_KEY; }

  async refresh() {
    this.state = await verifyToken(this.token, PUBLIC_KEY);
    this.revocation = { revoked: false, checked: false };
    if (this.state.status === 'valid' && REVOCATION_ENDPOINT) {
      this.revocation = await checkRevocation(this.state.payload.id, REVOCATION_ENDPOINT);
      if (this.revocation.revoked) this.state = { status: 'invalid', reason: 'This licence has been revoked.', payload: this.state.payload };
    }
    this.ent = entitlements(this.state, POLICY);
    this.onchange();
  }

  async set(token) {
    this.token = token.trim();
    write(this.token);
    await this.refresh();
  }

  /** Short text for the title bar. */
  label() {
    if (!this.configured) return 'Licence: not enforced';
    const s = this.state.status;
    if (s === 'valid') return `Licensed: ${this.state.payload.name || this.state.payload.id}`;
    if (s === 'expired') return 'Licence expired';
    if (s === 'missing') return 'Evaluation';
    return 'Licence invalid';
  }

  describe() { return describeLicense(this.state, this.ent); }

  /** Ask for an entitlement; shows the licence dialog and returns false if it is not granted. */
  allow(feature) { return !!this.ent[feature]; }
}

export async function showLicenseDialog(lic) {
  const d = lic.describe();
  const input = h('textarea.form', { spellcheck: 'false', placeholder: 'QS1.…', 'aria-label': 'Licence key' });
  input.value = lic.token;
  const status = h('p.note' + (d.status === 'valid' ? '.ok' : d.status === 'unconfigured' ? '.info' : '.warn'),
    !lic.configured
      ? 'Licence enforcement is not configured in this build, so every feature is available. The issuer sets it up with tools/license/keygen.mjs (see docs/LICENSING.md).'
      : d.status === 'valid'
        ? `Valid. Licensed to ${d.licensee || '—'}; plan ${d.plan}; expires ${d.expires}.`
        : (d.reason || 'No licence key entered. Evaluation limits apply.'));
  const lim = lic.ent.maxBytes ? `${Math.round(lic.ent.maxBytes / 1000)} kB input limit` : 'no input limit';
  const features = h('p.dim', { style: { margin: 0 } },
    `Current access: ${lic.ent.level}. Recovery ${lic.ent.recover ? 'on' : 'off'}, sandbox ${lic.ent.sandbox ? 'on' : 'off'}, export ${lic.ent.export ? 'on' : 'off'}, ${lim}.`);
  const body = [status, features];
  if (lic.configured) body.push(h('label', { style: { display: 'grid', gap: '4px' } }, h('span.dim', 'Licence key'), input));
  body.push(h('p.faint', { style: { margin: 0 } },
    'The key is checked in this page against a public key; it is stored only in this browser. A signature check in client-side code can deter casual sharing but cannot stop someone who edits the page; see the licensing notes for what it does and does not protect.'));
  const buttons = lic.configured
    ? [{ id: 'remove', label: 'Remove key' }, { id: 'cancel', label: 'Close' }, { id: 'save', label: 'Verify and save', primary: true }]
    : [{ id: 'cancel', label: 'Close', primary: true }];
  const r = await modal({ title: 'Licence', body, buttons });
  if (r === 'save') await lic.set(input.value);
  if (r === 'remove') await lic.set('');
  return r;
}
