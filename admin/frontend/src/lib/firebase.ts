/**
 * Firebase SDK initialization for the Admin Dashboard.
 *
 * No Cloud Functions client here — this project runs on the Spark (free)
 * plan, so all admin actions go straight to Firestore (see
 * hooks/useFirebaseData.ts), gated by firestore.rules' isAdmin() check.
 */

import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { initializeAppCheck, ReCaptchaV3Provider } from 'firebase/app-check';

// Same project/web app the Flutter build's firebase_options.dart uses
// (DefaultFirebaseOptions.web) — one Firebase project, two clients.
const firebaseConfig = {
  apiKey: "AIzaSyDX-ErtJ-YzGrsmA35-QVowcIGEcyIRPjs",
  authDomain: "rakta-bandhan2026.firebaseapp.com",
  projectId: "rakta-bandhan2026",
  storageBucket: "rakta-bandhan2026.firebasestorage.app",
  messagingSenderId: "686452527533",
  appId: "1:686452527533:web:96e80f3e108d8f3015d124",
  measurementId: "G-D7RXE48E0D",
};

const app = initializeApp(firebaseConfig);
const siteKey = import.meta.env.VITE_RECAPTCHA_SITE_KEY;
if (siteKey) {
  try { initializeAppCheck(app, { provider: new ReCaptchaV3Provider(siteKey), isTokenAutoRefreshEnabled: true }); }
  catch { console.warn('App Check activation unavailable; startup continues.'); }
}

export const auth = getAuth(app);
export const db = getFirestore(app);

export default app;
