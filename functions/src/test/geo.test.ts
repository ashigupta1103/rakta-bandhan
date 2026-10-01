import { test } from 'node:test';
import assert from 'node:assert/strict';

import { BLOOD_COMPATIBILITY, bloodGroupTopic, cellsCovering, distanceKm, encodeGeohash } from '../geo';
import { shortPlace } from '../text';

test('encodeGeohash matches the reference encoding', () => {
  // Classic reference point from the geohash spec (Jutland, Denmark).
  assert.equal(encodeGeohash(57.64911, 10.40744, 11), 'u4pruydqqvj');
  // Chennai Central — same prefix at every precision.
  const full = encodeGeohash(13.0827, 80.2707, 9);
  assert.equal(encodeGeohash(13.0827, 80.2707, 4), full.slice(0, 4));
});

test('cellsCovering includes the centre cell and every point inside the radius', () => {
  const lat = 13.0827;
  const lng = 80.2707;
  const cells = cellsCovering(lat, lng, 25, 4);
  assert.ok(cells.length >= 4 && cells.length <= 25, `unexpected cell count ${cells.length}`);
  assert.ok(cells.includes(encodeGeohash(lat, lng, 4)));
  // Sample points on the circle's edge: each one's cell must be covered.
  for (let deg = 0; deg < 360; deg += 15) {
    const r = (deg * Math.PI) / 180;
    const pLat = lat + (24.9 / 111.32) * Math.sin(r);
    const pLng = lng + (24.9 / (111.32 * Math.cos((lat * Math.PI) / 180))) * Math.cos(r);
    assert.ok(distanceKm(lat, lng, pLat, pLng) < 25.5);
    assert.ok(cells.includes(encodeGeohash(pLat, pLng, 4)), `edge point at ${deg}° not covered`);
  }
});

test('distanceKm is roughly right', () => {
  // Chennai Central → Chennai airport ≈ 14–15 km.
  const d = distanceKm(13.0827, 80.2707, 12.9941, 80.1709);
  assert.ok(d > 13 && d < 16, `got ${d}`);
});

test('blood compatibility matches the app table', () => {
  assert.deepEqual(BLOOD_COMPATIBILITY['O-'], ['O-']);
  assert.equal(BLOOD_COMPATIBILITY['AB+'].length, 8);
  assert.deepEqual(BLOOD_COMPATIBILITY['A-'], ['A-', 'O-']);
});

test('blood group topics are valid FCM topic names', () => {
  assert.equal(bloodGroupTopic('A+'), 'bg_Apos');
  assert.equal(bloodGroupTopic('AB-'), 'bg_ABneg');
  for (const g of Object.keys(BLOOD_COMPATIBILITY)) assert.match(bloodGroupTopic(g), /^[a-zA-Z0-9-_.~%]+$/);
});

test('shortPlace never shows coordinates or PIN codes', () => {
  assert.equal(shortPlace('13.0827, 80.2707'), 'near you');
  assert.equal(shortPlace(''), 'near you');
  assert.equal(shortPlace('Apollo Hospital, Greams Road, Thousand Lights, Chennai, 600006, India'), 'Apollo Hospital, Greams Road');
  assert.equal(shortPlace('600006, Adyar, Chennai'), 'Adyar, Chennai');
});
