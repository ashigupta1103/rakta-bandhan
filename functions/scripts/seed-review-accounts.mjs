// Creates (or refreshes) the two accounts store reviewers use, so the two-device
// walkthrough in docs/publishing/store-listing.md works:
//   A: a requester          B: an O+ donor, verified and available, near A
// Both have fictional names and dummy phone numbers. Safe to run twice.
//
//   cd functions && npm run build
//   node scripts/seed-review-accounts.mjs --emulator
//   node scripts/seed-review-accounts.mjs --project rakta-bandhan2026 --yes-live \
//        --email-a <REVIEW_EMAIL_A> --email-b <REVIEW_EMAIL_B>      (the owner, with credentials)
//
// Options: --lat/--lng (where A is; default Chennai Central), --area (label shown on B's card).
// Reviewers sign in with these emails and the fixed REVIEW_CODE (see login.ts).

import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const require = createRequire(import.meta.url);
const { encodeGeohash } = require('../lib/geo.js');

const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const emulator = flag('emulator');
if (!emulator && !(flag('yes-live') && opt('project'))) {
  console.error('Refusing to touch a real project. Use --emulator, or --project <id> --yes-live with --email-a and --email-b.');
  process.exit(1);
}
const projectId = emulator ? 'demo-rakta-bandhan' : opt('project');
if (emulator) {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
}
const emailA = opt('email-a', emulator ? 'review-a@example.com' : '');
const emailB = opt('email-b', emulator ? 'review-b@example.com' : '');
if (!emailA || !emailB) {
  console.error('Pass --email-a and --email-b.');
  process.exit(1);
}

const lat = Number(opt('lat', '13.0827'));
const lng = Number(opt('lng', '80.2707'));
const area = opt('area', 'Chennai');
if (![lat, lng].every(Number.isFinite)) {
  console.error('--lat and --lng must be numbers.');
  process.exit(1);
}

initializeApp({ projectId });
const auth = getAuth();
const db = getFirestore();

/** Same rounding as Backend._coarse: the public listing never has more than ~1 km. */
const coarse = (deg) => Math.round(deg * 100) / 100;

async function userFor(email, displayName) {
  try {
    return await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    return auth.createUser({ email, emailVerified: true, displayName });
  }
}

/** Writes donors/{uid} and donors_public/{uid} the way Backend.registerDonor does. */
async function writeProfile(user, p) {
  const donorRef = db.doc(`donors/${user.uid}`);
  await db.runTransaction(async (tx) => {
  const before = await tx.get(donorRef);
  const username = before.get('username') || `review_${createHash('sha256').update(user.uid).digest('hex').slice(0, 12)}`;
  const claimRef = db.doc(`usernames/${username}`);
  const claim = await tx.get(claimRef);
  if (claim.exists && claim.get('uid') !== user.uid) throw new Error('Review username already owned by another account');
  if (!claim.exists) tx.set(claimRef, { uid: user.uid, created_at: FieldValue.serverTimestamp() });
  const created = before.exists ? {} : { created_at: FieldValue.serverTimestamp() };
  tx.set(donorRef,
    {
      name: p.name,
      name_lower: p.name.trim().toLowerCase(),
      username,
      username_changed_at: before.get('username_changed_at') ?? FieldValue.serverTimestamp(),
      phone: p.phone,
      email: user.email,
      blood_group: p.bloodGroup,
      location_label: p.area,
      geohash: encodeGeohash(p.lat, p.lng),
      lat: p.lat,
      lng: p.lng,
      is_available: true,
      is_verified: p.verified,
      is_banned: false,
      active_request_id: null,
      ...created,
    },
    { merge: true },
  );
  tx.set(db.doc(`donors_public/${user.uid}`),
    {
      name: p.name,
      username,
      blood_group: p.bloodGroup,
      geohash: encodeGeohash(coarse(p.lat), coarse(p.lng), 6),
      lat: coarse(p.lat),
      lng: coarse(p.lng),
      area: p.area,
      is_available: true,
      is_verified: p.verified,
      updated_at: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  });
}

const a = await userFor(emailA, 'Review Requester');
const b = await userFor(emailB, 'Review Donor');
await writeProfile(a, { name: 'Review Requester', phone: '9000000001', bloodGroup: 'A+', lat, lng, area, verified: false });
// About 600 m from A, so B shows up as a nearby donor on A's request.
await writeProfile(b, { name: 'Review Donor', phone: '9000000002', bloodGroup: 'O+', lat: lat + 0.004, lng: lng + 0.004, area, verified: true });

console.log(`Review accounts ready on ${projectId}:`);
console.log(`  A (requester)  ${emailA}  uid ${a.uid}`);
console.log(`  B (O+ donor)   ${emailB}  uid ${b.uid}`);
console.log('Names and phone numbers are fictional. Reviewers sign in with these emails and the REVIEW_CODE.');
console.log('Make sure REVIEW_EMAILS lists both addresses and REVIEW_CODE is set (docs/launch/AFTER_BLAZE_UPGRADE.md).');
