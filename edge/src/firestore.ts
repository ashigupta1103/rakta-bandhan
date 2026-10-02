// Reads a Firestore document *as the caller*, over REST, with their own ID
// token. The security rules decide whether they may see it, so the Worker
// needs no service account and can't be talked into reading more than the
// person asking could read themselves.

import type { Caller } from './auth.js';
import { Env, HttpError } from './types.js';

type FirestoreValue = { stringValue?: string; booleanValue?: boolean };
export type Fields = Record<string, FirestoreValue>;

export interface Doc {
  /** 200 when the caller may read it and it exists; 404 or 403 otherwise. */
  status: 200 | 403 | 404;
  fields?: Fields;
}

const ID = /^[A-Za-z0-9_-]{1,128}$/;

export async function getDocument(env: Env, caller: Caller, collection: string, id: string): Promise<Doc> {
  if (!ID.test(id)) throw new HttpError(400, 'Invalid id.');
  const base = env.FIRESTORE_EMULATOR_HOST ? `http://${env.FIRESTORE_EMULATOR_HOST}` : 'https://firestore.googleapis.com';
  const res = await fetch(`${base}/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${collection}/${id}`, {
    headers: { Authorization: `Bearer ${caller.token}` },
  });
  if (res.status === 404) return { status: 404 };
  if (res.status === 403) return { status: 403 };
  if (!res.ok) throw new HttpError(502, 'Could not check access. Try again.');
  const body = (await res.json()) as { fields?: Fields };
  return { status: 200, fields: body.fields ?? {} };
}

export const text = (fields: Fields | undefined, key: string): string | undefined => fields?.[key]?.stringValue;
export const flag = (fields: Fields | undefined, key: string): boolean | undefined => fields?.[key]?.booleanValue;

/**
 * Admin = a doc at admins/{uid}. The rules let anyone read their *own* admin
 * doc, so for a non-admin this is a 404, and for an admin a 200.
 */
export async function isAdmin(env: Env, caller: Caller): Promise<boolean> {
  return (await getDocument(env, caller, 'admins', caller.uid)).status === 200;
}
