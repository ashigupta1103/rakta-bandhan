/**
 * adminBanUser — HTTP Callable Cloud Function
 *
 * Bans or unbans a user from the platform.
 * Banned users: marked in Firestore, Firebase Auth disabled, FCM token cleared.
 * Auth required: admin custom claim.
 *
 * Input payload:
 * {
 *   targetUid: string,
 *   isBanned: boolean,
 *   reason?: string,
 * }
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');

const db = admin.firestore();

exports.adminBanUser = functions
  .runWith({ timeoutSeconds: 30, memory: '128MB' })
  .https.onCall(async (data, context) => {
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }

    const { targetUid, isBanned, reason } = data;

    if (!targetUid || typeof targetUid !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'targetUid is required.');
    }
    if (typeof isBanned !== 'boolean') {
      throw new functions.https.HttpsError('invalid-argument', 'isBanned must be a boolean.');
    }

    // Prevent self-ban
    if (targetUid === context.auth.uid) {
      throw new functions.https.HttpsError('failed-precondition', 'You cannot ban your own account.');
    }

    logger.info(`Admin ${context.auth.uid} ${isBanned ? 'banning' : 'unbanning'} user ${targetUid}`);

    // Verify Firebase Auth user exists
    let authUser;
    try {
      authUser = await admin.auth().getUser(targetUid);
    } catch {
      throw new functions.https.HttpsError('not-found', `User ${targetUid} not found in Firebase Auth.`);
    }

    // Disable/enable Firebase Auth account
    await admin.auth().updateUser(targetUid, { disabled: isBanned });

    // Update donor document (if exists)
    const donorRef = db.collection('donors').doc(targetUid);
    const donorSnap = await donorRef.get();

    const batch = db.batch();

    if (donorSnap.exists) {
      batch.update(donorRef, {
        is_banned: isBanned,
        is_available: isBanned ? false : donorSnap.data().is_available,
        ban_reason: isBanned ? (reason || 'Banned by admin') : null,
        banned_at: isBanned ? admin.firestore.Timestamp.now() : null,
        banned_by: isBanned ? context.auth.uid : null,
        fcm_token: isBanned ? null : donorSnap.data().fcm_token, // Clear token on ban
        updated_at: admin.firestore.Timestamp.now(),
      });
    }

    // Audit log
    const auditRef = db.collection('admin_audit_log').doc();
    batch.set(auditRef, {
      action: isBanned ? 'BAN_USER' : 'UNBAN_USER',
      performed_by: context.auth.uid,
      target_uid: targetUid,
      target_email: authUser.email || null,
      reason: reason || null,
      timestamp: admin.firestore.Timestamp.now(),
    });

    await batch.commit();

    return {
      success: true,
      targetUid,
      isBanned,
      message: `User ${authUser.email || targetUid} has been ${isBanned ? 'banned' : 'unbanned'}.`,
    };
  });
