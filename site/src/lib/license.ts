/** Shared license key helpers. Format: MURMUR-XXXX-XXXX-XXXX-XXXX */

const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

export const LICENSE_KEY_PATTERN = /^MURMUR(-[0-9A-HJKMNP-TV-Z]{4}){4}$/;

export function isLicenseKey(value: string): boolean {
  return LICENSE_KEY_PATTERN.test(value.trim().toUpperCase());
}

export function normalizeLicenseKey(value: string): string {
  return value.trim().toUpperCase();
}

/**
 * Mirrors the SQL generate_license_key() function. The database is the source
 * of truth for real keys; this exists for demo data and tests.
 */
export function generateLicenseKey(): string {
  let out = "MURMUR";
  for (let i = 0; i < 16; i++) {
    if (i % 4 === 0) out += "-";
    out += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  }
  return out;
}
