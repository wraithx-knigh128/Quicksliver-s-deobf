// The family-module SDK: how a new kind of transformation is added without touching the platform.
//
// A family is data: an id, a name, where it came from, the versions it has been tested at, and a signature over the features in features.js
// (`all`: features that must be present; `none`: features that must be absent). The registry matches signatures against the features of a script.
// Families the detector already knows by name (src/detect/) stay where they are; the registry holds the ones that were *learned*
// (study.js) or registered by hand, and it is read from data/research/custom-families.json by the page and by the lab.
//
// Compatibility is not a field of a family. What is known about how well a family is handled comes from experiment records (kb.js), per version, and a
// version nobody has tested is reported as untested.

export const ORIGINS = ['lab-learned', 'registered', 'builtin'];

export function defineFamily(spec) {
  const bad = (why) => { throw new Error(`family "${spec && spec.id}": ${why}`); };
  if (!spec || typeof spec.id !== 'string' || !/^[a-z0-9][a-z0-9_.-]*$/.test(spec.id)) bad('id must be lower-case letters, digits, _ . -');
  if (typeof spec.name !== 'string' || !spec.name) bad('name is required');
  if (!ORIGINS.includes(spec.origin)) bad(`origin must be one of ${ORIGINS.join(', ')}`);
  const sig = spec.signature;
  if (!sig || !Array.isArray(sig.all) || !sig.all.length) bad('a signature needs at least one required feature');
  if (sig.none && !Array.isArray(sig.none)) bad('signature.none must be a list');
  const versions = (spec.versions || [{ id: 'unversioned', label: 'unversioned' }]).map((v) => {
    if (!v || typeof v.id !== 'string') bad('every version needs an id');
    return Object.freeze({ id: v.id, label: v.label || v.id });
  });
  return Object.freeze({
    id: spec.id, name: spec.name, origin: spec.origin, kind: spec.kind || 'custom', summary: spec.summary || '', versions,
    signature: Object.freeze({ all: [...sig.all], none: [...(sig.none || [])] }),
    learned: spec.learned || null,
  });
}

/** Does a set of features satisfy a signature? */
export function satisfies(signature, features) {
  return signature.all.every((f) => features.has(f)) && !(signature.none || []).some((f) => features.has(f));
}

export class FamilyRegistry {
  constructor(specs = []) {
    this.families = new Map();
    for (const s of specs) this.register(s);
  }

  register(spec) {
    const f = defineFamily(spec);
    if (this.families.has(f.id)) throw new Error(`family "${f.id}" is already registered`);
    this.families.set(f.id, f);
    return f;
  }

  unregister(id) { return this.families.delete(id); }
  get(id) { return this.families.get(id) || null; }
  list() { return [...this.families.values()]; }

  /** The registered families whose signature a script satisfies. @param {Set<string>} features */
  match(features) {
    return this.list().filter((f) => satisfies(f.signature, features)).map((f) => ({ id: f.id, name: f.name, evidence: f.signature.all.slice() }));
  }
}

/** A registry from the contents of data/research/custom-families.json. */
export function registryFromData(data) {
  const reg = new FamilyRegistry();
  for (const f of (data && data.families) || []) reg.register(f);
  return reg;
}
