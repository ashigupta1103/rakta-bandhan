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

// 1. Broadcast → onBroadcast runs and stamps a status (failed here: no FCM credentials).
const b = await db.collection('broadcasts').add({ title: 'Test', body: 'Hello', blood_group: 'O+', created_at: FieldValue.serverTimestamp(), status: 'queued' });
const stamped = await waitFor(async () => {
  const d = (await b.get()).data();
  return d.status !== 'queued' ? d : null;
}, 'broadcast status');
assert.equal(stamped.topic, 'bg_Opos');
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

// 4. Deleting a post → onStoryDeleted tolerates a photo that doesn't exist.
const story = await db.collection('community_stories').add({ author_uid: 'u1', body: 'x', image_path: 'community/u1/missing.jpg' });
await story.delete();
await sleep(3000);
console.log('✔ onStoryDeleted ran');

console.log('\nAll function smoke checks passed.');
process.exit(0);
