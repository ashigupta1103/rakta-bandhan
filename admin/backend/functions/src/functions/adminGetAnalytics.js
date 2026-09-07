/**
 * adminGetAnalytics — HTTP Callable Cloud Function
 *
 * Returns time-series analytics data for the Admin Dashboard charts.
 * Auth required: admin custom claim.
 *
 * Input payload:
 * {
 *   period: '7d' | '30d' | '90d' | '12m',  // time window
 * }
 *
 * Returns:
 * {
 *   requestsByDay: Array<{ date: string, total: number, fulfilled: number, expired: number }>,
 *   donorsByDay: Array<{ date: string, total: number, verified: number }>,
 *   donationsByMonth: Array<{ month: string, count: number }>,
 *   bloodGroupDistribution: Array<{ group: string, count: number }>,
 *   fulfillmentRateByUrgency: Array<{ urgency: string, rate: number }>,
 *   topHospitals: Array<{ name: string, requestCount: number }>,
 * }
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');

const db = admin.firestore();

function subtractDays(days) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  d.setHours(0, 0, 0, 0);
  return d;
}

function formatDate(date) {
  return date.toISOString().split('T')[0];
}

function formatMonth(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

exports.adminGetAnalytics = functions
  .runWith({ timeoutSeconds: 120, memory: '512MB' })
  .https.onCall(async (data, context) => {
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }

    const period = data?.period || '30d';
    const periodDaysMap = { '7d': 7, '30d': 30, '90d': 90, '12m': 365 };
    const days = periodDaysMap[period] || 30;

    const since = subtractDays(days);
    const sinceTimestamp = admin.firestore.Timestamp.fromDate(since);

    logger.info(`Analytics requested by ${context.auth.uid} for period: ${period}`);

    try {
      const [requestsSnap, donorsSnap, donationHistorySnap] = await Promise.all([
        db.collection('requests').where('created_at', '>=', sinceTimestamp).get(),
        db.collection('donors').get(),
        db.collection('donation_history').where('donation_date', '>=', sinceTimestamp).get(),
      ]);

      // ── Requests by day ────────────────────────────────────────────────
      const requestsByDayMap = {};
      requestsSnap.forEach((doc) => {
        const r = doc.data();
        if (!r.created_at) return;
        const dateKey = formatDate(r.created_at.toDate());
        if (!requestsByDayMap[dateKey]) {
          requestsByDayMap[dateKey] = { date: dateKey, total: 0, fulfilled: 0, expired: 0, open: 0, matched: 0 };
        }
        requestsByDayMap[dateKey].total++;
        if (r.status === 'fulfilled') requestsByDayMap[dateKey].fulfilled++;
        if (r.status === 'expired') requestsByDayMap[dateKey].expired++;
        if (r.status === 'open') requestsByDayMap[dateKey].open++;
        if (r.status === 'matched') requestsByDayMap[dateKey].matched++;
      });
      const requestsByDay = Object.values(requestsByDayMap).sort((a, b) => a.date.localeCompare(b.date));

      // ── Blood group distribution of all donors ─────────────────────────
      const bloodGroupMap = {};
      donorsSnap.forEach((doc) => {
        const bg = doc.data().blood_group;
        if (bg) bloodGroupMap[bg] = (bloodGroupMap[bg] || 0) + 1;
      });
      const bloodGroupDistribution = Object.entries(bloodGroupMap).map(([group, count]) => ({ group, count }));

      // ── Donors registered by day (in the period) ───────────────────────
      const donorsByDayMap = {};
      donorsSnap.forEach((doc) => {
        const d = doc.data();
        if (!d.created_at) return;
        const createdDate = d.created_at.toDate();
        if (createdDate < since) return;
        const dateKey = formatDate(createdDate);
        if (!donorsByDayMap[dateKey]) {
          donorsByDayMap[dateKey] = { date: dateKey, total: 0, verified: 0 };
        }
        donorsByDayMap[dateKey].total++;
        if (d.is_verified) donorsByDayMap[dateKey].verified++;
      });
      const donorsByDay = Object.values(donorsByDayMap).sort((a, b) => a.date.localeCompare(b.date));

      // ── Donations by month ─────────────────────────────────────────────
      const donationsByMonthMap = {};
      donationHistorySnap.forEach((doc) => {
        const d = doc.data();
        if (!d.donation_date) return;
        const monthKey = formatMonth(d.donation_date.toDate());
        donationsByMonthMap[monthKey] = (donationsByMonthMap[monthKey] || 0) + 1;
      });
      const donationsByMonth = Object.entries(donationsByMonthMap)
        .map(([month, count]) => ({ month, count }))
        .sort((a, b) => a.month.localeCompare(b.month));

      // ── Fulfillment rate by urgency ────────────────────────────────────
      const urgencyMap = {};
      requestsSnap.forEach((doc) => {
        const r = doc.data();
        const urgency = r.urgency || 'normal';
        if (!urgencyMap[urgency]) urgencyMap[urgency] = { total: 0, fulfilled: 0 };
        urgencyMap[urgency].total++;
        if (r.status === 'fulfilled') urgencyMap[urgency].fulfilled++;
      });
      const fulfillmentRateByUrgency = Object.entries(urgencyMap).map(([urgency, { total, fulfilled }]) => ({
        urgency,
        total,
        fulfilled,
        rate: total > 0 ? Math.round((fulfilled / total) * 100) : 0,
      }));

      // ── Top hospitals by request count ─────────────────────────────────
      const hospitalCountMap = {};
      requestsSnap.forEach((doc) => {
        const hospitalId = doc.data().hospital_id;
        if (hospitalId) hospitalCountMap[hospitalId] = (hospitalCountMap[hospitalId] || 0) + 1;
      });

      // Fetch hospital names for top 5
      const topHospitalIds = Object.entries(hospitalCountMap)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([id]) => id);

      const topHospitals = [];
      if (topHospitalIds.length > 0) {
        const hosSnaps = await Promise.all(topHospitalIds.map((id) => db.collection('hospitals').doc(id).get()));
        hosSnaps.forEach((snap, i) => {
          topHospitals.push({
            hospitalId: topHospitalIds[i],
            name: snap.exists ? snap.data().name : `Hospital (${topHospitalIds[i].slice(0, 6)}...)`,
            requestCount: hospitalCountMap[topHospitalIds[i]],
          });
        });
      }

      return {
        period,
        generatedAt: new Date().toISOString(),
        requestsByDay,
        donorsByDay,
        donationsByMonth,
        bloodGroupDistribution,
        fulfillmentRateByUrgency,
        topHospitals,
      };
    } catch (error) {
      logger.error('adminGetAnalytics error:', error);
      throw new functions.https.HttpsError('internal', 'Failed to fetch analytics data.');
    }
  });
