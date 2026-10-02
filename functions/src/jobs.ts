// Scheduled work, kept separate from the schedule itself (index.ts) so the
// emulator smoke test can run it directly.

import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from './app';
import { dueForReactivation } from './lifecycle';

export interface PushTarget {
  uid: string;
  token: string;
}

// Two writes per donor; keep every commit within 400 writes.
const PAGE = 200;
/** A safety stop: 50 pages is 10,000 donors in one run. */
const MAX_PAGES = 50;

/**
 * Switches donors whose rest period has ended back to available (private and
 * public docs) and clears the schedule, so a later manual switch-off isn't
 * overridden. Banned donors are skipped. `notify` receives the ones with a
 * push token. The app does the same when a donor opens it
 * (Backend.maybeReactivate); this covers donors who don't. Returns the count.
 */
export async function reactivateDueDonors(nowMs: number, notify: (targets: PushTarget[]) => Promise<unknown>): Promise<number> {
  let total = 0;
  for (let page = 0; page < MAX_PAGES; page++) {
    const snap = await db
      .collection('donors')
      .where('is_available', '==', false)
      .where('is_banned', '==', false)
      .where('reactivation_scheduled_at', '<=', Timestamp.fromMillis(nowMs))
      .limit(PAGE)
      .get();
    const due = snap.docs.filter((d) => dueForReactivation(d.data(), nowMs));
    if (due.length === 0) break;

    const batch = db.batch();
    for (const doc of due) {
      batch.update(doc.ref, { is_available: true, reactivation_scheduled_at: FieldValue.delete() });
      batch.set(db.doc(`donors_public/${doc.id}`), { is_available: true, updated_at: FieldValue.serverTimestamp() }, { merge: true });
    }
    await batch.commit();
    total += due.length;

    const targets = due.flatMap((d) => {
      const token = d.get('fcm_token');
      return typeof token === 'string' && token.length > 0 ? [{ uid: d.id, token }] : [];
    });
    if (targets.length > 0) await notify(targets);
    // A donor the check above skipped would match the query forever.
    if (snap.size < PAGE || due.length < snap.size) break;
  }
  return total;
}
