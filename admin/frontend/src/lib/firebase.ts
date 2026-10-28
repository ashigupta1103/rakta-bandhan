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
  apiKey: "AIzaSyA26RwQWBPJpSMOejUM9TRoHwZgHmc0sto",
  authDomain: "rakta-bandhan-india.firebaseapp.com",
  projectId: "rakta-bandhan-india",
  storageBucket: "rakta-bandhan-india.firebasestorage.app",
  messagingSenderId: "469374681836",
  appId: "1:469374681836:web:71d7edb17ba9c1de355bc9",
  measurementId: "G-WDEZZBY3QD",
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
