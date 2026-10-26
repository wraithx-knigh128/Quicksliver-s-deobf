// The help dialog: written for someone who has an obfuscated script and wants it readable, not for someone who knows
// what an AST is. It lists what every button does and, just as plainly, what it cannot do.

import { h, modal } from './dom.js';

const row = (name, text) => h('tr', h('th', { scope: 'row' }, name), h('td', text));

export function showHelp() {
  return modal({
    title: 'How to use QuickSilver',
    body: h('div.help', [
      h('h3', '1. Put your script in'),
      h('p', 'Paste it in the top editor (Obfuscated source), press Open File, drop a .lua / .luau / .txt file on the page, or use From link (raw GitHub, Pastebin, rentry, a Discord attachment). Load example opens a ready-made obfuscated script. It stays in your browser. Nothing is run.'),
      h('h3', '2. Press Deobfuscate'),
      h('p', 'QuickSilver works out what protects the script and writes the readable version in the bottom editor (Deobfuscated source). The strip under the editors says what it found, how sure it is and how long it took. The clock in the title bar shows the time of the running operation and then of the last one.'),
      h('h3', '3. Check and save'),
      h('p', 'Compare puts the two versions side by side. Export saves the result, a report or a zip with everything. Drag the divider between the editors to resize them, or press the arrows button of one editor to give it the whole height.'),
      h('h3', 'The Examples tab'),
      h('p', 'Lists every bundled example by the obfuscator that made it. Time all recovers each one in turn and shows how long it took and what came out, next to what the offline test suite measured for it.'),
      h('h3', 'If you already know the obfuscator'),
      h('table.help-table', h('tbody', [
        row('IronBrew', 'IronBrew 2: the original program is rebuilt from the virtual machine. IronBrew 1 is not supported.'),
        row('Luraph', 'Luraph v14 / v15 turns a script into a private virtual machine and nobody can turn that back into the source automatically. This button runs the script in QuickSilver’s own sandbox (it asks first), captures the text the script builds and loads, and lists what it does. Heavy scripts can run out of budget and give a partial result.'),
        row('MoonVeil', 'Rebuilds the program from the virtual machine\u2019s own data (nothing is run), with a progress bar; it takes a few seconds. If this build cannot be read that way, it says why and offers the sandbox, which asks first.'),
      ])),
      h('h3', 'Tools'),
      h('table.help-table', h('tbody', [
        row('Detect', 'Names the obfuscator and the language dialect.'),
        row('Beautify', 'Only re-indents the code. Nothing is decoded.'),
        row('Rename', 'Gives machine-made variable names readable ones.'),
        row('Dump', 'Runs the script in the sandbox (it asks first) and captures what it loads or joins with table.concat.'),
        row('Origin check', 'Estimates how much the code reads like AI-written code and how much of it looks copied. It is a guess from style and, if you allow it, from a search for the same lines on GitHub. It is never proof.'),
      ])),
      h('p.note.warn', 'Use QuickSilver only on scripts you own or are allowed to analyse.'),
    ]),
  });
}
