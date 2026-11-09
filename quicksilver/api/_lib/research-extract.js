// Research extraction: what a fetched document says, with the evidence attached, and how far the source can be trusted.
//
// Nothing here is a model. Every finding is a rule match, and carries the exact text it matched (`quote`, a substring of the document at `offset`), so
// a reader can check it against the source and a test can prove it. Source credibility is likewise a set of stated rules over *who published it and how
// directly it speaks to the subject*; it is not a verdict that something is true.

// ---- sources -----------------------------------------------------------------------------------------------------------------------------
/** Owners on GitHub whose repositories are the tool's own (or the language's own). */
const OWNERS = { luraph: 'Luraph', 'prometheus-lua': 'Prometheus', zeusssz: 'Hercules', roblox: 'Luau', bytexenon: 'LuaXen', 'luau-lang': 'Luau' };
const VENDOR_SITES = { 'lura.ph': 'Luraph', 'luau.org': 'Luau', 'luau-lang.org': 'Luau', 'prometheus-lua.github.io': 'Prometheus', 'www.lua.org': 'Lua', 'luajit.org': 'LuaJIT' };
const BASE = {
  'vendor-primary': 0.9, 'tool-source': 0.85, 'documentation-other-vendor': 0.6, 'package-registry': 0.7, 'community-forum': 0.45, 'blog-writeup': 0.45,
  'community-repo': 0.4, 'unvetted-tool-repo': 0.2, 'competitor-marketing': 0.3, 'aggregator-generated': 0.15, unknown: 0.3,
};
const MARKETING = new Set(['luaobscura.com', 'abacktools.com', 'voltils.pages.dev', 'robloxscriptobfuscator.pages.dev']);
const GENERATED = new Set(['codepal.ai', 'scrappey.com']);
const DEOBF_REPO = /deobfuscat|devirt|crack|bypass|dumper|unprotect|decompile?r?/i;

/**
 * @param {string} url
 * @param {string} [subject] what the research is about ("Luraph"): a source is primary only for its own subject
 * @returns {{class: string, subject: string|null, score: number, reasons: string[], flags: string[]}}
 */
export function classifySource(url, subject = null) {
  const u = new URL(url);
  const host = u.hostname.toLowerCase();
  const path = u.pathname.split('/').filter(Boolean);
  const reasons = [];
  const flags = [];
  let cls = 'unknown';
  let about = null;
  if (VENDOR_SITES[host]) { cls = 'vendor-primary'; about = VENDOR_SITES[host]; reasons.push(`${host} is the publisher's own site for ${about}`); }
  else if (host === 'github.com' || host === 'raw.githubusercontent.com' || host.endsWith('githubusercontent.com') || host === 'gist.github.com') {
    const owner = (path[0] || '').toLowerCase();
    const repo = (path[1] || '').toLowerCase();
    if (OWNERS[owner]) { cls = owner === 'luraph' ? 'vendor-primary' : 'tool-source'; about = OWNERS[owner]; reasons.push(`repository owned by ${path[0]}, the author of ${about}`); }
    else if (DEOBF_REPO.test(repo) || DEOBF_REPO.test(owner)) {
      cls = 'unvetted-tool-repo';
      reasons.push('a third-party tool that claims to defeat a protection; its claims are unverified');
      flags.push('may-be-malicious: repositories like this are a common way to distribute malware; read, never run');
    } else { cls = 'community-repo'; reasons.push('a repository by a third party; what it says is not checked against the tool'); }
  } else if (host === 'git.openpunk.com') { cls = 'documentation-other-vendor'; about = 'MoonVeil'; reasons.push("another product's documentation: primary for that product, secondary for anything it says about others"); }
  else if (host === 'devforum.roblox.com') { cls = 'community-forum'; reasons.push('a community forum: opinions and experience, not measurements'); }
  else if (host === 'pypi.org' || host === 'registry.npmjs.org') { cls = 'package-registry'; reasons.push('package metadata published by the maintainer'); }
  else if (MARKETING.has(host)) { cls = 'competitor-marketing'; reasons.push('a vendor or marketplace page that compares itself with others: biased'); flags.push('biased'); }
  else if (GENERATED.has(host)) { cls = 'aggregator-generated'; reasons.push('machine-written question-and-answer pages: no author, no accountability'); flags.push('generated'); }
  else if (/\.blog$|blog\./.test(host)) { cls = 'blog-writeup'; reasons.push('an individual\'s write-up'); }
  let score = BASE[cls];
  // a source is primary for its own subject only
  if ((cls === 'vendor-primary' || cls === 'tool-source') && subject && about && about.toLowerCase() !== subject.toLowerCase()) {
    score = Math.min(score, 0.5);
    reasons.push(`it speaks for ${about}, not for ${subject}`);
  }
  return { class: cls, subject: about, score: Math.round(score * 100) / 100, reasons, flags };
}

