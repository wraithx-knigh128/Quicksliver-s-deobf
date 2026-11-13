// What a script is made of, when no tool is known to have made it.
//
// A signature says "this is tool X". A script that no signature matches is still something: a loader that downloads its program, a minified script
// that was never obfuscated, a program kept as an array of numbers and run through `loadstring`, a state machine, a table of encrypted strings. The
// collection measured in docs/COMPATIBILITY.md has hundreds of such files (its "Unknown", "VM Compressed" and "MinifiedLua" folders are mostly these), and
// "unidentified" was all the detector had to say about them. This says what they are, from the syntax tree and the traits the detector already has,
// and what is and is not recoverable from the file alone. Every parsed script gets at least one class; none of them is a claim about which tool.

const FETCH = new Set(['HttpGet', 'HttpGetAsync']);
const LOAD = new Set(['load', 'loadstring']);

const unparen = (e) => (e && e.type === 'Paren' ? unparen(e.expr) : e);

/** Does the expression contain a network fetch (`game:HttpGet(url)`, `game.HttpGet(game, url)`)? Returns the URL literals it passes. */
function fetches(e) {
  const urls = [];
  let found = false;
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    if ((n.type === 'MethodCall' && FETCH.has(n.name)) || (n.type === 'Call' && n.fn && n.fn.type === 'Index' && n.fn.key && n.fn.key.type === 'String' && FETCH.has(n.fn.key.value))) {
      found = true;
      const args = n.type === 'MethodCall' ? n.args : n.args.slice(1);
      for (const a of args) { const u = unparen(a); if (u && u.type === 'String' && /^https?:\/\//i.test(u.value)) urls.push(u.value); }
    }
    for (const k of Object.keys(n)) if (k !== 'line' && k !== 'comments' && k !== 'trailing' && n[k] && typeof n[k] === 'object') visit(n[k]);
  };
  visit(e);
  return { found, urls };
}

/** `loadstring(<fetch>)` possibly called on the spot: the URLs, or null. */
function remoteLoad(e) {
  const x = unparen(e);
  if (!x || x.type !== 'Call') return null;
  const inner = unparen(x.fn);
  const target = inner && inner.type === 'Call' ? inner : x;               // loadstring(...)()  or  loadstring(...)
  if (!target.fn || target.fn.type !== 'Name' || !LOAD.has(target.fn.name) || !target.args.length) return null;
  const f = fetches(target.args[0]);
  return f.found ? f.urls : null;
}

/** A statement that only fetches and runs code: `loadstring(game:HttpGet(url))()`, `local lib = loadstring(...)()`, `return loadstring(...)()`. */
function loaderStatement(s) {
  if (s.type === 'CallStmt') return remoteLoad(s.call);
  if (s.type === 'Return' && s.values.length === 1) return remoteLoad(s.values[0]);
  if (s.type === 'Local' && s.values.length >= 1 && s.values.every((v) => remoteLoad(v))) return s.values.flatMap((v) => remoteLoad(v));
  if (s.type === 'Assign' && s.values.length >= 1 && s.values.every((v) => remoteLoad(v))) return s.values.flatMap((v) => remoteLoad(v));
  return null;
}

/** A configuration statement a loader may carry: `getgenv().Key = "x"`, `_G.Flag = true`, `Settings = { ... }` of literals. */
function isConfigStatement(s) {
  const literal = (e) => {
    const x = unparen(e);
    if (!x) return false;
    if (['String', 'Number', 'True', 'False', 'Nil'].includes(x.type)) return true;
    if (x.type === 'Unary') return literal(x.arg);
    if (x.type === 'Table') return x.fields.every((f) => literal(f.value) && (f.kind !== 'keyed' || literal(f.key)));
    return false;
  };
  if (s.type === 'Assign') return s.values.every(literal);
  if (s.type === 'Local') return s.values.every(literal);
  return false;
}

export function classify(source, ast, det) {
  const classes = [];
  const add = (id, label, confidence, evidence, recovery, note) => classes.push({ id, label, confidence, evidence, recovery, note });
  const known = (det.families || []).some((f) => f.confidence >= 0.5);
  const traitIds = new Set((det.traits || []).map((t) => t.id));
  if (!ast) {
    // text that does not parse: say what it still shows
    if (det.bytecode) add('bytecode', 'compiled Lua chunk', 0.9, [`the text is a ${det.bytecode.format || 'compiled'} Lua chunk`], 'partial', 'A compiled chunk is decompiled, not parsed.');
    else add('not-lua', 'text that is not Lua source', 0.6, [det.parseError ? `parse error: ${det.parseError.message}` : 'it does not parse'], 'none', 'Nothing can be reconstructed from text that does not parse; check the encoding or whether the file is a different dialect.');
    return classes;
  }

  const body = ast.body || [];
  // 1. a pure remote loader
  const urls = [];
  let loaders = 0;
  let other = 0;
  for (const s of body) {
    const u = loaderStatement(s);
    if (u) { loaders++; urls.push(...u); } else if (!isConfigStatement(s)) other++;
  }
  if (loaders > 0 && other === 0 && body.length <= 16) {
    add('remote-loader', 'a loader: the program it runs is downloaded when it runs', 0.95,
      [`${loaders} statement${loaders === 1 ? '' : 's'} of the form loadstring(<network request>)()`, ...[...new Set(urls)].slice(0, 6).map((u) => `fetches ${u}`)],
      'none', 'The program is not in this file, and QuickSilver does not fetch it. Fetch it yourself and paste it in to analyse it.');
  }

  // 2. a service-bound bootstrap (a script that downloads its real init from a licensing / key service and caches it)
  if (/\bwritefile\b[\s\S]{0,400}\bloadstring\b/.test(source) && /\bHttpGet\b/.test(source) && /\breadfile\b/.test(source) && source.length < 6000 && !classes.length) {
    add('cached-remote-loader', 'a loader that downloads its init script, caches it with writefile and runs it', 0.8,
      ['reads a cached copy with readfile, otherwise downloads with HttpGet, writes the copy and runs it with loadstring'], 'none', 'The program is fetched at run time; it is not in this file.');
  }

  if (!known && !classes.length) {
    // 3. a program kept as an array of numbers and handed to loadstring
    const arrays = body.filter((s) => (s.type === 'Local' || s.type === 'Assign') && s.values.some((v) => v.type === 'Table' && v.fields.length >= 24 && v.fields.every((f) => f.kind === 'item' && unparen(f.value).type === 'Number')));
    if (arrays.length && traitIds.has('loadstring-layer')) {
      add('numeric-array-loader', 'a program stored as an array of numbers, decoded when it runs and handed to loadstring', 0.8,
        [`a table of ${arrays[0].values[0].fields.length} numbers and a call to loadstring/load`], 'partial', 'If the decoder is made only of arithmetic and string functions it can be run in the sandbox; the encoding is not one a rule knows.');
    }
    // 4. a spelled-out entry: T,I,G,E,R,A,D,M,I,N = ..., a multiple assignment to single-letter names whose first value computes the loader
    // (capital letters: a minifier's `local a, b, c, d, e, f = ...` is lower case and is not a credit)
    const spelled = body.find((s) => (s.type === 'Assign' && s.targets.length >= 6 && s.targets.every((t) => t.type === 'Name' && /^[A-Z]$/.test(t.name)))
      || (s.type === 'Local' && s.ids.length >= 6 && s.ids.every((i) => /^[A-Z]$/.test(i.name))));
    if (spelled) {
      const names = (spelled.targets || spelled.ids).map((t) => t.name).join('');
      add('credit-entry', `a script entered through a multiple assignment that spells "${names}"`, 0.7,
        [`${names.length} one-letter names assigned at once at the top of the file`, ...(traitIds.has('minified') ? ['minified'] : [])], 'partial', 'The letters are a credit string; the loader around them hides a request or a decoder.');
    }
    // 5. structural traits
    if (traitIds.has('state-machine')) add('state-machine', 'control flow rewritten as a loop over a state variable', 0.8, ['a loop selects among blocks by the value of one variable'], 'partial', 'The adaptive engine follows the states and writes the blocks back as structured code where the next state is a constant.');
    if (det.bytecode) add('bytecode', 'compiled Lua chunk in a string', 0.8, ['a string holds a compiled Lua chunk'], 'partial', 'A compiled chunk is decompiled, not parsed.');
    if (traitIds.has('string-table')) add('string-table', 'strings kept in a table that is shuffled or decoded at start-up', 0.7, ['a rotation loop over a table of strings'], 'partial', 'The sandbox evaluates the decoder when it is made of standard functions.');
    if (traitIds.has('escape-encoded-strings')) add('encoded-strings', 'string literals written as escape sequences', 0.6, ['a large share of the string bytes are \\ddd escapes'], 'full', 'Escapes are plain text once parsed.');
    if (traitIds.has('loadstring-layer') && /\bHttpGet(?:Async)?\b/.test(source) && !classes.some((c) => c.id === 'numeric-array-loader')) {
      const libs = [...new Set([...source.matchAll(/HttpGet(?:Async)?\s*\(\s*\(?\s*["'](https?:\/\/[^"']{4,})["']/g)].map((m) => m[1]))].slice(0, 6);
      add('remote-library-script', 'a script with logic of its own that also downloads and runs code (usually a UI library) when it runs', 0.8,
        ['calls loadstring on the result of an HttpGet', ...libs.map((u) => `fetches ${u}`)], 'full', 'The script\u2019s own code is plain and is shown as it is; the downloaded code is not in the file and is not fetched.');
    } else if (traitIds.has('loadstring-layer') && !classes.some((c) => c.id === 'numeric-array-loader')) add('dynamic-loader', 'code handed to load/loadstring at run time', 0.6, ['a call to load or loadstring'], 'partial', 'The sandbox runs the script until the first chunk is handed to load when the script is only a loader.');
    // 6. nothing obfuscated about it
    if (!classes.length) {
      if (traitIds.has('minified') || traitIds.has('mangled-names')) add('minified-script', 'a minified script with no obfuscation layer recognised', 0.75, [traitIds.has('mangled-names') ? 'short or machine-like names' : 'very long lines', 'no encoded strings, state loops or loaders'], 'full', 'Formatting and naming are what can be recovered; names that were lost stay lost.');
      else add('plain-script', 'an ordinary script: nothing in it is obfuscated', 0.75, ['readable names, no encoded strings, no state loops or loaders'], 'full', 'It is shown formatted; there is nothing to recover.');
    }
  } else if (known && !classes.length) {
    add('known-tool', 'output of a tool a rule recognises', 0.9, det.families.filter((f) => f.confidence >= 0.5).map((f) => `${f.name}${f.version ? ` ${f.version}` : ''} (${f.confidence.toFixed(2)})`), 'see the compatibility matrix', 'What can be recovered depends on the tool and version.');
  }
  return classes;
}
