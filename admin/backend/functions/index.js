/**
 * Rakta Bandhan — Admin Cloud Functions Entry Point
 *
 * Separate codebase from app/backend/functions (see firebase.json's
 * `functions` array — two codebases, one Firebase project). Split out so
 * admin's backend is organizationally independent of the app's, even
 * though both share the same Firestore database underneath.
 *
 * Dormant on the current Spark (free) plan — these need Blaze to deploy.
 * The live admin panel (admin/frontend) talks to Firestore directly
 * instead; see admin/backend/ADMIN_BACKEND_ARCHITECTURE.md.
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const { adminGetDashboardStats } = require('./src/functions/adminGetDashboardStats');
exports.adminGetDashboardStats = adminGetDashboardStats;

const { adminVerifyDonor } = require('./src/functions/adminVerifyDonor');
exports.adminVerifyDonor = adminVerifyDonor;

const { adminToggleDonorAvailability } = require('./src/functions/adminToggleDonorAvailability');
exports.adminToggleDonorAvailability = adminToggleDonorAvailability;

const { adminBanUser } = require('./src/functions/adminBanUser');
exports.adminBanUser = adminBanUser;

const { adminManageHospital } = require('./src/functions/adminManageHospital');
exports.adminManageHospital = adminManageHospital;

const { adminGetAnalytics } = require('./src/functions/adminGetAnalytics');
exports.adminGetAnalytics = adminGetAnalytics;

const { adminBroadcastNotification } = require('./src/functions/adminBroadcastNotification');
exports.adminBroadcastNotification = adminBroadcastNotification;

const { adminGetAuditLog } = require('./src/functions/adminGetAuditLog');
exports.adminGetAuditLog = adminGetAuditLog;

const { onDonationConfirmed } = require('./src/functions/onDonationConfirmed');
exports.onDonationConfirmed = onDonationConfirmed;

const { setAdminRole } = require('./src/functions/setAdminRole');
exports.setAdminRole = setAdminRole;
