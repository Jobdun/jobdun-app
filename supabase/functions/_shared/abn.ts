// ABN format + checksum validation.
// Mirrors lib/core/utils/validators.dart so client + server agree.

const WEIGHTS = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19];

export function normaliseAbn(input: string): string {
  return input.replace(/\s+/g, "");
}

export function isValidAbn(input: string): boolean {
  const abn = normaliseAbn(input);
  if (!/^\d{11}$/.test(abn)) return false;

  // ABN checksum: subtract 1 from the first digit, multiply each by its weight,
  // sum, then check sum % 89 == 0.
  const digits = abn.split("").map((d) => parseInt(d, 10));
  digits[0] -= 1;
  const sum = digits.reduce((acc, d, i) => acc + d * WEIGHTS[i], 0);
  return sum % 89 === 0;
}