// ---- findings ----------------------------------------------------------------------------------------------------------------------------
const SUBJECTS = ['Luraph', 'Prometheus', 'IronBrew', 'Hercules', 'MoonVeil', 'MoonSec', 'PSU', 'Luarmor', 'Synapse Xen', 'LuaXen', 'Luau', 'LuaJIT', 'Voltils', 'WeAreDevs'];
const FEATURES = [
  ['virtual machine', /\bvirtual machines?\b|\bVM\b/],
  ['control-flow flattening', /control[- ]flow flatten/i],
  ['string encryption', /string (?:encryption|encrypt)/i],
  ['anti-tamper', /anti[- ]?tamper/i],
  ['bytecode', /\bbytecode\b/i],
  ['compression', /\bcompress(?:ion|ed)\b/i],
  ['macros', /\bmacros?\b/i],
  ['randomised instruction set', /randomi[sz]ed[^.\n]{0,40}(?:instruction set|opcodes?)/i],
  ['per-function virtualisation', /per[- ]function|selective(?:ly)? virtuali[sz]/i],
];
const LICENSES = [/\bMIT License\b/, /\bGNU (?:Affero )?General Public License\b/i, /\bAGPL-?\d?(?:\.\d)?\b/, /\bApache License(?:,? Version 2\.0)?\b/i, /\bBSD [23]-Clause\b/, /\bMozilla Public License\b/i];

const window = (text, start, end, pad = 70) => {
  let a = Math.max(0, start - pad);
  let b = Math.min(text.length, end + pad);
  // cut at word boundaries so the quote reads whole, but never past the match
  while (a > 0 && a < start && !/\s/.test(text[a - 1])) a++;
  while (b < text.length && b > end && !/\s/.test(text[b])) b--;
  return { quote: text.slice(a, b).trim(), offset: a };
};

/** Rule-based findings. Every `quote` is a substring of `text`. */
export function extractFindings(text, { limit = 200 } = {}) {
  const out = [];
  const seen = new Set();
  const push = (f) => { const k = `${f.type}|${f.subject || ''}|${f.value}|${f.offset}`; if (!seen.has(k) && out.length < limit) { seen.add(k); out.push({ method: 'rule', ...f }); } };
  const subjectNear = (index) => {
    let best = null;
    for (const s of SUBJECTS) {
      const re = new RegExp(`\\b${s}\\b`, 'g');
      let m;
      while ((m = re.exec(text)) !== null) { const d = Math.abs(m.index - index); if (d <= 160 && (!best || d < best.d)) best = { s, d }; }
    }
    return best && best.s;
  };

  // the banner a protector writes into its output: the one place a version is stated by the tool itself
  const banner = /(?:protected|obfuscated|generated)\s+(?:using|with|by)\s+([A-Z][A-Za-z ]{2,30}?)\s+(?:Obfuscator\s+)?v(\d+(?:\.\d+){1,3})/g;
  for (let m; (m = banner.exec(text)) !== null;) { const { quote, offset } = window(text, m.index, m.index + m[0].length); push({ type: 'banner', subject: m[1].trim(), value: `v${m[2]}`, quote, offset }); }

  const version = /\b[vV](\d+(?:\.\d+){1,3})\b/g;
  for (let m; (m = version.exec(text)) !== null;) {
    const subject = subjectNear(m.index);
    if (!subject) continue;
    const { quote, offset } = window(text, m.index, m.index + m[0].length);
    push({ type: 'version', subject, value: `v${m[1]}`, quote, offset });
  }
  // "Luraph v15": a major version written next to the name needs no minor part, which the pattern above insists on
  const named = new RegExp(`\\b(${SUBJECTS.join('|')})(?:\\s+(?:Obfuscator|VM|SDK))?\\s+[vV](\\d{1,2})(?!\\d|\\.\\d)`, 'g');
  for (let m; (m = named.exec(text)) !== null;) { const { quote, offset } = window(text, m.index, m.index + m[0].length); push({ type: 'version', subject: m[1], value: `v${m[2]}`, quote, offset }); }
  const macro = /\b(LPH_[A-Z0-9_]+|MV_[A-Z0-9_]+)\b/g;
  for (let m; (m = macro.exec(text)) !== null;) { const { quote, offset } = window(text, m.index, m.index + m[0].length); push({ type: 'macro', subject: m[1].startsWith('LPH') ? 'Luraph' : 'MoonVeil', value: m[1], quote, offset }); }
  for (const re of LICENSES) { const m = re.exec(text); if (m) { const { quote, offset } = window(text, m.index, m.index + m[0].length); push({ type: 'license', value: m[0], quote, offset }); } }
  for (const [name, re] of FEATURES) {
    const g = new RegExp(re.source, re.flags.includes('g') ? re.flags : `${re.flags}g`);
    let n = 0;
    for (let m; (m = g.exec(text)) !== null && n < 3; n++) { const { quote, offset } = window(text, m.index, m.index + m[0].length); push({ type: 'feature', subject: subjectNear(m.index) || undefined, value: name, quote, offset }); }
  }
  const date = /\b(20\d\d-\d\d-\d\d)\b|\b((?:January|February|March|April|May|June|July|August|September|October|November|December) \d{1,2}, 20\d\d)\b/g;
  for (let m; (m = date.exec(text)) !== null;) { const subject = subjectNear(m.index); if (subject) { const { quote, offset } = window(text, m.index, m.index + m[0].length); push({ type: 'date', subject, value: m[0], quote, offset }); } }
  return out;
}

