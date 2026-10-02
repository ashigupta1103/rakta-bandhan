// Only the local demo project. Outbound delivery must stay disabled.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator required');
initializeApp({ projectId: 'demo-rakta-bandhan' });
const db = getFirestore();
const reply = db.collection('support_replies').doc();
await reply.set({ to_uid: 'local-support-user', source_collection: 'issue_reports', source_id: 'local-issue', body: 'Local reply' });
for (let attempt = 0; attempt < 50; attempt++) {
  if ((await reply.get()).get('delivery_state')) break;
  await new Promise((resolve) => setTimeout(resolve, 400));
}
assert.equal((await reply.get()).get('delivery_state'), 'disabled', 'outbound delivery is off by default');
console.log('✓ support reply stored in-app without external email or push');

// More than two migration pages. Verify dry-run protection, cursor search,
// exact lookup, matching count and historical phone removal.
for (let start = 0; start < 410; start += 200) {
  const batch = db.batch();
  for (let i = start; i < Math.min(start + 200, 410); i++) {
    const id = `migration_${String(i).padStart(4, '0')}`;
    batch.set(db.doc(`donors/${id}`), { name: '  Migration Donor  ', username: `migration_${i}`, email: `${id}@example.com`, phone: '9876543210', is_verified: false, is_banned: false, created_at: Timestamp.fromMillis(i + 1) });
    batch.set(db.doc(`requests/${id}`), { requester_phone: '9876543210', matched_donor_phone: '9876543211', status: 'expired' });
  }
  await batch.commit();
}
const script = new URL('../scripts/backfill-search.mjs', import.meta.url);
const run = (...args) => execFileSync(process.execPath, [fileURLToPath(script), '--emulator', '--cleanup-request-phones', ...args], { encoding: 'utf8', env: process.env });
run();
assert.equal((await db.doc('donors/migration_0000').get()).get('name_lower'), undefined, 'dry run does not write');
assert.equal((await db.doc('requests/migration_0000').get()).get('requester_phone'), '9876543210');
run('--apply');
const base = db.collection('donors').where('is_verified', '==', false).where('is_banned', '==', false)
  .where('name_lower', '>=', 'migration').where('name_lower', '<=', 'migration\uf8ff').orderBy('name_lower');
assert.equal((await base.count().get()).data().count, 410);
const ids = new Set(); let cursor;
for (;;) {
  const page = await (cursor ? base.startAfter(cursor) : base).limit(50).get();
  for (const doc of page.docs) { assert.ok(!ids.has(doc.id)); ids.add(doc.id); }
  if (page.size < 50) break;
  cursor = page.docs.at(-1);
}
assert.equal(ids.size, 410, 'cursor pages cover every match exactly once');
assert.equal((await db.collection('donors').where('email', '==', 'migration_0409@example.com').get()).size, 1);
for (const request of await db.getAll(...[...ids].map((id) => db.doc(`requests/${id}`)))) {
  assert.equal(request.get('requester_phone'), undefined);
  assert.equal(request.get('matched_donor_phone'), undefined);
}
console.log('✓ dry-run migration, 410-record backfill, exact search, cursor pages and legacy phone cleanup');
process.exit(0);
