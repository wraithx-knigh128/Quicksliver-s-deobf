// User settings. Stored in localStorage when available; the page works the same without it.

const KEY = 'qs.settings.v1';

export const DEFAULTS = Object.freeze({
  indent: '2',            // '2' | '4' | 'tab'
  width: 100,
  rename: 'smart',        // 'smart' | 'all' | 'off'
  foldCalls: 'obfuscation',
  stringStyle: 'normalize',
  maxRounds: 8,
  sandbox: false,         // opt-in: evaluate string decoders in the interpreter sandbox
  sandboxFuel: 60_000_000,
  sandboxTimeMs: 10_000,
  compareAgainst: 'formatted', // 'formatted' | 'raw'
  sidebar: true,
  inspector: true,
});

export function loadSettings() {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return { ...DEFAULTS };
    const parsed = JSON.parse(raw);
    const out = { ...DEFAULTS };
    for (const k of Object.keys(DEFAULTS)) if (typeof parsed[k] === typeof DEFAULTS[k]) out[k] = parsed[k];
    out.width = Math.min(240, Math.max(40, Math.round(out.width)));
    out.maxRounds = Math.min(20, Math.max(1, Math.round(out.maxRounds)));
    out.sandboxFuel = Math.min(500_000_000, Math.max(100_000, Math.round(out.sandboxFuel)));
    out.sandboxTimeMs = Math.min(60_000, Math.max(500, Math.round(out.sandboxTimeMs)));
    return out;
  } catch {
    return { ...DEFAULTS };
  }
}

export function saveSettings(settings) {
  try { localStorage.setItem(KEY, JSON.stringify(settings)); } catch { /* private mode or blocked storage: keep going */ }
}

export const indentString = (s) => (s.indent === 'tab' ? '\t' : ' '.repeat(Number(s.indent) || 2));

export function recoverOptions(s, { allowSandbox }) {
  return {
    rename: s.rename,
    foldCalls: s.foldCalls,
    stringStyle: s.stringStyle,
    maxRounds: s.maxRounds,
    sandbox: { enabled: allowSandbox && s.sandbox, fuel: s.sandboxFuel, timeMs: s.sandboxTimeMs },
  };
}
