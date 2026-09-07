/**
 * adminManageHospital — HTTP Callable Cloud Function
 *
 * Full CRUD for hospital records from the admin dashboard.
 * Auth required: admin custom claim.
 *
 * Input payload:
 * {
 *   action: 'create' | 'update' | 'delete' | 'toggleVerified',
 *   hospitalId?: string,     // required for update/delete/toggleVerified
 *   name?: string,
 *   address?: string,
 *   city?: string,
 *   state?: string,
 *   lat?: number,
 *   lng?: number,
 *   contact_phone?: string,
 *   contact_email?: string,
 *   verified?: boolean,
 * }
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');

const db = admin.firestore();

exports.adminManageHospital = functions
  .runWith({ timeoutSeconds: 30, memory: '128MB' })
  .https.onCall(async (data, context) => {
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }

    const { action, hospitalId } = data;

    if (!action || !['create', 'update', 'delete', 'toggleVerified'].includes(action)) {
      throw new functions.https.HttpsError('invalid-argument', 'action must be create, update, delete, or toggleVerified.');
    }

    logger.info(`Admin ${context.auth.uid} performing hospital action: ${action}, hospitalId: ${hospitalId || 'new'}`);

    const hospitalsCol = db.collection('hospitals');

    // ── CREATE ────────────────────────────────────────────────────────────
    if (action === 'create') {
      const { name, address, city, state, lat, lng, contact_phone, contact_email } = data;

      if (!name || !address || !contact_phone) {
        throw new functions.https.HttpsError('invalid-argument', 'name, address, and contact_phone are required for create.');
      }

      const newRef = hospitalsCol.doc();
      const hospitalData = {
        hospital_id: newRef.id,
        name,
        address,
        city: city || null,
        state: state || null,
        lat: lat || null,
        lng: lng || null,
        contact_phone,
        contact_email: contact_email || null,
        verified: false,
        created_by: context.auth.uid,
        created_at: admin.firestore.Timestamp.now(),
        updated_at: admin.firestore.Timestamp.now(),
      };

      await newRef.set(hospitalData);

      // Audit
      await db.collection('admin_audit_log').doc().set({
        action: 'CREATE_HOSPITAL',
        performed_by: context.auth.uid,
        target_id: newRef.id,
        target_name: name,
        timestamp: admin.firestore.Timestamp.now(),
      });

      return { success: true, action: 'created', hospitalId: newRef.id, data: hospitalData };
    }

    // ── VERIFY hospitalId exists for all other actions ─────────────────
    if (!hospitalId) {
      throw new functions.https.HttpsError('invalid-argument', 'hospitalId is required for this action.');
    }

    const hospitalRef = hospitalsCol.doc(hospitalId);
    const hospitalSnap = await hospitalRef.get();

    if (!hospitalSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Hospital ${hospitalId} not found.`);
    }

    // ── UPDATE ────────────────────────────────────────────────────────────
    if (action === 'update') {
      const updates = {};
      const allowedFields = ['name', 'address', 'city', 'state', 'lat', 'lng', 'contact_phone', 'contact_email', 'verified'];
      allowedFields.forEach((field) => {
        if (data[field] !== undefined) updates[field] = data[field];
      });

      if (Object.keys(updates).length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'No valid fields to update.');
      }

      updates.updated_at = admin.firestore.Timestamp.now();
      updates.updated_by = context.auth.uid;

      await hospitalRef.update(updates);

      await db.collection('admin_audit_log').doc().set({
        action: 'UPDATE_HOSPITAL',
        performed_by: context.auth.uid,
        target_id: hospitalId,
        changes: JSON.stringify(updates),
        timestamp: admin.firestore.Timestamp.now(),
      });

      return { success: true, action: 'updated', hospitalId, updates };
    }

    // ── TOGGLE VERIFIED ────────────────────────────────────────────────────
    if (action === 'toggleVerified') {
      const current = hospitalSnap.data().verified;
      await hospitalRef.update({
        verified: !current,
        updated_at: admin.firestore.Timestamp.now(),
        updated_by: context.auth.uid,
      });

      await db.collection('admin_audit_log').doc().set({
        action: current ? 'UNVERIFY_HOSPITAL' : 'VERIFY_HOSPITAL',
        performed_by: context.auth.uid,
        target_id: hospitalId,
        target_name: hospitalSnap.data().name,
        timestamp: admin.firestore.Timestamp.now(),
      });

      return { success: true, action: 'toggleVerified', hospitalId, verified: !current };
    }

    // ── DELETE ────────────────────────────────────────────────────────────
    if (action === 'delete') {
      const name = hospitalSnap.data().name;
      await hospitalRef.delete();

      await db.collection('admin_audit_log').doc().set({
        action: 'DELETE_HOSPITAL',
        performed_by: context.auth.uid,
        target_id: hospitalId,
        target_name: name,
        timestamp: admin.firestore.Timestamp.now(),
      });

      return { success: true, action: 'deleted', hospitalId };
    }
  });
