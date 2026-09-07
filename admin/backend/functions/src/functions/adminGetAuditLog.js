/**
 * adminGetAuditLog — HTTP Callable Cloud Function
 *
 * Returns paginated admin audit trail for compliance and oversight.
 * Auth required: admin custom claim.
 *
 * Input payload:
 * {
 *   limit?: number,        // default 50, max 200
 *   startAfter?: string,   // doc ID for pagination cursor
 *   action?: string,       // filter by action type
 *   performedBy?: string,  // filter by admin UID
 * }
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');

const db = admin.firestore();

exports.adminGetAuditLog = functions
  .runWith({ timeoutSeconds: 30, memory: '128MB' })
  .https.onCall(async (data, context) => {
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }

    const { limit = 50, startAfter, action, performedBy } = data || {};
    const safeLimit = Math.min(Number(limit) || 50, 200);

    logger.info(`Audit log requested by admin: ${context.auth.uid}`);

    let query = db.collection('admin_audit_log').orderBy('timestamp', 'desc');

    if (action) query = query.where('action', '==', action);
    if (performedBy) query = query.where('performed_by', '==', performedBy);

    if (startAfter) {
      const cursorDoc = await db.collection('admin_audit_log').doc(startAfter).get();
      if (cursorDoc.exists) query = query.startAfter(cursorDoc);
    }

    query = query.limit(safeLimit);

    const snap = await query.get();

    const entries = snap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate().toISOString() || null,
    }));

    return {
      entries,
      count: entries.length,
      hasMore: entries.length === safeLimit,
      lastId: entries.length > 0 ? entries[entries.length - 1].id : null,
    };
  });
