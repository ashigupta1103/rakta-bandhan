const admin = require('firebase-admin');

// Replace this with your actual admin email and uid from Firebase Auth
const ADMIN_EMAIL = 'admin@raktabandhan.com';
const ADMIN_UID = 'REPLACE_WITH_YOUR_FIREBASE_AUTH_UID';

// Initialize Firebase Admin (make sure to set GOOGLE_APPLICATION_CREDENTIALS 
// or run this via firebase functions:shell if in a deployed environment,
// but for local execution with Firebase CLI logged in, the default app often works 
// if you supply a service account, OR you can just use setAdminRole Cloud Function directly from a client once.)
// Alternatively, if you just want to run this locally:
// 1. Generate a new private key from Firebase Console -> Project Settings -> Service Accounts
// 2. Save it as serviceAccountKey.json
// 3. Uncomment the lines below:

/*
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function makeAdmin() {
  try {
    await admin.auth().setCustomUserClaims(ADMIN_UID, { admin: true });
    console.log(`Successfully granted admin privileges to user: ${ADMIN_UID}`);
    process.exit(0);
  } catch (error) {
    console.error('Error granting admin privileges:', error);
    process.exit(1);
  }
}

makeAdmin();
*/

console.log('To run this script, download your serviceAccountKey.json and uncomment the code in bootstrap-admin.js');
