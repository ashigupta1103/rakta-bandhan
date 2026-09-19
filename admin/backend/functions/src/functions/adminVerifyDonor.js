/**
 * adminVerifyDonor — HTTP Callable Cloud Function
 *
 * Called by: Admin Dashboard to approve or reject a donor's verification.
 * Auth required: admin custom claim.
 *
 * Input payload:
 * {
 *   donorId: string,       // UID of the donor to verify/unverify
 *   isVerified: boolean,   // true = approve, false = reject/revoke
 *   reason?: string,       // Optional rejection reason
 * }
 *
 * Flow:
 *  1. Validate admin auth
 *  2. Validate donor exists
 *  3. Set is_verified on donor document
 *  4. Send FCM to donor notifying them of the outcome
 *  5. Write audit log
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');
const { sendPushToToken } = require('../utils/fcm');

const db = admin.firestore();

exports.adminVerifyDonor = functions
  .runWith({ timeoutSeconds: 30, memory: '128MB' })
  .https.onCall(async (data, context) => {
    // ── Auth check ────────────────────────────────────────────────────────
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }

    // ── Input validation ──────────────────────────────────────────────────
    const { donorId, isVerified, reason } = data;

    if (!donorId || typeof donorId !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'donorId is required.');
    }
    if (typeof isVerified !== 'boolean') {
      throw new functions.https.HttpsError('invalid-argument', 'isVerified must be a boolean.');
    }

    // ── Fetch donor ───────────────────────────────────────────────────────
    const donorRef = db.collection('donors').doc(donorId);
    const donorSnap = await donorRef.get();

    if (!donorSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Donor ${donorId} not found.`);
    }

    const donorData = donorSnap.data();
    logger.info(`Admin ${context.auth.uid} ${isVerified ? 'verifying' : 'unverifying'} donor ${donorId}`);

    // ── Update donor document ─────────────────────────────────────────────
    const batch = db.batch();

    batch.update(donorRef, {
      is_verified: isVerified,
      verified_at: isVerified ? admin.firestore.Timestamp.now() : null,
      verified_by: isVerified ? context.auth.uid : null,
      rejection_reason: isVerified ? null : (reason || 'Verification not approved by admin'),
      updated_at: admin.firestore.Timestamp.now(),
    });

    // ── Audit log ─────────────────────────────────────────────────────────
    const auditRef = db.collection('admin_audit_log').doc();
    batch.set(auditRef, {
      action: isVerified ? 'VERIFY_DONOR' : 'UNVERIFY_DONOR',
      performed_by: context.auth.uid,
      target_uid: donorId,
      target_name: donorData.name || null,
      reason: reason || null,
      timestamp: admin.firestore.Timestamp.now(),
    });

    await batch.commit();

    // ── Send FCM notification to donor ────────────────────────────────────
    if (donorData.fcm_token) {
      const notifPayload = isVerified
        ? {
            title: '✅ Verification Approved!',
            body: 'Congratulations! Your donor profile has been verified. You can now receive blood requests.',
          }
        : {
            title: '❌ Verification Not Approved',
            body: reason
              ? `Your verification was not approved. Reason: ${reason}`
              : 'Your verification was not approved. Please contact support.',
          };

      await sendPushToToken(donorData.fcm_token, notifPayload, {
        type: isVerified ? 'DONOR_VERIFIED' : 'DONOR_UNVERIFIED',
      }).catch((err) => logger.warn('FCM send failed (non-critical):', err.message));
    }

    return {
      success: true,
      donorId,
      isVerified,
      message: isVerified
        ? `Donor ${donorData.name} has been verified and will now receive blood requests.`
        : `Donor ${donorData.name} verification has been revoked.`,
    };
  });
