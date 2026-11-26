// Which engine reconstructs a detected format (Prompt XXIX). The one Deobfuscate pipeline (unified.js) asks this after detection; the
// person never chooses. An adapter exists only for a format where a measured, verified implementation does better than QuickSilver's own
// passes (docs/REPORT-XXIX.md has the measurements); everything else goes to QuickSilver's own recovery, which is also the fallback when an
// adapter's engine fails or is not available on the deployment.
//
// Contract of an adapter:
//   id, family (the detection id it serves), minConfidence, where ('server': api/engine.js runs it), output ('lua51-bytecode': the page
//   decompiles it with QuickSilver's own decompiler), label (the step's name in the report), licence (said in every result it produces),
//   verify (what the behaviour comparison must know about the format's own runtime: events the protected original makes before the program
//   starts, and whether an original that only runs as a callback can be a reference; `required`: the engine's program is used only when a
//   comparison with the script itself is identical and reaches `minCoverage` of the program), rules (the detection rules that must be
//   among the family's evidence), when ('own-result-keeps-vm': QuickSilver's own passes run first and the engine is asked only when their
//   result still carries the family's protection).

export const ADAPTERS = Object.freeze([
  {
    id: 'moonsec-v3',
    family: 'moonsec_v3',
    familyLabel: 'MoonSec V3',
    minConfidence: 0.5,
    where: 'server',
    output: 'lua51-bytecode',
    label: 'Rebuild the MoonSec V3 program (server engine: moonsec-deobfuscator-js)',
    licence: 'GPL-3.0: moonsec-deobfuscator-js, a port of tupsutumppu/MoonsecDeobfuscator (modified; api/_engine/moonsec/NOTICE.md)',
    // MoonSec V3's runtime calls wait() once before the program starts (seen in 102 of 120 sampled originals, in none of the rebuilt
    // programs); an original whose main chunk does nothing and runs only as a callback with stand-in arguments is no reference.
    // Prompt XXX: its runtime also writes two globals the program does not: the name its banner line assigns
    // (`([[This file was protected with MoonSec V3]]):gsub('.+', (function(a) _xxxx = a; end))`) and MoonSec_StringsHiddenAttr — in the
    // 120 sampled originals, every keyless one that ran wrote both, and no rebuilt program writes either.
    verify: {
      originalPrelude: ['wait()'],
      needsMainReference: true,
      // (the banner text varies — "… with MoonSec V3 by <name> on discord" — the pattern matches all 792 files of the public collection)
      runtimeGlobals: { names: ['MoonSec_StringsHiddenAttr'], fromSource: ["protected with MoonSec V3[^\\]]*\\]\\]\\):gsub\\('\\.\\+', \\(function\\(a\\) ([A-Za-z_][A-Za-z0-9_]*) = a; end\\)\\)"] },
    },
  },
  {
    // Prometheus' Vmify step (also in its Weak, Medium and Strong presets). QuickSilver's own passes lift some of these VMs; on its 53
    // VM fixtures they left the VM in place in 40. The vendored engine lifts more of them but is wrong on some, so it is asked only when
    // QuickSilver's own result still carries Prometheus protection, and its program is used only when a behaviour comparison with the script itself agrees
    // over at least half the program (on the fixtures: every one of its 31 faithful programs passed, none of its 6 wrong ones did).
    id: 'prometheus-vm',
    family: 'prometheus',
    familyLabel: 'Prometheus (Vmify)',
    rules: ['vmify-wrapper'],
    minConfidence: 0.5,
    where: 'server',
    when: 'own-result-keeps-vm',
    output: 'lua-source',
    label: 'Lift the Prometheus VM (server engine: Prometheus Deobfuscator by LeakD)',
    licence: 'MIT: Prometheus Deobfuscator by LeakD (modified; api/_engine/prometheus/NOTICE.md)',
    verify: { required: true, minCoverage: 0.5 },
  },
]);

/** The adapter for what detection found, or null (QuickSilver's own recovery handles it). */
export function selectAdapter(detection) {
  const fams = (detection && detection.families) || [];
  for (const a of ADAPTERS) {
    const f = fams.find((x) => x.id === a.family);
    if (f && f.confidence >= a.minConfidence && (!a.rules || (f.evidence || []).some((e) => a.rules.includes(e.rule)))) return a;
  }
  return null;
}
