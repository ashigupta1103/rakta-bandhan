// One Admin SDK app shared by every function module. Imported first, so
// any module can use `db`/`auth`/`messaging` at load time.
import { setGlobalOptions } from 'firebase-functions/v2';
import { HttpsError } from 'firebase-functions/v2/https';
import { defineBoolean } from 'firebase-functions/params';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

import { appCheckRefused } from './lifecycle';

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

/**
 * App Check enforcement for the callables. Off until the owner turns it on
 * (after a release build with Play Integrity passes), so it can't lock out
 * a build that isn't registered yet. See docs/launch/AFTER_BLAZE_UPGRADE.md.
 */
export const ENFORCE_APP_CHECK = defineBoolean('ENFORCE_APP_CHECK', { default: false });

/** First line of a callable: refuses a request that didn't come from the real app, once enforcement is on. */
export function requireAppCheck(req: { app?: unknown }): void {
  if (appCheckRefused(ENFORCE_APP_CHECK.value(), isEmulator, req.app != null)) {
    throw new HttpsError('failed-precondition', 'This version of the app can’t be verified. Update the app and try again.');
  }
}
