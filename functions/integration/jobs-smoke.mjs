// The reactivation job on the emulators: it switches the right donors back on,
// pages through more than one batch, and a second run does nothing.

import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

process.env.GCLOUD_PROJECT ??= 'demo-rakta-bandhan';
const require = createRequire(import.meta.url);
const { Timestamp } = require('firebase-admin/firestore');
const { db } = require('../lib/app.js'); // initialises the Admin app once
const { reactivateDueDonors } = require('../lib/jobs.js');

const past = Timestamp.fromMillis(Date.now() - 86400e3);
const future = Timestamp.fromMillis(Date.now() + 30 * 86400e3);
const resting = (extra = {}) => ({ is_available: false, is_banned: false, reactivation_scheduled_at: past, ...extra });

await db.doc('donors/due1').set(resting({ fcm_token: 'token-1' }));
await db.doc('donors_public/due1').set({ is_available: false, name: 'One' });
await db.doc('donors/due2').set(resting());
await db.doc('donors/future').set(resting({ reactivation_scheduled_at: future }));
await db.doc('donors/banned').set(resting({ is_banned: true }));
await db.doc('donors/available').set({ is_available: true, is_banned: false });
await db.doc('donors/chosen-off').set({ is_available: false, is_banned: false }); // switched off by choice, no schedule

const notified = [];
const notify = async (targets) => notified.push(...targets);
assert.equal(await reactivateDueDonors(Date.now(), notify), 2);

const get = async (id) => (await db.doc(`donors/${id}`).get()).data();
for (const id of ['due1', 'due2']) {
  const d = await get(id);
  assert.equal(d.is_available, true, id);
  assert.equal('reactivation_scheduled_at' in d, false, `${id}: schedule cleared so a later switch-off sticks`);
}
const pub = (await db.doc('donors_public/due1').get()).data();
assert.equal(pub.is_available, true);
assert.equal(pub.name, 'One', 'the public listing keeps its other fields');
assert.equal((await get('future')).is_available, false, 'rest not over');
assert.equal((await get('banned')).is_available, false, 'banned donors stay off');
assert.equal((await get('chosen-off')).is_available, false, 'no schedule: left alone');
assert.deepEqual(notified, [{ uid: 'due1', token: 'token-1' }], 'only donors with a push token are notified');
assert.equal(await reactivateDueDonors(Date.now(), notify), 0, 'a second run finds nothing');
console.log('✔ reactivateDueDonors: switches the right donors back on, tells those with a token, then does nothing');

// More than one page (200 donors / 400 writes per batch).
const bulk = db.batch();
for (let i = 0; i < 450; i++) bulk.set(db.doc(`donors/bulk${i}`), resting());
await bulk.commit();
assert.equal(await reactivateDueDonors(Date.now(), notify), 450);
assert.equal((await get('bulk449')).is_available, true);
assert.equal(await reactivateDueDonors(Date.now(), notify), 0);
console.log('✔ reactivateDueDonors: pages through 450 donors in three batches');

console.log('\nJob smoke checks passed.');
process.exit(0);
