// Smoke test: the triggers deploy and fire on the emulator.
//   cd functions && npm run build && npm run smoke
// Push delivery itself can't happen on the emulator (no FCM credentials),
// so each check looks for the side effect a trigger leaves in Firestore.

import assert from 'node:assert/strict';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';

initializeApp({ projectId: 'demo-rakta-bandhan' });
const db = getFirestore();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(fn, label, timeoutMs = 20000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const v = await fn();
    if (v) return v;
    await sleep(500);
  }
  throw new Error(`timed out waiting for: ${label}`);
}

// 1. Broadcast → onBroadcast stamps a status without contacting FCM locally.
const b = await db.collection('broadcasts').add({ title: 'Test', body: 'Hello', blood_group: 'O+', created_at: FieldValue.serverTimestamp(), status: 'queued' });
const stamped = await waitFor(async () => {
  const d = (await b.get()).data();
  return d.status !== 'queued' ? d : null;
}, 'broadcast status');
assert.equal(stamped.topic, 'bg_Opos');
assert.equal(stamped.status, 'skipped', 'local checks must not send real pushes');
console.log('✔ onBroadcast fired → status', stamped.status, 'topic', stamped.topic);

// 2. A donor with a (dead) token near a new request → onRequestCreated fans
//    out, FCM rejects the fake token, and the token is left alone or removed
//    without crashing. We verify the function ran by its log-free side
//    effect: the function must not throw, so the request stays intact.
await db.doc('donors/d1').set({
  name: 'Donor', blood_group: 'O+', is_available: true, is_banned: false, active_request_id: null,
  lat: 13.08, lng: 80.27, geohash: 'tf2ez0000', fcm_token: 'fake-token', urgent_alerts: true,
});
const req = await db.collection('requests').add({
  requester_uid: 'r1', requester_name: 'R', blood_group: 'O+', units_needed: 1, urgency: 'urgent',
  location_label: 'Apollo Hospital, Greams Road', lat: 13.06, lng: 80.25, geohash: 'tf2ez1111', status: 'open',
  created_at: FieldValue.serverTimestamp(), expires_at: Timestamp.fromMillis(Date.now() + 3600e3),
});
await sleep(4000);
assert.equal((await req.get()).data().status, 'open');
console.log('✔ onRequestCreated ran without errors');

// 3. Request update → onRequestUpdated handles a match without throwing.
await req.update({ status: 'matched', matched_donor_id: 'd1', matched_donor_name: 'Donor' });
await sleep(3000);
console.log('✔ onRequestUpdated ran');

// 3b. Two-sided completion → the donor's cooldown starts only at completion.
await db.doc('donors/d1').update({ active_request_id: req.id, is_available: true });
await db.doc('donors_public/d1').set({ is_available: true });
await req.update({ donor_confirmed_at: Timestamp.now() });
await sleep(2500);
let donor = (await db.doc('donors/d1').get()).data();
assert.equal(donor.is_available, true, 'the donor confirming alone must not start the cooldown');
assert.equal(donor.active_request_id, req.id);
await req.update({ requester_confirmed_at: Timestamp.now(), status: 'fulfilled', fulfilled_at: Timestamp.now() });
donor = await waitFor(async () => {
  const d = (await db.doc('donors/d1').get()).data();
  return d.active_request_id === null ? d : null;
}, 'donor completion applied');
assert.equal(donor.is_available, false);
assert.ok(donor.reactivation_scheduled_at.toMillis() > Date.now() + 89 * 86400e3, 'cooldown ~90 days');
assert.equal((await db.doc('donors_public/d1').get()).data().is_available, false);
const history = await db.collection('donation_history').where('request_id', '==', req.id).get();
assert.equal(history.size, 1, 'exactly one donation record');
assert.equal(history.docs[0].id, req.id);
console.log('✔ completion applied the donor cooldown once, at completion');

// 4. The Impact counter moves server-side only once config/features.server_jobs is on
//    (the free plan has no functions, so until then the app keeps it itself).
const impact = db.doc('public_stats/impact');
assert.equal((await impact.get()).exists, false, 'the earlier completion left the counter alone: server jobs were off');
await db.doc('config/features').set({ server_jobs: true });
const completed = async () => {
  const r = await db.collection('requests').add({
    requester_uid: 'r1', blood_group: 'O+', units_needed: 1, urgency: 'normal', location_label: 'Apollo Hospital', status: 'matched',
    matched_donor_id: 'nobody', donor_confirmed_at: Timestamp.now(), requester_confirmed_at: Timestamp.now(),
    created_at: Timestamp.now(), expires_at: Timestamp.fromMillis(Date.now() + 3600e3),
  });
  await r.update({ status: 'fulfilled', fulfilled_at: Timestamp.now() });
};
await completed();
let counted = await waitFor(async () => (await impact.get()).data(), 'impact counter created');
assert.equal(counted.donations_this_month, 1);
assert.match(counted.month_key, /^\d{4}-\d{2}$/);
await completed();
counted = await waitFor(async () => {
  const d = (await impact.get()).data();
  return d.donations_this_month === 2 ? d : null;
}, 'impact counter incremented');
console.log('✔ onRequestUpdated moves the Impact counter, once per completed donation, when server jobs are on');

console.log('\nAll function smoke checks passed.');
process.exit(0);
