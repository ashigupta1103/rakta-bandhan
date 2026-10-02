// Owner-run, paged migration. Default is a dry run; no records or values logged.
// node scripts/backfill-search.mjs --emulator [--apply] [--cleanup-request-phones]
// Owner only: --project <id> --yes-live [--apply] [--cleanup-request-phones]
import { initializeApp } from 'firebase-admin/app';
import { FieldPath, FieldValue, getFirestore } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const emulator = args.includes('--emulator');
const project = args[args.indexOf('--project') + 1];
if (!emulator && (!args.includes('--yes-live') || !args.includes('--project') || !project || project.startsWith('--'))) {
  console.error('Use --emulator, or an explicit --project <id> --yes-live. Default is dry run.');
  process.exit(1);
}
if (emulator) process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
else if (process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Unset emulator host before an owner live migration.');
initializeApp({ projectId: emulator ? 'demo-rakta-bandhan' : project });
const db = getFirestore();
const apply = args.includes('--apply');

async function migrate(collection, patchFor) {
  let cursor, changed = 0;
  for (;;) {
    let query = db.collection(collection).orderBy(FieldPath.documentId()).limit(200);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    const batch = db.batch();
    let writes = 0;
    for (const doc of page.docs) {
      const patch = patchFor(doc.data());
      if (!patch) continue;
      writes++; changed++;
      if (apply) batch.update(doc.ref, patch);
    }
    if (apply && writes) await batch.commit();
    cursor = page.docs.at(-1);
    if (page.size < 200) break;
  }
  console.log(`${collection}: ${changed} records ${apply ? 'updated' : 'would change (dry run)'}`);
}

await migrate('donors', (data) => {
  const lower = typeof data.name === 'string' ? data.name.trim().toLowerCase() : '';
  return data.name_lower === lower ? null : { name_lower: lower };
});
if (args.includes('--cleanup-request-phones')) {
  await migrate('requests', (data) => ('requester_phone' in data || 'matched_donor_phone' in data)
    ? { requester_phone: FieldValue.delete(), matched_donor_phone: FieldValue.delete() } : null);
}
