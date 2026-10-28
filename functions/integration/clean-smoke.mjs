// Checks scripts/clean-test-data.mjs on the emulators: a dry run deletes nothing,
// --apply deletes the test data and keeps the admin, the reviewer and the team's content.
//   npm run smoke:clean

import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
initializeApp({ projectId: 'demo-rakta-bandhan' });
const auth = getAuth();
const db = getFirestore();

const mk = (email) => auth.createUser({ email });
const admin = await mk('admin@example.com');
const reviewer = await mk('reviewer@example.com');
const tester = await mk('tester@example.com');
const orphan = await mk('never-finished@example.com'); // signed up, never registered

await db.doc(`admins/${admin.uid}`).set({ created: true });
await db.doc(`donors/${admin.uid}`).set({ name: 'Admin', active_request_id: 'gone' });
await db.doc(`donors/${reviewer.uid}`).set({ name: 'Reviewer' });
await db.doc(`donors/${tester.uid}`).set({ name: 'Tester' });
await db.doc(`donors/${tester.uid}/private/id_proof`).set({ data: 'x' });
await db.doc(`donors_public/${tester.uid}`).set({ name: 'Tester' });
await db.doc('usernames/tester_one').set({ uid: tester.uid });
await db.doc('usernames/review_one').set({ uid: reviewer.uid });
await db.doc('requests/r1').set({ requester_uid: tester.uid });
await db.doc('requests/r1/messages/m1').set({ text: 'hi' });
await db.doc('requests/r1/calls/c1').set({ status: 'ended' });
await db.doc('requests/r1/calls/c1/caller_candidates/x1').set({ candidate: 'x' });
await db.doc('donation_history/r1').set({ donor_id: tester.uid });
await db.doc('community_stories/s1').set({ body: 'story' });
await db.doc('public_stats/impact').set({ donations_this_month: 4 });
await db.doc('announcements/a1').set({ title: 'Keep me' });
await db.doc('config/features').set({ server_jobs: false });

const run = (...extra) =>
  execFileSync('node', ['scripts/clean-test-data.mjs', '--emulator', '--keep-email', 'reviewer@example.com', ...extra], { encoding: 'utf8' });
const exists = async (path) => (await db.doc(path).get()).exists;
const gone = async (email) => auth.getUserByEmail(email).then(() => false, (e) => e.code === 'auth/user-not-found');

// Dry run: prints the plan, deletes nothing.
const dry = run();
assert.match(dry, /Dry run only/);
assert.match(dry, /sign-in accounts/);
assert.ok(await exists('requests/r1'), 'dry run must not delete');
assert.ok(!(await gone('tester@example.com')), 'dry run must not delete accounts');

// Apply.
run('--apply');
for (const path of ['requests/r1', 'requests/r1/messages/m1', 'requests/r1/calls/c1/caller_candidates/x1', 'donation_history/r1', 'community_stories/s1',
  `donors/${tester.uid}`, `donors/${tester.uid}/private/id_proof`, `donors_public/${tester.uid}`, 'usernames/tester_one', 'public_stats/impact']) {
  assert.ok(!(await exists(path)), `${path} should be deleted`);
}
assert.ok(await gone('tester@example.com'), 'tester account deleted');
assert.ok(await gone('never-finished@example.com'), 'account without a profile deleted');
for (const path of [`admins/${admin.uid}`, `donors/${admin.uid}`, `donors/${reviewer.uid}`, 'usernames/review_one', 'announcements/a1', 'config/features']) {
  assert.ok(await exists(path), `${path} should stay`);
}
assert.ok(!(await gone('admin@example.com')) && !(await gone('reviewer@example.com')), 'admin and reviewer accounts stay');
assert.equal((await db.doc(`donors/${admin.uid}`).get()).get('active_request_id'), null, 'kept profile no longer points at a deleted request');
void orphan;

// No admin at all: refuses, so it can never wipe the owner out.
await db.doc(`admins/${admin.uid}`).delete();
assert.throws(() => execFileSync('node', ['scripts/clean-test-data.mjs', '--emulator', '--apply'], { stdio: 'pipe' }), /./);
assert.ok(!(await gone('admin@example.com')), 'refused run keeps the account');

console.log('clean-test-data smoke test passed');
