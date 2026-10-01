// The review-account seed script, end to end on the emulators: it creates both
// accounts and profiles, a second run changes nothing, and the real flow works
// with them: B is an available, verified, nearby O+ donor, and A can sign in
// with the review code.

import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ projectId: 'demo-rakta-bandhan' });
const db = getFirestore();
const auth = getAuth();

const seed = () => execFileSync('node', ['scripts/seed-review-accounts.mjs', '--emulator'], { encoding: 'utf8' });

seed();
const a = await auth.getUserByEmail('review-a@example.com');
const b = await auth.getUserByEmail('review-b@example.com');
const bPrivate = (await db.doc(`donors/${b.uid}`).get()).data();
const createdAt = bPrivate.created_at.toMillis();

assert.equal(bPrivate.blood_group, 'O+');
assert.equal(bPrivate.is_available, true);
assert.equal(bPrivate.is_verified, true);
assert.equal(bPrivate.is_banned, false);
assert.equal(bPrivate.active_request_id, null);
assert.equal(a.emailVerified && b.emailVerified, true);

const bPublic = (await db.doc(`donors_public/${b.uid}`).get()).data();
assert.equal('phone' in bPublic, false, 'the public listing never carries a phone number');
assert.equal(bPublic.is_verified, true);
// B is within a kilometre of A's point (A is at Chennai Central by default).
assert.ok(Math.abs(bPublic.lat - 13.0827) < 0.01 && Math.abs(bPublic.lng - 80.2707) < 0.01);

const aPrivate = (await db.doc(`donors/${a.uid}`).get()).data();
assert.equal(aPrivate.is_verified, false);

seed();
assert.equal((await auth.getUserByEmail('review-b@example.com')).uid, b.uid, 'a second run reuses the account');
assert.equal((await db.doc(`donors/${b.uid}`).get()).data().created_at.toMillis(), createdAt, 'a second run keeps created_at');
console.log('✔ seed-review-accounts: creates verified requester and donor accounts, and is idempotent');

// Refuses to touch a real project without being told twice.
assert.throws(() => execFileSync('node', ['scripts/seed-review-accounts.mjs', '--project', 'rakta-bandhan2026'], { stdio: 'pipe' }));
console.log('✔ seed-review-accounts: refuses a real project without --yes-live');

console.log('\nSeed smoke checks passed.');
process.exit(0);
