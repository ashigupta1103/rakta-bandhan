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

// Same project/web app the Flutter build's firebase_options.dart uses
// (DefaultFirebaseOptions.web) — one Firebase project, two clients.
const firebaseConfig = {
  apiKey: "AIzaSyC-Maq9_JwK9gEaKAyC1-CDc995LlA2cPY",
  authDomain: "project-673480bf-b9b8-4e5b-8a1.firebaseapp.com",
  projectId: "project-673480bf-b9b8-4e5b-8a1",
  storageBucket: "project-673480bf-b9b8-4e5b-8a1.firebasestorage.app",
  messagingSenderId: "323116488555",
  appId: "1:323116488555:web:04ea5be4983471efb15e2e",
  measurementId: "G-J8TLQ4KG5K",
};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);

export default app;
