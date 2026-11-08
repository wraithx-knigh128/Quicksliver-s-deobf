// What a script looks like from the outside: the signature the advisor matches experiments against.
//
// It is made only of things a reader of the script can observe: the detector's traits and families, whether the comments are a split sentence, the
// structural features of features.js, and the families learned by the study framework. It is never made from knowing how a test program was
// transformed, so what the laboratory measures for a signature is what the page can look up for a real input.

import { parse, LuaSyntaxError } from '../core/parser.js';
import { detect } from '../detect/detect.js';
import { analyzeTrivia } from '../nexus/trivia.js';
import { extractFeatures } from './features.js';

/**
 * @param {string} source binary string
 * @param {{registry?: import('./families.js').FamilyRegistry}} [options]
 * @returns {{tokens: string[], parsed: boolean, features: string[], custom: string[]}}
 */
export function observe(source, { registry = null } = {}) {
  const tokens = new Set();
  let ast = null;
  try { ast = parse(source); } catch (e) { if (!(e instanceof LuaSyntaxError)) throw e; }
  if (!ast) return { tokens: ['syntax:invalid'], parsed: false, features: ['syntax:invalid'], custom: [] };
  const det = detect(source, ast);
  for (const t of det.traits) tokens.add(`trait:${t.id}`);
  for (const f of det.families) if (f.confidence >= 0.5) tokens.add(`family:${f.id}`);
  try { if (analyzeTrivia(source).verdict === 'fragmented-message') tokens.add('trivia:fragmented'); } catch { /* unreadable trivia adds nothing */ }
  const { features } = extractFeatures(source);
  for (const f of features) tokens.add(`f:${f}`);
  const custom = registry ? registry.match(features).map((m) => m.id) : [];
  for (const id of custom) tokens.add(`custom:${id}`);
  return { tokens: [...tokens].sort(), parsed: true, features: [...features].sort(), custom };
}

/** The observed tokens that are signs of obfuscation (as opposed to facts about any program, like a tail call). */
const INDICATORS = new Set([
  'trait:mangled-names', 'trait:escape-encoded-strings', 'trait:loadstring-layer', 'trait:bytecode-blob', 'trait:state-machine', 'trait:string-table',
  'trait:opaque-predicates', 'trait:junk-code', 'trait:compressed-payload', 'trivia:fragmented',
  'f:comments:dense', 'f:names:machine', 'f:strings:escaped', 'f:data:byte-table', 'f:data:byte-table-big', 'f:shape:state-loop', 'f:shape:decoder-loop',
  'f:shape:stream-arithmetic', 'f:shape:function-table', 'f:shape:proxy-functions', 'f:shape:vararg-wrapper', 'f:numbers:dense',
]);
export const isIndicator = (token) => INDICATORS.has(token) || token.startsWith('family:') || token.startsWith('custom:');

/** How many signs of obfuscation a list of observed tokens shows. */
export const opacity = (tokens) => tokens.filter(isIndicator).length;
