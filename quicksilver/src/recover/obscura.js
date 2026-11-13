// Obscura's anti-tamper guards, recognised and taken off.
//
// Obscura (https://github.com/vo3pal/obscura, MIT) puts a run of environment checks at the top of its Luau output. Each one is an `if` that
// raises an empty error when the script is not running where an unmodified Roblox client would run it:
//
//     if typeof == nil or game == nil then error("") end
//     if not pcall(function() return game:GetService("RunService") end) then error("") end
//     local v = type
//     if v(getgenv) ~= v(nil) then error("") end                -- an executor's API is visible: the script is being run under an exploit
//     if v(print) ~= v(function() end) then error("") end       -- print was replaced by a Lua function
//     if tostring(print) ~= str then error("") end
//
// Revisions before 1.1.0 say the same with a message (`error("Security violation")`) and put the integrity check in a `do` block.
//
// They are not part of the program that was obfuscated, so the recovered program has none. A guard is taken off only when the run as a whole is
// recognisably this one: at least two of those `if error("")` tests, and among them one that probes for an executor-only global. A script's
// own `if game == nil then error("") end` is a guard too, but nothing marks it as an injected one, so it stays.

const EXECUTOR_GLOBALS = new Set([
  'getgenv', 'getrenv', 'getreg', 'getgc', 'hookfunction', 'hookmetamethod', 'fireclickdetector', 'fireproximityprompt', 'firetouchinterest', 'getrawmetatable',
  'setrawmetatable', 'newcclosure', 'checkcaller', 'setreadonly', 'isreadonly', 'getnamecallmethod', 'setnamecallmethod', 'iscclosure', 'islclosure',
  'loadfile', 'readfile', 'writefile', 'syn', 'identifyexecutor', 'getexecutorname', 'request', 'http_request',
]);

/** `if <test> then error(...) end` with no other branch and nothing else in it. */
function isErrorGuard(s) {
  if (s.type !== 'If' || s.clauses.length !== 1 || (s.orelse && s.orelse.length)) return false;
  const body = s.clauses[0].body;
  if (body.length !== 1 || body[0].type !== 'CallStmt') return false;
  const call = body[0].call;
  if (call.type !== 'Call' || call.fn.type !== 'Name' || call.fn.name !== 'error') return false;
  // the message is a constant: empty in 1.1.0, "Security violation", "Environment tampered", ... in 1.0.x
  return call.args.length === 0 || (call.args.length === 1 && call.args[0].type === 'String');
}

/** The names the test mentions (globals, aliases and function-valued probes alike). */
function names(node) {
  const out = new Set();
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    if (n.type === 'Name') out.add(n.name);
    for (const k of Object.keys(n)) if (k !== 'line' && k !== 'comments' && k !== 'trailing' && n[k] && typeof n[k] === 'object') visit(n[k]);
  };
  visit(node);
  return out;
}

/** A top-level local that only copies or inspects a global (`local v = type`, `local s = tostring(print)`): the helper a guard uses. */
function isGuardHelper(s) {
  if (s.type !== 'Local' || s.ids.length !== 1 || s.values.length !== 1) return false;
  const e = s.values[0];
  if (e.type === 'Name') return true;
  return e.type === 'Call' && e.fn.type === 'Name' && e.args.every((a) => a.type === 'Name' || a.type === 'String' || a.type === 'Number');
}

/** An error guard, a helper local, or a `do` block made of nothing else. */
const isGuardStatement = (s) => isErrorGuard(s) || isGuardHelper(s) || (s.type === 'Do' && s.body.length > 0 && s.body.every(isGuardStatement));

/** The error guards inside a statement (the statement itself, or those of a `do` block made of guards). */
function guardsIn(s) {
  if (isErrorGuard(s)) return [s];
  if (s.type === 'Do') return s.body.flatMap(guardsIn);
  return [];
}

export function removeObscuraGuards(chunk) {
  const body = chunk.body;
  const found = [];            // the statements of the prefix that hold guards
  let end = 0;
  for (let i = 0; i < body.length; i++) {
    const s = body[i];
    if (!isGuardStatement(s)) break;
    if (guardsIn(s).length) { found.push(i); end = i + 1; }
  }
  const guards = found.flatMap((i) => guardsIn(body[i]));
  if (guards.length < 2) return { changed: 0 };
  const probes = guards.some((g) => [...names(g.clauses[0].cond)].some((n) => EXECUTOR_GLOBALS.has(n)));
  if (!probes) return { changed: 0 };
  const drop = new Set(found);
  // helpers the guards used are left for the dead-code pass: removing a local that something later still reads would be wrong
  chunk.body = body.filter((_, i) => !(drop.has(i) && i < end));
  return { changed: guards.length };
}
