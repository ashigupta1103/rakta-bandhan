// One Admin SDK app shared by every function module. Imported first, so
// any module can use `db`/`auth`/`messaging` at load time.
import { setGlobalOptions } from 'firebase-functions/v2';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

/**
 * Must match the Firestore database's location (Firebase console →
 * Firestore → the location shown at the top). Firestore triggers deploy
 * only to that region; a mismatch fails the deploy with a clear error.
 * The app calls the sign-in functions in this region too
 * (kFunctionsRegion in lib/services/backend.dart).
 */
export const REGION = 'asia-south1';

setGlobalOptions({ region: REGION, maxInstances: 10, memory: '256MiB', timeoutSeconds: 60 });

initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export const messaging = getMessaging();

/** True when running on the local Firebase emulator. */
export const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
