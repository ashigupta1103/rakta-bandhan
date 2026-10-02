// What happens to the sign-in account when an admin bans, unbans or removes a
// donor. The consoles only write Firestore (is_banned, or deleting the donor
// doc); these functions carry that through to Firebase Auth, which the app
// can't touch for someone else. Both are idempotent.

import { onDocumentDeleted, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';

import { auth, db } from './app';
import { banTransition } from './lifecycle';

const userGone = (e: unknown) => (e as { code?: string }).code === 'auth/user-not-found';

/**
 * Ban: the account is disabled (it can't sign in again) and every device is
 * has its refresh sessions revoked. Unban: it can sign in again. The rules already stop a
 * banned donor writing; this closes the sign-in door too.
 */
export const onDonorUpdated = onDocumentUpdated('donors/{uid}', async (event) => {
  const change = banTransition(event.data?.before.data(), event.data?.after.data());
  if (!change) return;
  const { uid } = event.params;
  try {
    await auth.updateUser(uid, { disabled: change === 'ban' });
    if (change === 'ban') await auth.revokeRefreshTokens(uid);
    logger.info(change === 'ban' ? 'account disabled' : 'account re-enabled', { uid });
  } catch (e) {
    if (!userGone(e)) throw e;
  }
});

/**
 * Removing a donor (an admin deleting them, or the last step of in-app
 * deletion) leaves nothing behind: Firestore doesn't delete a document's
 * subcollections with it, so they go here, and so does the sign-in account.
 */
export const onDonorDeleted = onDocumentDeleted('donors/{uid}', async (event) => {
  const { uid } = event.params;
  const username = event.data?.get('username');
  if (typeof username === 'string') {
    const claim = db.doc(`usernames/${username}`);
    await db.runTransaction(async (tx) => {
      // A released name may already belong to someone else by the time this
      // event is delivered. Never remove the new owner's claim.
      if ((await tx.get(claim)).get('uid') === uid) tx.delete(claim);
    });
  }
  await db.recursiveDelete(db.doc(`donors/${uid}`));
  try {
    await auth.deleteUser(uid);
  } catch (e) {
    if (!userGone(e)) throw e;
  }
  logger.info('donor removed', { uid });
});
