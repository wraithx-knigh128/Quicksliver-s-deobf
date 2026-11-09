// Sample packages: original-and-protected pairs supplied by someone entitled to supply them.
//
// A package is a JSON manifest. The page can build one from files the person chose (nothing is uploaded anywhere); the Node tools read one from disk
// (local/samples/, git-ignored) and differential-test it. The manifest's `attestation` is a statement by the supplier and is stored verbatim: nothing
// here can check it, so it is never used as evidence that a sample is genuine, only as the record of who vouched for it.

export const PACKAGE_SCHEMA = 1;
const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

/** SHA-256 of a binary string, hex. Works in the page and in Node. */
export async function sha256(binaryString) {
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) bytes[i] = binaryString.charCodeAt(i) & 255;
  return hex(await globalThis.crypto.subtle.digest('SHA-256', bytes));
}

/**
 * @param {{system: string, claimedVersion?: string|null, supplier: string, attestation: string, runtimeHint?: string,
 *          pairs: Array<{id: string, original: string, protected: string}>}} input
 */
export async function buildPackage(input) {
  const problems = [];
  if (!input.system) problems.push('system is required (what produced the protected files)');
  if (!input.supplier) problems.push('supplier is required');
  if (!input.attestation || input.attestation.length < 20) problems.push('attestation is required: say in your own words that you own both files or have the owner\'s permission to use them for this purpose');
  if (!Array.isArray(input.pairs) || !input.pairs.length) problems.push('at least one pair is required');
  const ids = new Set();
  const pairs = [];
  for (const p of input.pairs || []) {
    if (!p.id || ids.has(p.id)) problems.push(`pair id "${p.id}" is missing or repeated`);
    ids.add(p.id);
    if (!p.original) problems.push(`${p.id}: the original is empty`);
    if (!p.protected) problems.push(`${p.id}: the protected file is empty`);
    if (p.original && p.protected && p.original === p.protected) problems.push(`${p.id}: the protected file is identical to the original, so it shows nothing`);
    pairs.push({ id: p.id, original: p.original, protected: p.protected, originalSha256: p.original ? await sha256(p.original) : null, protectedSha256: p.protected ? await sha256(p.protected) : null });
  }
  if (problems.length) return { ok: false, problems };
  return {
    ok: true,
    package: {
      schema: PACKAGE_SCHEMA, system: input.system, claimedVersion: input.claimedVersion || null, supplier: input.supplier, attestation: input.attestation,
      runtimeHint: input.runtimeHint || null, createdAt: new Date().toISOString(), pairs,
    },
  };
}

/** Check a manifest that was read from somewhere else: the hashes are the integrity check, the rest is shape. */
export async function validatePackage(pkg) {
  const problems = [];
  if (!pkg || pkg.schema !== PACKAGE_SCHEMA) return { ok: false, problems: ['not a sample package (schema 1)'] };
  if (!pkg.attestation) problems.push('no attestation');
  for (const p of pkg.pairs || []) {
    if ((await sha256(p.original)) !== p.originalSha256) problems.push(`${p.id}: original does not match its hash`);
    if ((await sha256(p.protected)) !== p.protectedSha256) problems.push(`${p.id}: protected file does not match its hash`);
  }
  if (!(pkg.pairs || []).length) problems.push('no pairs');
  return { ok: problems.length === 0, problems };
}

/**
 * Pair files by name: `<id>.original.lua` with `<id>.protected.lua` (`.orig.` and `.src.` are accepted for the first, `.obf.` for the second).
 * @param {Array<{name: string, text: string}>} files
 * @returns {{pairs: Array<{id: string, original: string, protected: string}>, unpaired: string[]}}
 */
export function pairFiles(files) {
  const re = /^(.*)\.(original|orig|src|protected|obf|obfuscated)\.(lua|luau|txt)$/i;
  const by = new Map();
  const unpaired = [];
  for (const f of files) {
    const m = re.exec(f.name);
    if (!m) { unpaired.push(f.name); continue; }
    const side = /^(original|orig|src)$/i.test(m[2]) ? 'original' : 'protected';
    const e = by.get(m[1]) || {};
    e[side] = f.text;
    e[`${side}Name`] = f.name;
    by.set(m[1], e);
  }
  const pairs = [];
  for (const [id, e] of by) {
    if (e.original !== undefined && e.protected !== undefined) pairs.push({ id, original: e.original, protected: e.protected });
    else unpaired.push(e.originalName || e.protectedName);
  }
  return { pairs, unpaired };
}
