// Firebase ID-token verification, with no SDK and no service account: the
// signature is checked against Google's published signing keys, and the
// claims against this project. The Worker never holds a secret that could
// impersonate a user; to ask "may this person do that?" it forwards the
// caller's own token to Firestore (see firestore.ts) and lets the security
// rules answer.

import { Env, HttpError } from './types.js';

export interface Caller {
  uid: string;
  /** The raw ID token, forwarded to Firestore so the rules decide. */
  token: string;
  claims: Record<string, unknown>;
  /** Signed in with an emailed code, or a verified email. Only demanded once the owner requires email proof (see media.ts). */
  verified: boolean;
}

const JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
/** Don't refetch the key set more than once a minute, whatever the token says. */
const MIN_REFETCH_MS = 60_000;

let keys: { byKid: Map<string, CryptoKey>; expires: number; fetchedAt: number } | null = null;

/** Forget cached signing keys (tests). */
export function resetKeyCache(): void {
  keys = null;
}

function b64urlToBytes(s: string): Uint8Array {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4);
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function parseJson(bytes: Uint8Array): Record<string, unknown> {
  try {
    const v: unknown = JSON.parse(new TextDecoder().decode(bytes));
    if (v && typeof v === 'object' && !Array.isArray(v)) return v as Record<string, unknown>;
  } catch {
    // falls through
  }
  throw new HttpError(401, 'Invalid sign-in token.');
}

async function loadKeys(now: number): Promise<void> {
  const res = await fetch(JWKS_URL);
  if (!res.ok) throw new HttpError(503, 'Could not check your sign-in. Try again.');
  const body = (await res.json()) as { keys?: Array<JsonWebKey & { kid?: string }> };
  const byKid = new Map<string, CryptoKey>();
  for (const jwk of body.keys ?? []) {
    if (!jwk.kid) continue;
    byKid.set(
      jwk.kid,
      await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']),
    );
  }
  const maxAge = Number(/max-age=(\d+)/.exec(res.headers.get('cache-control') ?? '')?.[1] ?? 3600);
  keys = { byKid, fetchedAt: now, expires: now + Math.max(maxAge, 60) * 1000 };
}

async function signingKey(kid: string, now: number): Promise<CryptoKey> {
  if (!keys || keys.expires <= now) await loadKeys(now);
  let key = keys?.byKid.get(kid);
  // An unknown kid may just mean Google rotated keys since we cached them.
  if (!key && keys && now - keys.fetchedAt >= MIN_REFETCH_MS) {
    await loadKeys(now);
    key = keys?.byKid.get(kid);
  }
  if (!key) throw new HttpError(401, 'Invalid sign-in token.');
  return key;
}

/** Verifies a Firebase ID token for this project and returns who sent it. */
export async function verifyIdToken(token: string, env: Env, now = Date.now()): Promise<Caller> {
  const parts = token.split('.');
  if (parts.length !== 3) throw new HttpError(401, 'Invalid sign-in token.');
  const [h, p, s] = parts;
  const header = parseJson(b64urlToBytes(h));
  const claims = parseJson(b64urlToBytes(p));

  if (env.AUTH_EMULATOR === 'true' && header.alg === 'none') {
    // The Auth emulator signs nothing. Only ever enabled for local development.
  } else {
    if (header.alg !== 'RS256' || typeof header.kid !== 'string') throw new HttpError(401, 'Invalid sign-in token.');
    const key = await signingKey(header.kid, now);
    const ok = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      key,
      b64urlToBytes(s),
      new TextEncoder().encode(`${h}.${p}`),
    );
    if (!ok) throw new HttpError(401, 'Invalid sign-in token.');
  }

  const nowS = Math.floor(now / 1000);
  if (claims.aud !== env.FIREBASE_PROJECT_ID || claims.iss !== `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`) {
    throw new HttpError(401, 'Invalid sign-in token.');
  }
  if (typeof claims.exp !== 'number' || claims.exp <= nowS) throw new HttpError(401, 'Your sign-in has expired. Sign in again.');
  if (typeof claims.iat === 'number' && claims.iat > nowS + 300) throw new HttpError(401, 'Invalid sign-in token.');
  const uid = claims.sub;
  if (typeof uid !== 'string' || uid.length === 0 || uid.length > 128) throw new HttpError(401, 'Invalid sign-in token.');

  return {
    uid,
    token,
    claims,
    verified: claims.login === 'email_otp' || claims.email_verified === true,
  };
}

/** The caller behind `Authorization: Bearer <id token>`, or a 401. */
export async function requireCaller(request: Request, env: Env): Promise<Caller> {
  const m = /^Bearer (.+)$/.exec(request.headers.get('authorization') ?? '');
  if (!m) throw new HttpError(401, 'Sign in first.');
  return verifyIdToken(m[1], env);
}
