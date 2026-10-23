// Recovery modules for Hercules (https://github.com/zeusssz/hercules-obfuscator).
//
// Patterns come from the Hercules source (src/modules/*.lua) and were checked against its real output
// in tests/corpus/obfuscated/hercules.

import { transform, walk } from '../core/walk.js';

/**
 * modules/antitamper.lua prepends
 *   do local _BFR, _MFR, T, E, Pa, GM, RG = {...}, {...}, type, error, pairs, getmetatable, rawget
 *      ... local function check() ... error("Tamper Detected! Reason: ...") ... end  check() end
 * The block only verifies that standard functions are intact; it contributes nothing to the program.
 */
function isAntiTamperBlock(stmt) {
  if (stmt.type !== 'Do') return false;
  let hasTable = false;
  let marker = false;
  walk(stmt, (n) => {
    if (n.type === 'Id' && n.name === '_BFR') hasTable = true;
    if (n.type === 'String' && n.value.startsWith('Tamper Detected! Reason:')) marker = true;
  });
  return hasTable && marker;
}

export function removeHerculesAntiTamper(chunk) {
  let removed = 0;
  transform(chunk, {
    block(stmts) {
      if (!stmts.some(isAntiTamperBlock)) return undefined;
      const out = stmts.filter((s) => !isAntiTamperBlock(s));
      removed += stmts.length - out.length;
      return out;
    },
  });
  return { changed: removed };
}
