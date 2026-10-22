// Control characters are intentionally denied in filenames and text.
// deno-lint-ignore-file no-control-regex
export const MAX_FILE_BYTES = 3 * 1024 * 1024;
const types: Record<string, string[]> = {
  "image/jpeg": ["jpg", "jpeg"],
  "image/png": ["png"],
  "image/webp": ["webp"],
  "application/pdf": ["pdf"],
  "text/plain": ["txt"],
};
export class FileError extends Error {
  constructor(message: string, public status = 400) {
    super(message);
  }
}
const invalid = (): never => {
  throw new FileError("invalid_file");
};
function dimensions(w: number, h: number) {
  if (!w || !h || w > 8192 || h > 8192 || w * h > 32_000_000) invalid();
}
function ascii(bytes: Uint8Array, from = 0, to = bytes.length) {
  return Array.from(bytes.subarray(from, to), (b) => String.fromCharCode(b))
    .join("");
}
function png(b: Uint8Array, v: DataView) {
  if (ascii(b, 0, 8) !== "\x89PNG\r\n\x1a\n") invalid();
  let pos = 8, first = true, image = false, ended = false;
  while (pos + 12 <= b.length) {
    const len = v.getUint32(pos), type = ascii(b, pos + 4, pos + 8);
    if (pos + 12 + len > b.length || !/^[A-Za-z]{4}$/.test(type)) invalid();
    // Validate every chunk CRC, so damaged headers cannot become trusted metadata.
    let crc = 0xffffffff;
    for (let i = pos + 4; i < pos + 8 + len; i++) {
      crc ^= b[i];
      for (let j = 0; j < 8; j++) {
        crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
      }
    }
    if (((crc ^ 0xffffffff) >>> 0) !== v.getUint32(pos + 8 + len)) invalid();
    if (first) {
      if (type !== "IHDR" || len !== 13) invalid();
      dimensions(v.getUint32(pos + 8), v.getUint32(pos + 12));
      if (
        ![0, 2, 3, 4, 6].includes(b[pos + 17]) ||
        ![1, 2, 4, 8, 16].includes(b[pos + 16]) || b[pos + 18] || b[pos + 19] ||
        b[pos + 20] > 1
      ) invalid();
    } else if (type === "IHDR") invalid();
    first = false;
    if (type === "IDAT" && len) image = true;
    pos += len + 12;
    if (type === "IEND") {
      if (len || pos !== b.length) invalid();
      ended = true;
      break;
    }
  }
  if (!image || !ended) invalid();
}
function jpeg(b: Uint8Array, v: DataView) {
  if (
    b[0] !== 255 || b[1] !== 216 || b[b.length - 2] !== 255 ||
    b[b.length - 1] !== 217
  ) invalid();
  let p = 2, sized = false, scan = false;
  while (p < b.length - 2) {
    if (b[p++] !== 255) invalid();
    while (b[p] === 255) p++;
    const marker = b[p++];
    if (marker === 218) {
      scan = true;
      break;
    }
    if (p + 2 > b.length) invalid();
    const len = v.getUint16(p);
    if (len < 2 || p + len > b.length) invalid();
    if ([192, 193, 194].includes(marker)) {
      if (len < 8 || b[p + 2] !== 8) invalid();
      dimensions(v.getUint16(p + 5), v.getUint16(p + 3));
      sized = true;
    } else if (
      marker >= 195 && marker <= 207 && ![196, 200, 204].includes(marker)
    ) invalid();
    p += len;
  }
  if (!sized || !scan || p + 4 >= b.length) invalid();
}
function webp(b: Uint8Array, v: DataView) {
  if (
    b.length < 30 || ascii(b, 0, 4) !== "RIFF" || ascii(b, 8, 12) !== "WEBP" ||
    v.getUint32(4, true) + 8 !== b.length
  ) invalid();
  let p = 12, sized = false, image = false;
  while (p + 8 <= b.length) {
    const type = ascii(b, p, p + 4), len = v.getUint32(p + 4, true), d = p + 8;
    if (d + len + (len % 2) > b.length) invalid();
    if (type === "VP8X") {
      if (p !== 12 || len !== 10 || (b[d] & 2)) invalid(); // no animation in v1
      dimensions(
        1 + b[d + 4] + (b[d + 5] << 8) + (b[d + 6] << 16),
        1 + b[d + 7] + (b[d + 8] << 8) + (b[d + 9] << 16),
      );
      sized = true;
    } else if (type === "VP8 ") {
      if (len < 10 || (b[d] & 1) || ascii(b, d + 3, d + 6) !== "\x9d\x01\x2a") {
        invalid();
      }
      dimensions(
        v.getUint16(d + 6, true) & 16383,
        v.getUint16(d + 8, true) & 16383,
      );
      image = true;
      sized = true;
    } else if (type === "VP8L") {
      if (len < 5 || b[d] !== 47 || (b[d + 4] >> 5) !== 0) invalid();
      const n = v.getUint32(d + 1, true);
      dimensions((n & 16383) + 1, ((n >>> 14) & 16383) + 1);
      image = true;
      sized = true;
    } else if (["ANIM", "ANMF"].includes(type)) invalid();
    p = d + len + (len % 2);
  }
  if (p !== b.length || !sized || !image) invalid();
}
export function validateFile(name: string, mime: string, bytes: Uint8Array) {
  if (!bytes.length || bytes.length > MAX_FILE_BYTES) {
    throw new FileError("invalid_file_size", 413);
  }
  if (
    name.length < 1 || name.length > 180 || name !== name.trim() ||
    /[\x00-\x1f\x7f/\\\u202a-\u202e\u2066-\u2069]/u.test(name)
  ) invalid();
  if (
    !Object.hasOwn(types, mime) ||
    !types[mime].includes(name.split(".").pop()?.toLowerCase() ?? "")
  ) invalid();
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (mime === "image/png") png(bytes, view);
  if (mime === "image/jpeg") jpeg(bytes, view);
  if (mime === "image/webp") webp(bytes, view);
  if (mime === "application/pdf") {
    const text = ascii(bytes);
    if (
      !/^%PDF-(?:1\.[0-7]|2\.0)[\r\n]/.test(text) || !/%%EOF\s*$/.test(text) ||
      !/\bobj\b/.test(text) ||
      /\/(JavaScript|JS|Launch|EmbeddedFile|OpenAction)\b/i.test(text)
    ) invalid();
  }
  if (mime === "text/plain") {
    let text: string;
    try {
      text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    } catch {
      return invalid();
    }
    if (
      /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(text) ||
      /<\s*(?:!doctype\s+html|html\b|head\b|body\b|script\b|svg\b|iframe\b|object\b|embed\b)/i
        .test(text)
    ) invalid();
  }
  return { name, mime, size: bytes.length };
}
