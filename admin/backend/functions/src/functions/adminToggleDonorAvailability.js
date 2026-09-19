/**
 * adminToggleDonorAvailability — HTTP Callable Cloud Function
 *
 * Admin-forced toggle of a donor's is_available flag.
 * Used when a donor is not responding or admin needs to override.
 * Auth required: admin custom claim.
 *
 * Input payload:
 * {
 *   donorId: string,
 *   isAvailable: boolean,
 *   reason?: string,
 * }
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');

const db = admin.firestore();

exports.adminToggleDonorAvailability = functions
  .runWith({ timeoutSeconds: 20, memory: '128MB' })
  .https.onCall(async (data, context) => {
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }

    const { donorId, isAvailable, reason } = data;

    if (!donorId || typeof donorId !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'donorId is required.');
    }
    if (typeof isAvailable !== 'boolean') {
      throw new functions.https.HttpsError('invalid-argument', 'isAvailable must be a boolean.');
    }

    const donorRef = db.collection('donors').doc(donorId);
    const donorSnap = await donorRef.get();

    if (!donorSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Donor ${donorId} not found.`);
    }

    const donorData = donorSnap.data();
    logger.info(`Admin ${context.auth.uid} toggling donor ${donorId} availability to ${isAvailable}`);

    const batch = db.batch();

    batch.update(donorRef, {
      is_available: isAvailable,
      availability_override_by: context.auth.uid,
      availability_override_at: admin.firestore.Timestamp.now(),
      availability_override_reason: reason || null,
      updated_at: admin.firestore.Timestamp.now(),
    });

    const auditRef = db.collection('admin_audit_log').doc();
    batch.set(auditRef, {
      action: isAvailable ? 'FORCE_DONOR_AVAILABLE' : 'FORCE_DONOR_UNAVAILABLE',
      performed_by: context.auth.uid,
      target_uid: donorId,
      target_name: donorData.name || null,
      reason: reason || null,
      timestamp: admin.firestore.Timestamp.now(),
    });

    await batch.commit();

    return {
      success: true,
      donorId,
      isAvailable,
      message: `Donor ${donorData.name} availability set to ${isAvailable ? 'available' : 'unavailable'} by admin.`,
    };
  });
