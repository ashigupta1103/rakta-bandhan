// Geohash helpers — the same encoding as lib/services/backend.dart's
// encodeGeohash, so a cell computed here matches the `geohash` stored on
// donor and request documents.

const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

export function encodeGeohash(lat: number, lng: number, precision = 9): string {
  let latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  let hash = '';
  let isEven = true;
  let bit = 0;
  let ch = 0;
  while (hash.length < precision) {
    if (isEven) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch |= 1 << (4 - bit);
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch |= 1 << (4 - bit);
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    isEven = !isEven;
    if (bit < 4) {
      bit++;
    } else {
      hash += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return hash;
}

export function distanceKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Every geohash cell of [precision] that overlaps the square around a
 * circle of [radiusKm] — each becomes one `[cell, cell~)` range query.
 * Precision 4 cells are ~39 × 20 km, so a 25 km radius needs about a dozen.
 */
export function cellsCovering(lat: number, lng: number, radiusKm: number, precision = 4): string[] {
  const lngBits = Math.ceil((5 * precision) / 2);
  const latBits = Math.floor((5 * precision) / 2);
  const cellLat = 180 / 2 ** latBits;
  const cellLng = 360 / 2 ** lngBits;
  const dLat = radiusKm / 111.32;
  const dLng = radiusKm / (111.32 * Math.max(Math.cos((lat * Math.PI) / 180), 0.01));
  const cells = new Set<string>();
  for (let y = lat - dLat; y <= lat + dLat + cellLat; y += cellLat) {
    const cy = Math.min(Math.max(y, lat - dLat), lat + dLat);
    for (let x = lng - dLng; x <= lng + dLng + cellLng; x += cellLng) {
      const cx = Math.min(Math.max(x, lng - dLng), lng + dLng);
      cells.add(encodeGeohash(Math.max(-90, Math.min(90, cy)), ((cx + 540) % 360) - 180, precision));
    }
  }
  return [...cells];
}

/** Recipient blood group → donor groups that can give to it. */
export const BLOOD_COMPATIBILITY: Record<string, string[]> = {
  'A+': ['A+', 'A-', 'O+', 'O-'],
  'A-': ['A-', 'O-'],
  'B+': ['B+', 'B-', 'O+', 'O-'],
  'B-': ['B-', 'O-'],
  'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
  'AB-': ['A-', 'B-', 'AB-', 'O-'],
  'O+': ['O+', 'O-'],
  'O-': ['O-'],
};

/** FCM topic for a blood group ("A+" → "bg_Apos"); topics allow only [a-zA-Z0-9-_.~%]. */
export function bloodGroupTopic(group: string): string {
  return 'bg_' + group.replace('+', 'pos').replace('-', 'neg');
}
