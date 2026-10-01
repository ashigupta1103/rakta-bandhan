/**
 * Short display form of a stored address: the first two comma-separated
 * parts, skipping bare numbers (PIN codes) — the same rule as
 * Backend.shortPlace in the app, so a notification never shows a raw
 * coordinate or a six-line address.
 */
export function shortPlace(label: string | undefined | null, fallback = 'near you'): string {
  const text = (label ?? '').trim();
  if (!text || /^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$/.test(text)) return fallback;
  const parts = text
    .split(',')
    .map((p) => p.trim())
    .filter((p) => p.length > 0 && !/^\d+$/.test(p));
  return parts.slice(0, 2).join(', ') || fallback;
}
