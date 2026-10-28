// Clears the test data so the first real users start from an empty app.
// Run it once, right before the public launch (after your own testing is done).
//
// KEEPS   every admin (admins/{uid}) and their sign-in accounts, plus any account
//         named with --keep-email (use it for the Play review accounts),
//         and the content the team wrote: config, hospitals, announcements,
//         published testimonials, audit_log.
// DELETES every other sign-in account and everything people created: donor
//         profiles, usernames, requests (with their chats and calls), donation
//         history, reports, support and partnership messages, community stories,
//         testimonial submissions, broadcasts, and the impact counter.
// Photos in Cloudflare R2 are NOT touched here: empty the bucket by hand.
//
//   cd functions
//   node scripts/clean-test-data.mjs --emulator                       (dry run on the emulator)
//   node scripts/clean-test-data.mjs --project rakta-bandhan-india --yes-live
//        DRY RUN: only prints what would go. Nothing is deleted.
//   node scripts/clean-test-data.mjs --project rakta-bandhan-india --yes-live --apply
//        [--keep-email reviewer-a@x.com,reviewer-b@x.com]             deletes for real
//
// The live run needs Admin SDK credentials (see docs/launch/CLEAN_BEFORE_LAUNCH.md).

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const emulator = flag('emulator');
if (!emulator && !(flag('yes-live') && opt('project'))) {
  console.error('Refusing to touch a real project. Use --emulator, or --project <id> --yes-live.');
  process.exit(1);
}
const projectId = emulator ? 'demo-rakta-bandhan' : opt('project');
if (emulator) {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
}
const apply = flag('apply');

initializeApp({ projectId });
const auth = getAuth();
const db = getFirestore();

/** Collections emptied completely (their sub-collections go too). */
const WIPE = [
  'requests', 'donation_history', 'reports', 'issue_reports', 'partnership_inquiries',
  'support_submissions', 'support_replies', 'community_stories', 'testimonial_submissions', 'broadcasts',
];
/** Per-person collections: everything except the accounts we keep. */
const PROFILES = ['donors', 'donors_public'];

// 1. Who stays.
const keep = new Set((await db.collection('admins').listDocuments()).map((d) => d.id));
for (const email of opt('keep-email', '').split(',').map((s) => s.trim()).filter(Boolean)) {
  try {
    keep.add((await auth.getUserByEmail(email)).uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    console.error(`--keep-email ${email}: no such account. Stopping.`);
    process.exit(1);
  }
}
const found = keep.size === 0 ? { users: [] } : await auth.getUsers([...keep].map((uid) => ({ uid })));
if (found.users.length === 0) {
  console.error('No admin sign-in account found. Deleting now would remove every account, including yours. Stopping.');
  process.exit(1);
}
console.log(`Project: ${projectId}   Mode: ${apply ? 'DELETE FOR REAL' : 'dry run (nothing is deleted)'}`);
console.log('Keeping these accounts:');
for (const u of found.users) console.log(`  ${u.email ?? '(no email)'}  ${u.uid}`);

// 2. What would go.
const count = async (q) => (await q.count().get()).data().count;
const plan = [];
for (const name of WIPE) plan.push([name, await count(db.collection(name))]);
const profileRefs = {};
for (const name of PROFILES) {
  profileRefs[name] = (await db.collection(name).listDocuments()).filter((r) => !keep.has(r.id));
  plan.push([name, profileRefs[name].length]);
}
const claims = (await db.collection('usernames').get()).docs.filter((d) => !keep.has(d.get('uid')));
plan.push(['usernames', claims.length]);
const impact = await db.doc('public_stats/impact').get();
plan.push(['public_stats/impact', impact.exists ? 1 : 0]);

const doomed = [];
let token;
do {
  const page = await auth.listUsers(1000, token);
  doomed.push(...page.users.filter((u) => !keep.has(u.uid)).map((u) => u.uid));
  token = page.pageToken;
} while (token);
plan.push(['sign-in accounts', doomed.length]);

console.log('\nWould delete:');
for (const [name, n] of plan) console.log(`  ${String(n).padStart(6)}  ${name}`);

if (!apply) {
  console.log('\nDry run only. Add --apply to delete.');
  process.exit(0);
}

// 3. Delete.
for (const name of WIPE) await db.recursiveDelete(db.collection(name));
for (const name of PROFILES) for (const ref of profileRefs[name]) await db.recursiveDelete(ref);
for (const d of claims) await d.ref.delete();
if (impact.exists) await impact.ref.delete();
// A kept profile must not point at a request that no longer exists.
for (const uid of keep) {
  const ref = db.doc(`donors/${uid}`);
  if ((await ref.get()).exists) await ref.update({ active_request_id: null });
}
let failed = 0;
for (let i = 0; i < doomed.length; i += 1000) {
  const res = await auth.deleteUsers(doomed.slice(i, i + 1000));
  failed += res.failureCount;
}
console.log(`\nDone. ${failed ? `${failed} sign-in accounts could not be deleted: check the Authentication page.` : 'All listed data deleted.'}`);
console.log('Next: empty the R2 bucket (docs/launch/CLEAN_BEFORE_LAUNCH.md, step 3).');
