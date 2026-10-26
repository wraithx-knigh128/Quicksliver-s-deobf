// The report in front of an incomplete recovery, and the honesty rules behind it: a result that still holds a virtual machine is never called
// recovered, a complete one carries no report, a report is replaced and not stacked, and cut-off input is refused with a position instead of
// being guessed at.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { recover } from '../src/recover/pipeline.js';
import { parse } from '../src/core/parser.js';
import { detectScript, recoverSource, beautifyScript } from '../src/api.js';
import { buildReport, annotate, stripReport } from '../src/recover/annotate.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const sample = (f) => fs.readFileSync(path.join(here, '..', 'data', 'samples', f), 'latin1');
const nested = (f) => fs.readFileSync(path.join(here, 'corpus', 'obfuscated', 'prometheus-nested', f), 'latin1');

// virtual machines the engine detects and does not rebuild (documented in README.md)
const UNRECOVERED_VMS = [
  'hercules__s06_combined__virtual_machine.lua',
  'zenfus__s06_combined__default.lua',
  'azurevm__s06_combined__Fast.lua',
  'clyde__s06_combined__vm.lua',
];

for (const f of UNRECOVERED_VMS) {
  test(`${f}: a VM that stays is reported as partial, in the result and in the file`, () => {
    const r = recover(sample(f), {});
    assert.equal(r.ok, true);
    assert.notEqual(r.confidence.level, 'high', 'a script that still holds its VM must not rate as recovered');
    assert.equal(r.report.show, true);
    assert.match(r.report.label, /^PARTIAL/);
    assert.match(r.output, /^-- QuickSilver recovery report\n/);
    assert.match(r.output.split('\n').slice(0, 4).join('\n'), /PARTIAL/);
    assert.ok(r.report.unresolved.length > 0, 'it says what is left');
    // the report is comments: the file is still a program, and the code after it is the code that was recovered
    assert.doesNotThrow(() => parse(r.output));
    const plain = recover(sample(f), { annotate: false });
    assert.equal(r.output.endsWith(plain.output), true);
    assert.doesNotMatch(plain.output, /QuickSilver recovery report/);
  });
}

test('a complete recovery carries no report', () => {
  const r = recover(nested('seed-1337/n01_nested_loops__Medium.lua'), { sandbox: { enabled: true } });
  assert.equal(r.confidence.level, 'high');
  assert.equal(r.report.show, false);
  assert.doesNotMatch(r.output, /QuickSilver recovery report/);
});

test('recovering a result again replaces its report', () => {
  const first = recover(sample('zenfus__s06_combined__default.lua'), {});
  const second = recover(first.output, {});
  assert.equal(second.output.split('QuickSilver recovery report').length - 1, 1);
  assert.equal(second.output.split('(end of report)').length - 1, 1);
  assert.ok(second.output.startsWith('-- QuickSilver recovery report'));
});

test('stripReport and annotate undo each other and leave other text alone', () => {
  const report = { show: true, lines: ['-- QuickSilver recovery report', '-- Result: PARTIAL', '-- (end of report)'] };
  const text = annotate('print(1)\n', report);
  assert.equal(stripReport(text), 'print(1)\n');
  assert.equal(stripReport('print(1)\n'), 'print(1)\n');
  assert.equal(stripReport('-- QuickSilver recovery report\nno end marker'), '-- QuickSilver recovery report\nno end marker');
  assert.equal(annotate('x', { show: false, lines: [] }), 'x');
});

test('the report only repeats what the run measured', () => {
  const r = recover(sample('zenfus__s06_combined__default.lua'), {});
  const text = r.output.split('(end of report)')[0];
  for (const u of r.report.unresolved) assert.ok(text.replace(/\n--\s+/g, ' ').includes(u.text.slice(0, 40)), `"${u.text}" is in the report`);
  for (const s of r.report.applied) assert.ok(text.includes(s.id), `step ${s.id} is named`);
  assert.ok(text.split('\n').every((l) => l.length <= 140), 'lines stay readable');
});

test('buildReport lists a leftover interpreter of a rebuilt program, not what the program itself does', () => {
  const confidence = { level: 'medium', score: 0.75, reasons: [{ effect: 0, text: 'checked' }] };
  const adaptive = {
    observeOnly: true,
    residual: [
      { kind: 'dynamic-code', line: 3, label: 'code is built at run time', reason: 'looked at only', weight: 3 },
      { kind: 'interpreter', line: 9, label: 'a loop fetches an instruction', reason: 'data for an interpreter that ships with it', weight: 12 },
      { kind: 'remote-loader', line: 20, label: 'fetched code', reason: 'not in this file', weight: 0 },
    ],
  };
  const rep = buildReport({ detection: { families: [] }, steps: [], confidence, adaptive });
  assert.deepEqual(rep.unresolved.map((u) => u.kind), ['interpreter']);
  assert.ok(rep.lines.some((l) => /Fetched when the script runs/.test(l)));
});

// ---- cut-off input --------------------------------------------------------------------------------------------------------

const CUTS = [
  ['a Prometheus program', nested('seed-1337/n01_nested_loops__Medium.lua')],
  ['an IronBrew 2 program', sample('ironbrew2__s06_combined__default.lua')],
  ['a Zenfus VM', sample('zenfus__s06_combined__default.lua')],
  ['a Hercules program', sample('hercules__s06_combined__garbage_code.lua')],
];

for (const [name, text] of CUTS) {
  for (const frac of [0.3, 0.9, 0.995]) {
    test(`${name} cut off at ${Math.round(frac * 1000) / 10}%: refused with a position, nothing thrown, nothing invented`, () => {
      const cut = text.slice(0, Math.floor(text.length * frac));
      const r = recoverSource(cut, {});
      assert.equal(r.ok, false);
      assert.equal(r.stage, 'parse');
      assert.equal(r.output, null, 'no recovered text is made up from half a program');
      assert.ok(Number.isInteger(r.error.line) && Number.isInteger(r.error.col), JSON.stringify(r.error));
      const d = detectScript(cut);
      assert.equal(d.ok, true);
      assert.equal(d.detection.parsed, false);
      assert.ok(d.detection.parseError && d.detection.parseError.message);
      const b = beautifyScript(cut);
      assert.ok(b.ok === false || b.mode === 'tokens', 'only the layout is repaired, and it says so');
    });
  }
}
