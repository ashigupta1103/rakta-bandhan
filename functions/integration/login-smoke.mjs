// Passwordless sign-in, end to end on the emulators: request a code, try a
// wrong one, use the right one, sign in with the returned custom token on
// the Auth emulator, check the token's claims, then delete the account.

import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const require = createRequire(import.meta.url);
const { destinationKey } = require('../lib/otp.js');

initializeApp({ projectId: 'demo-rakta-bandhan' });
const db = getFirestore();

const FN = 'http://127.0.0.1:5001/demo-rakta-bandhan/asia-south1';
const AUTH = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';

async function callable(name, data, idToken) {
  const headers = { 'Content-Type': 'application/json' };
  if (idToken) headers.Authorization = `Bearer ${idToken}`;
  const res = await fetch(`${FN}/${name}`, { method: 'POST', headers, body: JSON.stringify({ data }) });
  return res.json();
}

async function signInWithCustomToken(token) {
  const r = await fetch(`${AUTH}/accounts:signInWithCustomToken?key=demo`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token, returnSecureToken: true }),
  }).then((x) => x.json());
  assert.ok(r.idToken, JSON.stringify(r));
  return { idToken: r.idToken, claims: JSON.parse(Buffer.from(r.idToken.split('.')[1], 'base64url').toString()) };
}

const codeRef = (email) => db.doc(`login_codes/${destinationKey('email', email)}`);

const email = `smoke-${Date.now()}@example.com`;

const sent = await callable('requestLoginCode', { email });
assert.equal(sent.result?.sent, true, JSON.stringify(sent));
assert.equal(sent.result?.resendAfterS, 30);
const again = await callable('requestLoginCode', { email });
assert.equal(again.error?.status, 'RESOURCE_EXHAUSTED', 'a second send within 30 s must be refused');
const bad = await callable('requestLoginCode', { email: 'nope' });
assert.equal(bad.error?.status, 'INVALID_ARGUMENT');
const sms = await callable('requestLoginCode', { channel: 'sms', phone: '9876543210' });
assert.equal(sms.error?.status, 'UNIMPLEMENTED');
console.log('✔ requestLoginCode: sends, rate-limits, validates; SMS answers "coming soon"');

const stored = (await codeRef(email).get()).data();
assert.match(stored.dev_code, /^\d{6}$/);
assert.ok(!JSON.stringify(stored).includes(email), 'the raw email must not be stored');
assert.ok(!Object.values(stored).includes(Number(stored.dev_code)), 'no plain code outside the emulator-only field');

const wrong = String((Number(stored.dev_code) + 1) % 1_000_000).padStart(6, '0');
const wrongRes = await callable('verifyLoginCode', { email, code: wrong });
assert.equal(wrongRes.error?.status, 'PERMISSION_DENIED');
assert.match(wrongRes.error?.message, /4 tries left/);

const ok = await callable('verifyLoginCode', { email, code: stored.dev_code });
assert.ok(ok.result?.token, JSON.stringify(ok));
const reuse = await callable('verifyLoginCode', { email, code: stored.dev_code });
assert.equal(reuse.error?.status, 'FAILED_PRECONDITION', 'a code works once');
console.log('✔ verifyLoginCode: wrong code counted, right code accepted exactly once');

const first = await signInWithCustomToken(ok.result.token);
assert.equal(first.claims.login, 'email_otp');
assert.equal(first.claims.email, email);
assert.equal(first.claims.email_verified, true);
console.log('✔ custom token signs in; ID token carries login=email_otp, the email, email_verified');

// Same email again → same account (and so the same donor profile).
await codeRef(email).update({ last_sent_ms: 0 });
await callable('requestLoginCode', { email });
const code2 = (await codeRef(email).get()).data().dev_code;
const ok2 = await callable('verifyLoginCode', { email, code: code2 });
const second = await signInWithCustomToken(ok2.result.token);
assert.equal(second.claims.user_id, first.claims.user_id);
console.log('✔ the same email always opens the same account');

// Five wrong guesses burn a code.
await codeRef(email).update({ last_sent_ms: 0 });
await callable('requestLoginCode', { email });
const code3 = (await codeRef(email).get()).data().dev_code;
const notIt = String((Number(code3) + 7) % 1_000_000).padStart(6, '0');
for (let i = 0; i < 5; i++) await callable('verifyLoginCode', { email, code: notIt });
const burned = await callable('verifyLoginCode', { email, code: code3 });
assert.equal(burned.error?.status, 'RESOURCE_EXHAUSTED', 'after 5 wrong tries even the right code is refused');
console.log('✔ five wrong tries burn the code');

const anon = await callable('deleteMyAuthAccount', {});
assert.equal(anon.error?.status, 'UNAUTHENTICATED');
const del = await callable('deleteMyAuthAccount', {}, second.idToken);
assert.equal(del.result?.deleted, true, JSON.stringify(del));
const lookup = await fetch(`${AUTH}/accounts:lookup?key=demo`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
  body: JSON.stringify({ localId: [first.claims.user_id] }),
}).then((x) => x.json());
assert.ok(!lookup.users || lookup.users.length === 0, 'the account must be gone');
console.log('✔ deleteMyAuthAccount removes the caller’s account and refuses anonymous calls');

console.log('\nAll sign-in smoke checks passed.');
process.exit(0);
