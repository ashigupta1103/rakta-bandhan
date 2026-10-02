// Bans, unbans and removals reach the sign-in account (functions/src/accounts.ts),
// on the emulators.

import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const require = createRequire(import.meta.url);
const { destinationKey } = require('../lib/otp.js');

initializeApp({ projectId: 'demo-rakta-bandhan' });
const db = getFirestore();
const auth = getAuth();
const FN = 'http://127.0.0.1:5001/demo-rakta-bandhan/asia-south1';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(fn, label, timeoutMs = 20000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await fn()) return;
    await sleep(400);
  }
  throw new Error(`timed out waiting for: ${label}`);
}

const callable = (name, data) =>
  fetch(`${FN}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ data }) }).then((r) => r.json());

const email = `banned-${Date.now()}@example.com`;
const user = await auth.createUser({ email, emailVerified: true });
const donor = db.doc(`donors/${user.uid}`);
const username = `donor_${Date.now()}`;
await db.doc(`usernames/${username}`).set({ uid: user.uid });
await donor.set({ name: 'Donor', username, email, is_banned: false, is_available: true });
await db.doc(`donors/${user.uid}/private/id_proof`).set({ id_proof_base64: 'abc' });
await sleep(1500);
assert.equal((await auth.getUser(user.uid)).disabled, false, 'an ordinary update leaves the account alone');

await donor.update({ is_banned: true, is_available: false });
await waitFor(async () => (await auth.getUser(user.uid)).disabled === true, 'account disabled after a ban');
// A banned person can't get back in with an emailed code either.
assert.equal((await callable('requestLoginCode', { email })).result?.sent, true);
const code = (await db.doc(`login_codes/${destinationKey('email', email)}`).get()).data().dev_code;
const refused = await callable('verifyLoginCode', { email, code });
assert.equal(refused.error?.status, 'PERMISSION_DENIED');
assert.match(refused.error?.message, /disabled/);
console.log('✔ a ban disables the sign-in account, and the emailed code no longer opens it');

await donor.update({ is_banned: false });
await waitFor(async () => (await auth.getUser(user.uid)).disabled === false, 'account re-enabled after an unban');
console.log('✔ an unban re-enables it');

await donor.delete();
await waitFor(async () => {
  try {
    await auth.getUser(user.uid);
    return false;
  } catch (e) {
    return e.code === 'auth/user-not-found';
  }
}, 'sign-in account removed with the donor');
await waitFor(async () => !(await db.doc(`donors/${user.uid}/private/id_proof`).get()).exists, 'ID photo doc removed with the donor');
assert.equal((await db.doc(`usernames/${username}`).get()).exists, false, 'removal releases the donor username');
console.log('✔ removing a donor removes the sign-in account and the subcollection left behind (the ID photo doc)');

const oldUser = await auth.createUser({ email: `old-${Date.now()}@example.com` });
const reused = `reused_${Date.now()}`;
await db.doc(`donors/${oldUser.uid}`).set({ username: reused, is_banned: false });
await db.doc(`usernames/${reused}`).set({ uid: 'new-owner' });
await db.doc(`donors/${oldUser.uid}`).delete();
await waitFor(async () => {
  try { await auth.getUser(oldUser.uid); return false; } catch (e) { return e.code === 'auth/user-not-found'; }
}, 'old account removal');
assert.equal((await db.doc(`usernames/${reused}`).get()).get('uid'), 'new-owner', 'late cleanup must preserve a reused name');
console.log('✔ username cleanup preserves a new owner of a released name');

console.log('\nAccount smoke checks passed.');
process.exit(0);
