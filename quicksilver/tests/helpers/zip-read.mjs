// Reads a ZIP through its central directory, verifying every CRC, the way an unzip tool does.
import { crc32 } from '../../src/app/zip.js';

export function readZip(bytes) {
  const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const eocd = bytes.length - 22;
  if (dv.getUint32(eocd, true) !== 0x06054b50) throw new Error('no end-of-central-directory record');
  const count = dv.getUint16(eocd + 10, true);
  let p = dv.getUint32(eocd + 16, true);
  const out = {};
  for (let i = 0; i < count; i++) {
    if (dv.getUint32(p, true) !== 0x02014b50) throw new Error('bad central directory entry');
    const crc = dv.getUint32(p + 16, true);
    const size = dv.getUint32(p + 24, true);
    const nameLen = dv.getUint16(p + 28, true);
    const extraLen = dv.getUint16(p + 30, true);
    const commentLen = dv.getUint16(p + 32, true);
    const lho = dv.getUint32(p + 42, true);
    const name = new TextDecoder().decode(bytes.subarray(p + 46, p + 46 + nameLen));
    const lname = dv.getUint16(lho + 26, true);
    const lextra = dv.getUint16(lho + 28, true);
    const data = bytes.subarray(lho + 30 + lname + lextra, lho + 30 + lname + lextra + size);
    if (crc32(data) !== crc) throw new Error(`crc mismatch in ${name}`);
    out[name] = data;
    p += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}
