// Identification: which system produced (or is meant for) this script, which version, on what evidence, and what the engine may say about it.
//
// Three kinds of evidence, each with its own ceiling (src/research/profiles.js):
//   * the detector's families (signatures and banners it already carries);
//   * a Luraph banner comment, which names a version. It says what the file claims; the text can be edited by anyone, so it cannot be trusted above 0.7;
//   * a set of Luraph macros in an UNPROTECTED script. The macros a script uses narrow the generation of the service it was written for, because the
//     vendor's own SDK repository shows which macros exist in which generation. Protected output no longer contains them.
//
// A capability only takes part if it is enabled in data/research/capabilities.json, and a capability is only enabled after its verifier passed
// (tools/research/capabilities.mjs). Without that file nothing but the detector is used.

import { supportClaim } from './profiles.js';

const BANNER = /protected\s+(?:using|with|by)\s+Luraph\s+Obfuscator\s+v(\d+)\.(\d+)(?:\.(\d+))?/i;
const MACRO = /\bLPH_[A-Z0-9_]+\b/g;

/** Generation of Luraph for a banner version, per the profile's periods; null when outside what is profiled. */
export function generationForVersion(major, minor) {
  if (major === 13) return 'v13-era';
  if (major === 14) return 'v14';
  if (major === 15 && minor === 0) return 'v15';
  if (major === 15 && minor >= 1) return 'v15.1';
  return null;
}

/** The generations whose SDK defines every macro in `used`. */
export function generationsForMacros(used, profile) {
  return profile.versions.filter((v) => v.macros && used.every((m) => v.macros.all.includes(m))).map((v) => v.id);
}

const enabled = (capabilities, id) => !capabilities || capabilities.some((c) => c.id === id && c.enabled);

/**
 * @param {string} source
 * @param {{detection?: object, profiles: {profiles: object[]}, capabilities?: Array<{id: string, enabled: boolean}>|null}} ctx
 * @returns {{systems: object[], notes: string[]}}
 */
export function identify(source, { detection = null, profiles, capabilities = null }) {
  const byId = new Map(profiles.profiles.map((p) => [p.id, p]));
  const systems = [];
  const notes = [];
  const seen = new Set();

  for (const f of (detection && detection.families) || []) {
    if (f.confidence < 0.5) continue;
    const p = byId.get(f.id);
    seen.add(f.id);
    const v = p && p.versions[0];
    systems.push({
      id: f.id, name: f.name || (p && p.name), basis: 'detector', confidence: Math.round(f.confidence * 100) / 100,
      evidence: (f.evidence || []).slice(0, 3).map((e) => e.text || String(e)),
      version: null,
      profile: p ? { id: p.id, kind: p.kind, status: v.verification.status, claim: supportClaim(p, v.id), limitations: v.limitations.slice(0, 3) } : null,
    });
  }

  const luraph = byId.get('luraph');
  if (luraph) {
    const m = enabled(capabilities, 'luraph.banner-version') ? BANNER.exec(source) : null;
    if (m) {
      const [major, minor, patch] = [Number(m[1]), Number(m[2]), m[3] === undefined ? null : Number(m[3])];
      const gen = generationForVersion(major, minor);
      const vp = gen && luraph.versions.find((v) => v.id === gen);
      const claimed = `${major}.${minor}${patch === null ? '' : `.${patch}`}`;
      let entry = systems.find((s) => s.id === 'luraph');
      if (!entry) { entry = { id: 'luraph', name: 'Luraph', basis: 'banner', confidence: 0.7, evidence: [m[0]], version: null, profile: null }; systems.push(entry); }
      entry.evidence = [m[0], ...entry.evidence.filter((e) => e !== m[0])].slice(0, 3);
      entry.version = {
        claimed: `v${claimed}`, generation: gen, confidence: gen ? 0.7 : 0, basis: 'banner',
        caveats: ['A banner is text the file\'s owner controls: it states what the file claims, not what produced it.', ...(gen ? [] : [`Version ${claimed} is outside the generations profiled (v13-era to v15.1), so no generation is estimated.`])],
      };
      if (vp) entry.profile = { id: 'luraph', kind: luraph.kind, version: vp.id, status: vp.verification.status, claim: supportClaim(luraph, vp.id), limitations: vp.limitations.slice(0, 3) };
      seen.add('luraph');
    }
    const used = enabled(capabilities, 'luraph.macro-generation') ? [...new Set(source.match(MACRO) || [])].sort() : [];
    if (used.length) {
      const gens = generationsForMacros(used, luraph);
      const unknown = used.filter((u) => !luraph.versions.some((v) => v.macros.all.includes(u)));
      systems.push({
        id: 'luraph-source', name: 'Script prepared for Luraph (not protected)', basis: 'macro-set', confidence: gens.length ? 0.8 : 0.3,
        evidence: [`uses ${used.join(', ')}`],
        version: {
          claimed: null, generation: gens.length === 1 ? gens[0] : null, candidates: gens, confidence: gens.length === 1 ? 0.8 : gens.length ? 0.5 : 0, basis: 'macro-set',
          caveats: [
            'Macros belong to the unprotected source script; protected output no longer contains them.',
            unknown.length ? `${unknown.join(', ')} ${unknown.length === 1 ? 'is' : 'are'} not defined by the SDK of any generation profiled.` : 'The vendor SDK lists the macros the vendor documents; the service may accept more.',
            gens.length > 1 ? `More than one generation defines all of these macros: ${gens.join(', ')}.` : null,
          ].filter(Boolean),
        },
        profile: null,
      });
    }
  }
  if (!systems.length) notes.push('No known system was identified. The structural traits in the detection report still apply, and the unfamiliar-structure tools can group several samples.');
  return { systems, notes };
}
