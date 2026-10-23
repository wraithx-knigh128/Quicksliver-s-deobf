// Registry of obfuscators and tools QuickSilver knows about.
//
// `evidence` records how much is actually known about a family, and caps how sure detection may be:
//   source      the tool's source code was read; its output patterns are verified against real output
//   banner      only a header / banner string was observed in public material; structure is unknown
//   none        no public signature or documentation was found; only generic heuristics can apply
//
// `sources` are the public references the entry rests on (see docs/RESEARCH.md for what each one
// supports and what could not be fetched from the build environment).

export const FAMILIES = {
  prometheus: {
    name: 'Prometheus',
    kind: 'open-source',
    evidence: 'source',
    maxConfidence: 0.99,
    summary: 'Open-source Lua 5.1 / basic Luau obfuscator written in Lua (levno-710).',
    techniques: ['Vmify (flattened register VM)', 'ConstantArray', 'EncryptStrings', 'SplitStrings',
      'NumbersToExpressions', 'ProxifyLocals', 'AntiTamper', 'WrapInFunction', 'AddVararg'],
    sources: ['https://github.com/prometheus-lua/Prometheus'],
  },
  hercules: {
    name: 'Hercules',
    kind: 'open-source',
    evidence: 'source',
    maxConfidence: 0.99,
    summary: 'Open-source Lua obfuscator with a module pipeline (zeusssz).',
    techniques: ['variable renaming', 'control-flow wrapper', 'Caesar string encoding', 'string-to-expressions',
      'opaque predicates', 'garbage code', 'function inlining', 'wrap in function', 'anti-tamper',
      'dynamic code', 'bytecode encoding', 'virtual machine', 'compressor'],
    sources: ['https://github.com/zeusssz/hercules-obfuscator'],
  },
  luraph: {
    name: 'Luraph',
    kind: 'commercial',
    evidence: 'banner',
    maxConfidence: 0.97,
    summary: 'Commercial virtualising obfuscator for Lua and Luau (lura.ph). Per-script VM; v14 and v15 are current.',
    techniques: ['custom VM per script', 'encrypted constants', 'anti-tamper', 'VM compression (v14+)'],
    sources: ['https://lura.ph/'],
  },
  moonsec_v3: {
    name: 'MoonSec V3',
    kind: 'commercial',
    evidence: 'banner',
    maxConfidence: 0.95,
    summary: 'Commercial Roblox-oriented Lua obfuscator with a VM loader.',
    techniques: ['VM loader', 'constant encoding'],
    sources: [],
  },
  moonveil: {
    name: 'MoonVeil',
    kind: 'commercial',
    evidence: 'banner',
    maxConfidence: 0.9,
    summary: 'Obfuscator with selectable virtualisation, function encryption and control-flow flattening (macros MV_VM, MV_ENC_FUNC, MV_CFF).',
    techniques: ['optional VM', 'function encryption', 'control-flow flattening'],
    sources: ['https://git.openpunk.com/CPunch/MoonVeil-Docs'],
  },
  ironbrew2: {
    name: 'IronBrew 2',
    kind: 'open-source',
    evidence: 'none',
    maxConfidence: 0.45,
    summary: 'Lua obfuscator that compiles scripts to a custom bytecode VM. Output is minified with random names.',
    techniques: ['custom bytecode VM', 'opcode shuffling', 'constant encoding'],
    sources: [],
  },
  luaobfuscator: {
    name: 'LuaObfuscator.com',
    kind: 'service',
    evidence: 'none',
    maxConfidence: 0.4,
    summary: 'Web obfuscation service with several protection levels.',
    techniques: ['string escaping', 'constant tables', 'optional VM'],
    sources: ['https://luaobfuscator.com'],
  },
  fuscator77: {
    name: '77fuscator',
    kind: 'unknown',
    evidence: 'banner',
    maxConfidence: 0.85,
    summary: 'Obfuscator seen only through its "77fuscator <version>" banner; no documentation was found.',
    techniques: [],
    sources: [],
  },
  psu: {
    name: 'PSU',
    kind: 'commercial',
    evidence: 'none',
    maxConfidence: 0.3,
    summary: 'Commercial obfuscator mentioned in community threads; no public signature or documentation was found.',
    techniques: [],
    sources: [],
  },
  ironveil: { name: 'IronVeil', kind: 'unknown', evidence: 'none', maxConfidence: 0.3, summary: 'No public documentation or sample output was found.', techniques: [], sources: [] },
  goofyscator: { name: 'Goofyscator', kind: 'unknown', evidence: 'none', maxConfidence: 0.3, summary: 'No public documentation or sample output was found.', techniques: [], sources: [] },
  clyde: { name: 'Clyde Protection', kind: 'unknown', evidence: 'none', maxConfidence: 0.3, summary: 'No public documentation or sample output was found.', techniques: [], sources: [] },
  xhider: { name: 'XHider', kind: 'unknown', evidence: 'none', maxConfidence: 0.3, summary: 'No public documentation or sample output was found.', techniques: [], sources: [] },
  synapse_xen: {
    name: 'Synapse Xen',
    kind: 'commercial',
    evidence: 'none',
    maxConfidence: 0.3,
    summary: 'Historic commercial obfuscator bundled with an exploit executor; mentioned in community guides.',
    techniques: [],
    sources: [],
  },
  wearedevs: {
    name: 'WeAreDevs Obfuscator',
    kind: 'service',
    evidence: 'none',
    maxConfidence: 0.3,
    summary: 'Web obfuscator referenced by community deobfuscation prompts; output format not verified.',
    techniques: [],
    sources: [],
  },
};

export const TRAITS = {
  minified: 'Source is minified (long lines, no comments, no indentation).',
  'mangled-names': 'Most identifiers are machine generated.',
  'escape-encoded-strings': 'String literals are mostly numeric escapes.',
  'loadstring-layer': 'The script builds code at run time and passes it to load/loadstring.',
  'bytecode-blob': 'Contains a compiled Lua chunk (string.dump output).',
  'state-machine': 'Contains a flattened dispatcher loop (control-flow flattening or a register VM).',
  'string-table': 'Strings are kept in a table and fetched through an accessor.',
  'opaque-predicates': 'Branches whose condition is a constant arithmetic identity.',
  'junk-code': 'Statements that have no effect were inserted.',
};
