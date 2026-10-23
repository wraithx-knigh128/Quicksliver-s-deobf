// File input and output. Only plain text sources are accepted (.lua, .luau, .txt); anything else is refused
// with a reason instead of being decoded into noise.

export const ACCEPTED = ['.lua', '.luau', '.txt'];
export const MAX_FILE_BYTES = 16 * 1024 * 1024;

export class FileRejected extends Error {}

export function checkFile(file) {
  const dot = file.name.lastIndexOf('.');
  const ext = dot >= 0 ? file.name.slice(dot).toLowerCase() : '';
  if (!ACCEPTED.includes(ext)) throw new FileRejected(`"${file.name}" is not supported. Open a ${ACCEPTED.join(', ')} file or paste the code.`);
  if (file.size > MAX_FILE_BYTES) throw new FileRejected(`"${file.name}" is ${(file.size / 1048576).toFixed(1)} MiB; the limit is ${MAX_FILE_BYTES / 1048576} MiB.`);
}

/** @returns {Promise<Uint8Array>} */
export async function readFileBytes(file) {
  checkFile(file);
  return new Uint8Array(await file.arrayBuffer());
}

export function download(name, data, type = 'text/plain') {
  const blob = new Blob([data], { type: `${type};charset=utf-8` });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  a.rel = 'noopener';
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}

/** "My Script.lua" -> "My_Script" (safe for a download name) */
export function baseName(name) {
  return (name || 'script').replace(/\.[^.]*$/, '').replace(/[^\w.-]+/g, '_').slice(0, 60) || 'script';
}
