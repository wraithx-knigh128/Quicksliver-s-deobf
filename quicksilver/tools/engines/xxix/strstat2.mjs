const fs = await import('node:fs');
const [Q, tsv] = process.argv.slice(2);
const { parseChunk } = await import(Q + '/src/sandbox/bytecode.js');
const S = tsv.replace(/\/keys\.tsv$/, '');
const printable = (s) => /^[\t\n\r\x20-\x7e]*$/.test(s) || (() => { try { const b = Buffer.from(s, 'latin1'); return new TextDecoder('utf-8', { fatal: true }).decode(b) && !/[\x00-\x08\x0e-\x1f]/.test(s); } catch { return false; } })();
const t = { marked: 0, shiftPrintable: 0, shiftIdent: 0, verbatimPrintable: 0, unmarked: 0, unmarkedPrintable: 0, files: 0, filesAllOk: 0 };
const samples = [];
for (const line of fs.readFileSync(tsv, 'utf8').trim().split('\n')) {
  const [f, j] = line.split('\t'); if (j === 'null') continue;
  const k = JSON.parse(j); if (k.keyExpressions < 2) continue;
  const bc = `${S}/ms-bc/${f.replace(/\//g, '_')}.luac`; if (!fs.existsSync(bc)) continue;
  let ch; try { ch = parseChunk(fs.readFileSync(bc, 'latin1')); } catch { continue; }
  t.files++; let bad = 0;
  const walk = (p) => { for (const c of p.constants || p.k || []) { const v = c && typeof c === 'object' && 'value' in c ? c.value : c; if (typeof v !== 'string' || !v.length) continue;
    if (v.charCodeAt(0) >= 128 && v.length > 1) { t.marked++; let o = ''; for (let i = 1; i < v.length; i++) o += String.fromCharCode((v.charCodeAt(i) + k.constantKey) % 256);
      if (printable(o)) t.shiftPrintable++; else { bad++; if (samples.length < 6) samples.push([f.slice(-21), JSON.stringify(o).slice(0, 60)]); }
      if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(o)) t.shiftIdent++; if (printable(v)) t.verbatimPrintable++; }
    else { t.unmarked++; if (printable(v)) t.unmarkedPrintable++; } }
    for (const q of p.protos || p.p || []) walk(q); };
  walk(ch.main); if (!bad) t.filesAllOk++;
}
console.log(JSON.stringify(t)); console.log(samples);
