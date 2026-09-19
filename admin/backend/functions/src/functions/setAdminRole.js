/**
 * setAdminRole — HTTP Callable Cloud Function
 *
 * Called by: Super-admin (the initial admin set manually in Firebase Console)
 * Auth required: Must already have admin custom claim
 *
 * Input payload:
 * {
 *   targetUid: string,    // UID of user to promote/demote
 *   isAdmin: boolean,     // true = grant admin, false = revoke admin
 * }
 *
 * Flow:
 *  1. Verify caller is already an admin
 *  2. Set/revoke custom claim { admin: true/false } on targetUid
 *  3. Log the action to /admin_audit_log
 *
 * NOTE: After setting a custom claim, the user must sign out and
 * sign back in for the new claim to take effect in their ID token.
 *
 * BOOTSTRAPPING: To create the very first admin, run this in
 * Firebase Admin SDK (e.g., a one-off script):
 *   admin.auth().setCustomUserClaims(uid, { admin: true })
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');

const db = admin.firestore();

exports.setAdminRole = functions
  .runWith({ timeoutSeconds: 30, memory: '128MB' })
  .https.onCall(async (data, context) => {
    // ── Auth check: caller must be admin ──────────────────────────────────
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only existing admins can manage admin roles.'
      );
    }

    // ── Input validation ──────────────────────────────────────────────────
    const { targetUid, isAdmin } = data;

    if (!targetUid || typeof targetUid !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'targetUid is required.');
    }
    if (typeof isAdmin !== 'boolean') {
      throw new functions.https.HttpsError('invalid-argument', 'isAdmin must be a boolean.');
    }

    // Prevent self-demotion (accidental lockout)
    if (targetUid === context.auth.uid && isAdmin === false) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'You cannot revoke your own admin role. Ask another admin to do this.'
      );
    }

    logger.info(`Admin ${context.auth.uid} setting admin=${isAdmin} for user ${targetUid}`);

    // ── Verify target user exists ─────────────────────────────────────────
    let targetUser;
    try {
      targetUser = await admin.auth().getUser(targetUid);
    } catch (error) {
      throw new functions.https.HttpsError('not-found', `User ${targetUid} not found in Firebase Auth.`);
    }

    // ── Set custom claim ──────────────────────────────────────────────────
    await admin.auth().setCustomUserClaims(targetUid, { admin: isAdmin });

    // ── Log to audit trail ────────────────────────────────────────────────
    const auditRef = db.collection('admin_audit_log').doc();
    await auditRef.set({
      action: isAdmin ? 'GRANT_ADMIN' : 'REVOKE_ADMIN',
      performed_by: context.auth.uid,
      target_uid: targetUid,
      target_email: targetUser.email || null,
      timestamp: admin.firestore.Timestamp.now(),
    });

    const action = isAdmin ? 'granted' : 'revoked';
    logger.info(`Admin role ${action} for user ${targetUid} (${targetUser.email}). Audit: ${auditRef.id}`);

    return {
      success: true,
      message: `Admin role ${action} for ${targetUser.email || targetUid}. The user must sign out and back in for changes to take effect.`,
    };
  });
