/**
 * adminGetDashboardStats — HTTP Callable Cloud Function
 *
 * Returns aggregated KPI metrics for the Admin Dashboard homepage.
 * Auth required: admin custom claim.
 *
 * Returns:
 * {
 *   totalDonors: number,
 *   verifiedDonors: number,
 *   availableDonors: number,
 *   bannedUsers: number,
 *   totalRequests: number,
 *   openRequests: number,
 *   fulfilledRequests: number,
 *   expiredRequests: number,
 *   cancelledRequests: number,
 *   totalHospitals: number,
 *   verifiedHospitals: number,
 *   totalDonations: number,
 *   donationsThisMonth: number,
 *   fulfillmentRate: number,         // % of non-expired requests that got fulfilled
 *   avgResponseTimeMinutes: number,  // avg time from request creation to match
 *   recentRequests: Array,           // last 5 requests
 *   recentDonors: Array,             // last 5 registered donors
 * }
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');

const db = admin.firestore();

exports.adminGetDashboardStats = functions
  .runWith({ timeoutSeconds: 60, memory: '256MB' })
  .https.onCall(async (data, context) => {
    // ── Auth check ────────────────────────────────────────────────────────
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }

    logger.info(`Dashboard stats requested by admin: ${context.auth.uid}`);

    try {
      // ── Parallel Firestore queries ─────────────────────────────────────
      const [
        donorsSnap,
        requestsSnap,
        hospitalsSnap,
        donationHistorySnap,
        recentRequestsSnap,
        recentDonorsSnap,
      ] = await Promise.all([
        db.collection('donors').get(),
        db.collection('requests').get(),
        db.collection('hospitals').get(),
        db.collection('donation_history').get(),
        db.collection('requests')
          .orderBy('created_at', 'desc')
          .limit(5)
          .get(),
        db.collection('donors')
          .orderBy('created_at', 'desc')
          .limit(5)
          .get(),
      ]);

      // ── Aggregate donor stats ──────────────────────────────────────────
      let totalDonors = 0;
      let verifiedDonors = 0;
      let availableDonors = 0;
      let bannedUsers = 0;

      donorsSnap.forEach((doc) => {
        const d = doc.data();
        totalDonors++;
        if (d.is_verified) verifiedDonors++;
        if (d.is_available && !d.is_banned) availableDonors++;
        if (d.is_banned) bannedUsers++;
      });

      // ── Aggregate request stats ────────────────────────────────────────
      let totalRequests = 0;
      let openRequests = 0;
      let fulfilledRequests = 0;
      let expiredRequests = 0;
      let cancelledRequests = 0;
      let matchedRequests = 0;
      let totalResponseMs = 0;
      let responseCount = 0;

      requestsSnap.forEach((doc) => {
        const r = doc.data();
        totalRequests++;
        switch (r.status) {
          case 'open':      openRequests++;      break;
          case 'fulfilled': fulfilledRequests++;  break;
          case 'expired':   expiredRequests++;    break;
          case 'cancelled': cancelledRequests++;  break;
          case 'matched':   matchedRequests++;    break;
        }
        // Calculate response time if matched_at and created_at exist
        if (r.matched_at && r.created_at) {
          const ms = r.matched_at.toMillis() - r.created_at.toMillis();
          if (ms > 0) {
            totalResponseMs += ms;
            responseCount++;
          }
        }
      });

      const closedRequests = fulfilledRequests + expiredRequests + cancelledRequests;
      const fulfillmentRate = closedRequests > 0
        ? Math.round((fulfilledRequests / (fulfilledRequests + expiredRequests)) * 100)
        : 0;

      const avgResponseTimeMinutes = responseCount > 0
        ? Math.round(totalResponseMs / responseCount / 60000)
        : 0;

      // ── Aggregate hospital stats ───────────────────────────────────────
      let totalHospitals = 0;
      let verifiedHospitals = 0;

      hospitalsSnap.forEach((doc) => {
        totalHospitals++;
        if (doc.data().verified) verifiedHospitals++;
      });

      // ── Aggregate donation stats ───────────────────────────────────────
      const totalDonations = donationHistorySnap.size;
      const now = new Date();
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

      let donationsThisMonth = 0;
      donationHistorySnap.forEach((doc) => {
        const d = doc.data();
        if (d.donation_date && d.donation_date.toDate() >= startOfMonth) {
          donationsThisMonth++;
        }
      });

      // ── Format recent records ──────────────────────────────────────────
      const recentRequests = recentRequestsSnap.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
        created_at: doc.data().created_at?.toDate().toISOString() || null,
      }));

      const recentDonors = recentDonorsSnap.docs.map((doc) => ({
        id: doc.id,
        name: doc.data().name,
        blood_group: doc.data().blood_group,
        is_verified: doc.data().is_verified,
        is_available: doc.data().is_available,
        created_at: doc.data().created_at?.toDate().toISOString() || null,
      }));

      return {
        totalDonors,
        verifiedDonors,
        availableDonors,
        bannedUsers,
        totalRequests,
        openRequests,
        matchedRequests,
        fulfilledRequests,
        expiredRequests,
        cancelledRequests,
        totalHospitals,
        verifiedHospitals,
        totalDonations,
        donationsThisMonth,
        fulfillmentRate,
        avgResponseTimeMinutes,
        recentRequests,
        recentDonors,
      };
    } catch (error) {
      logger.error('adminGetDashboardStats error:', error);
      throw new functions.https.HttpsError('internal', 'Failed to fetch dashboard stats.');
    }
  });
