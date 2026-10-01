// Test helpers: real RSA-signed Firebase-style ID tokens, an in-memory R2
// bucket, and a stubbed fetch for Google's key set, Firestore and Cloudflare.

export const PROJECT = 'demo-rakta-test';
export const JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/';
export const FIRESTORE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/`;

const b64url = (buf) => Buffer.from(buf).toString('base64url');
const enc = (o) => b64url(Buffer.from(JSON.stringify(o)));

export async function makeSigner() {
  const { publicKey, privateKey } = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  );
  const jwk = { ...(await crypto.subtle.exportKey('jwk', publicKey)), kid: 'test-kid', alg: 'RS256', use: 'sig' };
  return {
    jwks: { keys: [jwk] },
    /** An ID token for `sub` (default u1), verified-email by default. */
    async token(claims = {}, header = {}) {
      const now = Math.floor(Date.now() / 1000);
      const payload = {
        iss: `https://securetoken.google.com/${PROJECT}`,
        aud: PROJECT,
        sub: 'u1',
        iat: now - 10,
        auth_time: now - 10,
        exp: now + 3600,
        email_verified: true,
        ...claims,
      };
      const signingInput = `${enc({ alg: 'RS256', kid: 'test-kid', typ: 'JWT', ...header })}.${enc(payload)}`;
      const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', privateKey, Buffer.from(signingInput));
      return `${signingInput}.${b64url(sig)}`;
    },
  };
}

/** An unsigned token, as the Auth emulator issues. */
export function emulatorToken(claims = {}) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: `https://securetoken.google.com/${PROJECT}`,
    aud: PROJECT,
    sub: 'u1',
    iat: now - 10,
    exp: now + 3600,
    email_verified: true,
    ...claims,
  };
  return `${enc({ alg: 'none', typ: 'JWT' })}.${enc(payload)}.`;
}

export class FakeR2 {
  constructor() {
    this.objects = new Map();
  }
  async put(key, value, opts = {}) {
    this.objects.set(key, {
      bytes: new Uint8Array(value),
      httpMetadata: opts.httpMetadata ?? {},
      customMetadata: opts.customMetadata ?? {},
    });
  }
  async get(key) {
    const o = this.objects.get(key);
    if (!o) return null;
    return {
      body: new Blob([o.bytes]).stream(),
      httpEtag: `"etag-${key}"`,
      writeHttpMetadata(headers) {
        if (o.httpMetadata.contentType) headers.set('content-type', o.httpMetadata.contentType);
        if (o.httpMetadata.cacheControl) headers.set('cache-control', o.httpMetadata.cacheControl);
      },
    };
  }
  async delete(keys) {
    for (const k of Array.isArray(keys) ? keys : [keys]) this.objects.delete(k);
  }
  async list({ prefix = '' } = {}) {
    return { objects: [...this.objects.keys()].filter((k) => k.startsWith(prefix)).map((key) => ({ key })), truncated: false };
  }
  keys() {
    return [...this.objects.keys()].sort();
  }
}

/**
 * Replaces global fetch with a router: `routes` is [urlPrefix, (url, init) => Response].
 * Returns the recorded calls and a restore function.
 */
export function routeFetch(routes) {
  const original = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (input, init = {}) => {
    const url = typeof input === 'string' ? input : input.url;
    calls.push({ url, init });
    for (const [prefix, handler] of routes) if (url.startsWith(prefix)) return handler(url, init);
    throw new Error(`unexpected fetch ${url}`);
  };
  return { calls, restore: () => (globalThis.fetch = original) };
}

/** A Firestore REST stub. `docs` maps "collection/id" to a fields object; anything else is a 404. */
export function firestoreRoute(docs, { expectToken } = {}) {
  return [
    FIRESTORE_URL,
    (url, init) => {
      const key = decodeURIComponent(url.slice(FIRESTORE_URL.length));
      if (expectToken && init.headers?.Authorization !== `Bearer ${expectToken}`) return new Response('{}', { status: 403 });
      const fields = docs[key];
      if (fields === 'forbidden') return new Response('{}', { status: 403 });
      return fields ? Response.json({ fields }) : new Response('{}', { status: 404 });
    },
  ];
}

export const jwksRoute = (jwks) => [JWKS_URL, () => Response.json(jwks, { headers: { 'cache-control': 'public, max-age=3600' } })];

export const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1]);
export const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
export const WEBP = new Uint8Array([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]);
