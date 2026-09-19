/**
 * adminBroadcastNotification — HTTP Callable Cloud Function
 *
 * Sends a custom push notification to all verified donors, or filtered by blood group.
 * Auth required: admin custom claim.
 *
 * Input payload:
 * {
 *   title: string,
 *   body: string,
 *   bloodGroup?: string,         // If set, only notify donors with this blood group
 *   availableOnly?: boolean,     // Default true — only notify available donors
 *   type?: string,               // Notification type tag (default: 'ADMIN_BROADCAST')
 *   data?: Record<string, string>, // Extra data payload
 * }
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');
const { sendPushToMultiple } = require('../utils/fcm');

const db = admin.firestore();

exports.adminBroadcastNotification = functions
  .runWith({ timeoutSeconds: 120, memory: '512MB' })
  .https.onCall(async (data, context) => {
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }

    const { title, body, bloodGroup, availableOnly = true, type = 'ADMIN_BROADCAST', data: extraData } = data;

    if (!title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'title and body are required.');
    }

    logger.info(`Admin ${context.auth.uid} broadcasting: "${title}" to ${bloodGroup || 'all'} donors`);

    // ── Build Firestore query ─────────────────────────────────────────────
    let query = db.collection('donors').where('is_verified', '==', true).where('is_banned', '!=', true);

    if (availableOnly) {
      query = query.where('is_available', '==', true);
    }
    if (bloodGroup) {
      query = query.where('blood_group', '==', bloodGroup);
    }

    const donorsSnap = await query.get();

    // Collect valid FCM tokens
    const tokens = [];
    donorsSnap.forEach((doc) => {
      const token = doc.data().fcm_token;
      if (token) tokens.push(token);
    });

    if (tokens.length === 0) {
      return {
        success: true,
        sent: 0,
        failed: 0,
        message: 'No eligible donors with FCM tokens found.',
      };
    }

    // ── Send multicast in batches of 500 (FCM limit) ──────────────────────
    const BATCH_SIZE = 500;
    let totalSent = 0;
    let totalFailed = 0;

    for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
      const batch = tokens.slice(i, i + BATCH_SIZE);
      try {
        const result = await sendPushToMultiple(batch, { title, body }, {
          type,
          ...extraData,
        });
        totalSent += result.successCount;
        totalFailed += result.failureCount;
      } catch (err) {
        logger.error('Multicast batch failed:', err.message);
        totalFailed += batch.length;
      }
    }

    // ── Audit log ─────────────────────────────────────────────────────────
    await db.collection('admin_audit_log').doc().set({
      action: 'BROADCAST_NOTIFICATION',
      performed_by: context.auth.uid,
      details: {
        title,
        body,
        bloodGroup: bloodGroup || 'all',
        availableOnly,
        totalTargeted: tokens.length,
        totalSent,
        totalFailed,
      },
      timestamp: admin.firestore.Timestamp.now(),
    });

    logger.info(`Broadcast complete. Sent: ${totalSent}, Failed: ${totalFailed}`);

    return {
      success: true,
      sent: totalSent,
      failed: totalFailed,
      targeted: tokens.length,
      message: `Notification sent to ${totalSent} donors. ${totalFailed} failed.`,
    };
  });
