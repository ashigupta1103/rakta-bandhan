/**
 * onDonationConfirmed — HTTP Callable Cloud Function
 *
 * Called by: Admin Dashboard (React) after verifying a donation occurred
 * Auth required: Admin role (custom claim: admin == true)
 *
 * Input payload:
 * {
 *   donorId: string,        // UID of the donor who donated
 *   requestId: string,      // The blood request that was fulfilled
 *   hospitalId?: string,    // Optional hospital where donation happened
 *   donationDate?: string,  // ISO date string; defaults to now
 * }
 *
 * Flow:
 *  1. Validate caller is an admin
 *  2. Validate input fields
 *  3. Write to /donation_history
 *  4. Update donor: last_donation_date, is_available = false,
 *     reactivation_scheduled_at = now + 90 days
 *  5. Update request: status = "fulfilled", fulfilled_at
 *  6. Send FCM to donor: "Thank you for your donation!"
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');

const { sendPushToToken } = require('../utils/fcm');
const { DONOR_COOLDOWN_MS, REQUEST_STATUS } = require('../config/constants');

const db = admin.firestore();

exports.onDonationConfirmed = functions
  .runWith({ timeoutSeconds: 30, memory: '256MB' })
  .https.onCall(async (data, context) => {
    // ── Auth check: must be admin ──────────────────────────────────────────
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can confirm donations.'
      );
    }

    // ── Input validation ──────────────────────────────────────────────────
    const { donorId, requestId, hospitalId, donationDate } = data;

    if (!donorId || typeof donorId !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'donorId is required.');
    }
    if (!requestId || typeof requestId !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'requestId is required.');
    }

    // Parse donation date — default to now
    let donationTimestamp;
    if (donationDate) {
      const parsed = new Date(donationDate);
      if (isNaN(parsed.getTime())) {
        throw new functions.https.HttpsError('invalid-argument', 'donationDate is not a valid ISO date string.');
      }
      donationTimestamp = admin.firestore.Timestamp.fromDate(parsed);
    } else {
      donationTimestamp = admin.firestore.Timestamp.now();
    }

    logger.info(`Admin ${context.auth.uid} confirming donation: donor=${donorId}, request=${requestId}`);

    // ── Fetch donor document ───────────────────────────────────────────────
    const donorRef = db.collection('donors').doc(donorId);
    const donorSnap = await donorRef.get();

    if (!donorSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Donor ${donorId} not found.`);
    }

    // ── Fetch request document ────────────────────────────────────────────
    const requestRef = db.collection('requests').doc(requestId);
    const requestSnap = await requestRef.get();

    if (!requestSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Request ${requestId} not found.`);
    }

    // ── Calculate reactivation date (90 days from donation) ───────────────
    const reactivationDate = new Date(donationTimestamp.toMillis() + DONOR_COOLDOWN_MS);
    const reactivationTimestamp = admin.firestore.Timestamp.fromDate(reactivationDate);

    // ── Batch write all updates ───────────────────────────────────────────
    const batch = db.batch();

    // 1. Create donation history record
    const historyRef = db.collection('donation_history').doc();
    batch.set(historyRef, {
      record_id: historyRef.id,
      donor_id: donorId,
      request_id: requestId,
      hospital_id: hospitalId || null,
      donation_date: donationTimestamp,
      verified_by: context.auth.uid,
      created_at: admin.firestore.Timestamp.now(),
    });

    // 2. Update donor: start cooldown, mark unavailable
    batch.update(donorRef, {
      last_donation_date: donationTimestamp,
      is_available: false,
      reactivation_scheduled_at: reactivationTimestamp,
    });

    // 3. Update request: mark fulfilled
    batch.update(requestRef, {
      status: REQUEST_STATUS.FULFILLED,
      fulfilled_at: admin.firestore.Timestamp.now(),
      fulfilled_by: context.auth.uid,
    });

    await batch.commit();

    logger.info(`Donation confirmed. Record: ${historyRef.id}. Reactivation scheduled: ${reactivationDate.toISOString()}`);

    // ── Send thank-you FCM to the donor ───────────────────────────────────
    const donorData = donorSnap.data();
    if (donorData.fcm_token) {
      await sendPushToToken(
        donorData.fcm_token,
        {
          title: '🙏 Thank You for Donating!',
          body: `You've saved a life today. You can donate again after ${reactivationDate.toLocaleDateString('en-IN')}. Rest well!`,
        },
        {
          type: 'DONATION_CONFIRMED',
          reactivationDate: reactivationDate.toISOString(),
        }
      );
    }

    return {
      success: true,
      donationRecordId: historyRef.id,
      reactivationDate: reactivationDate.toISOString(),
      message: `Donation confirmed. Donor will be reactivated on ${reactivationDate.toLocaleDateString('en-IN')}.`,
    };
  });