/** True when `quote` appears in `text` (whitespace-insensitive), which is the test every finding, rule-made or model-made, has to pass. */
export function isGrounded(quote, text) {
  if (typeof quote !== 'string' || quote.trim().length < 3) return false;
  const norm = (s) => s.replace(/\s+/g, ' ').trim();
  return norm(text).includes(norm(quote));
}

// ---- text that tries to instruct the reader -------------------------------------------------------------------------------------------------
const INJECTION = [
  /ignore (?:all |any |the )?(?:previous|prior|above|earlier) (?:instructions?|prompts?|messages?)/i,
  /disregard (?:all |the )?(?:above|previous|prior)/i,
  /\b(?:you are|act as|pretend to be) (?:now )?(?:an? )?(?:ai|assistant|language model|llm)\b/i,
  /\b(?:system|developer) prompt\b/i,
  /<\/?(?:system|assistant|instructions?)>/i,
  /\bAI (?:assistants?|agents?|models?|tools?)\b[^.\n]{0,80}\b(?:refuse|ignore|must not|do not|never|report)\b/i,
];

/** Passages in a document that address the program reading it. They are reported, never obeyed. */
export function injectionScan(text) {
  const hits = [];
  for (const re of INJECTION) {
    const m = re.exec(text);
    if (m) { const { quote, offset } = window(text, m.index, m.index + m[0].length, 40); hits.push({ pattern: re.source.slice(0, 40), quote, offset }); }
  }
  return hits;
}

/** A short, deterministic digest: headings, the opening paragraph, and what was found. Nothing in it is written by a model. */
export function digest(text, findings) {
  const headings = [...text.matchAll(/^#{1,3}\s+(.+)$/gm)].map((m) => m[1].trim()).slice(0, 12);
  const first = text.split(/\n\s*\n/).map((p) => p.trim()).find((p) => p.length > 40 && !p.startsWith('#') && !p.startsWith('<')) || '';
  const by = {};
  for (const f of findings) by[f.type] = (by[f.type] || 0) + 1;
  return { headings, opening: first.slice(0, 300), counts: by };
}

/**
 * Agreement between sources: findings that several independent sources state. Independence is by publisher (host or GitHub owner), not by URL.
 * @param {Array<{url: string, findings: Array}>} records
 */
export function corroborate(records) {
  const publisher = (url) => { const u = new URL(url); return u.hostname.endsWith('githubusercontent.com') || u.hostname === 'github.com' ? `github:${(u.pathname.split('/')[1] || '').toLowerCase()}` : u.hostname; };
  const groups = new Map();
  for (const r of records) {
    for (const f of r.findings || []) {
      const key = `${f.type}|${(f.subject || '').toLowerCase()}|${String(f.value).toLowerCase()}`;
      if (!groups.has(key)) groups.set(key, { type: f.type, subject: f.subject || null, value: f.value, publishers: new Set(), urls: new Set() });
      const g = groups.get(key);
      g.publishers.add(publisher(r.url));
      g.urls.add(r.url);
    }
  }
  return [...groups.values()].map((g) => ({ type: g.type, subject: g.subject, value: g.value, independentSources: g.publishers.size, urls: [...g.urls] })).sort((a, b) => b.independentSources - a.independentSources);
}
