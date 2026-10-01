import { afterEach, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';

import worker from '../build/index.js';
import { resetKeyCache } from '../build/auth.js';
import { parseIceServers, STUN_ONLY } from '../build/ice.js';
import { parseMediaPath, sniffImage } from '../build/media.js';
import {
  FakeR2,
  JPEG,
  PNG,
  PROJECT,
  WEBP,
  emulatorToken,
  firestoreRoute,
  jwksRoute,
  makeSigner,
  routeFetch,
} from './helpers.mjs';

const BASE = 'https://edge.test';
let signer;
let r2;
let net;

const env = (extra = {}) => ({
  MEDIA: r2,
  FIREBASE_PROJECT_ID: PROJECT,
  ALLOWED_ORIGINS: 'https://admin.example, https://app.example',
  ...extra,
});
const call = (path, init = {}, e = env()) => worker.fetch(new Request(BASE + path, init), e);
const bearer = async (claims) => ({ authorization: `Bearer ${await signer.token(claims)}` });
const put = async (path, bytes, { type = 'image/jpeg', claims, extra = {} } = {}) =>
  call(path, { method: 'PUT', headers: { ...(await bearer(claims)), 'content-type': type, ...extra }, body: bytes });

const fs = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, { stringValue: v }]));

beforeEach(async () => {
  signer ??= await makeSigner();
  r2 = new FakeR2();
  resetKeyCache();
  net = routeFetch([jwksRoute(signer.jwks), firestoreRoute({})]);
});

afterEach(() => net.restore());

describe('routes', () => {
  test('health answers without a sign-in', async () => {
    const res = await call('/health');
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { ok: true });
  });

  test('unknown paths and malformed media paths are 404', async () => {
    assert.equal((await call('/nope')).status, 404);
    assert.equal((await call('/media/secrets/u1/a.jpg')).status, 404);
    assert.equal((await call('/media/community/u1/..%2Fx.jpg')).status, 404);
    assert.equal((await call('/media/community/u1/photo.gif')).status, 404);
  });

  test('parseMediaPath and sniffImage', () => {
    assert.deepEqual(parseMediaPath('/media/avatars/u1/abcd1234.webp'), { kind: 'avatars', uid: 'u1', name: 'abcd1234.webp' });
    assert.equal(parseMediaPath('/media/community/u1'), null);
    assert.equal(sniffImage(JPEG), 'image/jpeg');
    assert.equal(sniffImage(PNG), 'image/png');
    assert.equal(sniffImage(WEBP), 'image/webp');
    assert.equal(sniffImage(new TextEncoder().encode('<html></html>')), null);
  });
});

describe('sign-in tokens', () => {
  const path = '/media/community/u1/post_abc123.jpg';

  test('no token is refused', async () => {
    const res = await call(path, { method: 'PUT', headers: { 'content-type': 'image/jpeg' }, body: JPEG });
    assert.equal(res.status, 401);
  });

  test('a tampered signature, expired token, wrong project or unknown key is refused', async () => {
    const good = await signer.token();
    const [h, p, s] = good.split('.');
    const forged = `${h}.${Buffer.from(JSON.stringify({ ...JSON.parse(Buffer.from(p, 'base64url')), sub: 'u2' })).toString('base64url')}.${s}`;
    const now = Math.floor(Date.now() / 1000);
    const bad = [
      forged,
      await signer.token({ exp: now - 5 }),
      await signer.token({ aud: 'some-other-project' }),
      await signer.token({ iss: 'https://securetoken.google.com/some-other-project' }),
      await signer.token({}, { kid: 'unknown-kid' }),
      await signer.token({}, { alg: 'HS256' }),
    ];
    for (const token of bad) {
      const res = await call(path, { method: 'PUT', headers: { authorization: `Bearer ${token}`, 'content-type': 'image/jpeg' }, body: JPEG });
      assert.equal(res.status, 401, token.slice(0, 20));
    }
  });

  test('the Auth emulator\'s unsigned tokens work only when the emulator switch is on', async () => {
    const init = { method: 'PUT', headers: { authorization: `Bearer ${emulatorToken()}`, 'content-type': 'image/jpeg' }, body: JPEG };
    assert.equal((await call(path, init)).status, 401);
    assert.equal((await call(path, init, env({ AUTH_EMULATOR: 'true' }))).status, 201);
  });
});

describe('uploading photos', () => {
  const path = '/media/community/u1/post_abc123.jpg';

  test('a verified member can upload to their own folder', async () => {
    const res = await put(path, JPEG);
    assert.equal(res.status, 201);
    assert.deepEqual(await res.json(), { path: 'community/u1/post_abc123.jpg', url: `${BASE}/media/community/u1/post_abc123.jpg` });
    const stored = r2.objects.get('community/u1/post_abc123.jpg');
    assert.equal(stored.httpMetadata.contentType, 'image/jpeg');
    assert.match(stored.httpMetadata.cacheControl, /immutable/);
    assert.equal(stored.customMetadata.uploader, 'u1');
  });

  test('an account signed in with an emailed code counts as verified', async () => {
    const res = await put(path, JPEG, { claims: { email_verified: false, login: 'email_otp' } });
    assert.equal(res.status, 201);
  });

  test('someone else\'s folder, and unverified accounts, are refused', async () => {
    assert.equal((await put('/media/community/u2/post_abc123.jpg', JPEG)).status, 403);
    assert.equal((await put(path, JPEG, { claims: { email_verified: false } })).status, 403);
    assert.equal(r2.keys().length, 0);
  });

  test('the bytes must really be the declared image type', async () => {
    assert.equal((await put(path, new TextEncoder().encode('<html>not a photo</html>'))).status, 415);
    assert.equal((await put(path, PNG)).status, 415); // PNG bytes, .jpg name and jpeg header
    assert.equal((await put(path, JPEG, { type: 'application/pdf' })).status, 415);
    assert.equal((await put('/media/community/u1/post_abc123.png', JPEG, { type: 'image/png' })).status, 415);
    assert.equal((await put('/media/community/u1/post_abc123.png', PNG, { type: 'image/png' })).status, 201);
    assert.equal((await put('/media/community/u1/post_abc124.webp', WEBP, { type: 'image/webp' })).status, 201);
  });

  test('photos over 2 MB are refused, declared or not', async () => {
    const big = new Uint8Array(2 * 1024 * 1024 + 1);
    big.set(JPEG);
    assert.equal((await put(path, big, { extra: { 'content-length': String(big.length) } })).status, 413);
    assert.equal((await put(path, big)).status, 413);
    const ok = new Uint8Array(2 * 1024 * 1024);
    ok.set(JPEG);
    assert.equal((await put(path, ok)).status, 201);
  });

  test('a new avatar or ID photo replaces the old one; community photos accumulate', async () => {
    assert.equal((await put('/media/avatars/u1/first_aaaa.jpg', JPEG)).status, 201);
    assert.equal((await put('/media/avatars/u1/second_bbb.jpg', JPEG)).status, 201);
    assert.equal((await put('/media/avatars/u2/other_cccc.jpg', JPEG, { claims: { sub: 'u2' } })).status, 201);
    assert.equal((await put('/media/community/u1/post_one11.jpg', JPEG)).status, 201);
    assert.equal((await put('/media/community/u1/post_two22.jpg', JPEG)).status, 201);
    assert.deepEqual(r2.keys(), [
      'avatars/u1/second_bbb.jpg',
      'avatars/u2/other_cccc.jpg',
      'community/u1/post_one11.jpg',
      'community/u1/post_two22.jpg',
    ]);
  });
});

describe('downloading photos', () => {
  test('community and avatar photos are readable by link, cacheable, from any site', async () => {
    await put('/media/community/u1/post_abc123.jpg', JPEG);
    const res = await call('/media/community/u1/post_abc123.jpg');
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('content-type'), 'image/jpeg');
    assert.match(res.headers.get('cache-control'), /public.*immutable/);
    assert.equal(res.headers.get('access-control-allow-origin'), '*');
    assert.deepEqual(new Uint8Array(await res.arrayBuffer()), JPEG);
    assert.equal((await call('/media/community/u1/missing_aaa.jpg')).status, 404);
  });

  test('an ID photo is for its owner or an admin only, and is never cached', async () => {
    await put('/media/id_proofs/u1/proof.jpg', JPEG);
    assert.equal((await call('/media/id_proofs/u1/proof.jpg')).status, 401);

    const owner = await call('/media/id_proofs/u1/proof.jpg', { headers: await bearer() });
    assert.equal(owner.status, 200);
    assert.equal(owner.headers.get('cache-control'), 'private, no-store');

    const strangerToken = await signer.token({ sub: 'stranger' });
    net.restore();
    net = routeFetch([jwksRoute(signer.jwks), firestoreRoute({}, { expectToken: strangerToken })]);
    const stranger = await call('/media/id_proofs/u1/proof.jpg', { headers: { authorization: `Bearer ${strangerToken}` } });
    assert.equal(stranger.status, 403);

    const adminToken = await signer.token({ sub: 'boss' });
    net.restore();
    net = routeFetch([jwksRoute(signer.jwks), firestoreRoute({ 'admins/boss': fs({ role: 'admin' }) }, { expectToken: adminToken })]);
    const admin = await call('/media/id_proofs/u1/proof.jpg', { headers: { authorization: `Bearer ${adminToken}` } });
    assert.equal(admin.status, 200);
    // The caller's own token, not a Worker secret, is what Firestore saw.
    assert.ok(net.calls.some((c) => c.init.headers?.Authorization === `Bearer ${adminToken}`));
  });
});

describe('removing photos', () => {
  test('the owner can remove their own; a stranger cannot', async () => {
    await put('/media/community/u1/post_abc123.jpg', JPEG);
    const stranger = await call('/media/community/u1/post_abc123.jpg', {
      method: 'DELETE',
      headers: await bearer({ sub: 'stranger' }),
    });
    assert.equal(stranger.status, 403);
    const owner = await call('/media/community/u1/post_abc123.jpg', { method: 'DELETE', headers: await bearer() });
    assert.equal(owner.status, 204);
    assert.equal(r2.keys().length, 0);
  });

  test('an admin can remove a community photo or an ID photo, but not a private avatar', async () => {
    await put('/media/community/u1/post_abc123.jpg', JPEG);
    await put('/media/avatars/u1/avatar_aaaa.jpg', JPEG);
    net.restore();
    net = routeFetch([jwksRoute(signer.jwks), firestoreRoute({ 'admins/boss': fs({ role: 'admin' }) })]);
    const asBoss = { headers: await bearer({ sub: 'boss' }), method: 'DELETE' };
    assert.equal((await call('/media/avatars/u1/avatar_aaaa.jpg', asBoss)).status, 403);
    assert.equal((await call('/media/community/u1/post_abc123.jpg', asBoss)).status, 204);
    assert.deepEqual(r2.keys(), ['avatars/u1/avatar_aaaa.jpg']);
  });
});

describe('call relay credentials', () => {
  const ask = async (body, { claims, e = env(), method = 'POST' } = {}) =>
    call('/ice', { method, headers: { ...(await bearer(claims)), 'content-type': 'application/json' }, body: method === 'POST' ? JSON.stringify(body) : undefined }, e);
  const matched = { 'requests/r1': fs({ status: 'matched', requester_uid: 'u1', matched_donor_id: 'u2' }) };
  const withRequests = (docs) => {
    net.restore();
    net = routeFetch([jwksRoute(signer.jwks), firestoreRoute(docs), ['https://rtc.live.cloudflare.com/', () => Response.json(cloudflare, { status: 201 })]]);
  };
  const cloudflare = {
    iceServers: [
      { urls: ['stun:stun.cloudflare.com:3478'] },
      { urls: ['turn:turn.cloudflare.com:3478?transport=udp', 'turns:turn.cloudflare.com:443?transport=tcp'], username: 'user', credential: 'secret' },
    ],
  };

  test('a participant gets STUN only when no relay is configured', async () => {
    withRequests(matched);
    const res = await ask({ requestId: 'r1' });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { iceServers: STUN_ONLY, ttlS: 3600 });
  });

  test('both participants get relay credentials from Cloudflare when it is configured', async () => {
    withRequests(matched);
    const e = env({ TURN_KEY_ID: 'key-1', TURN_API_TOKEN: 'tok-1' });
    for (const sub of ['u1', 'u2']) {
      const res = await ask({ requestId: 'r1' }, { claims: { sub }, e });
      assert.equal(res.status, 200);
      assert.deepEqual((await res.json()).iceServers, cloudflare.iceServers);
    }
    const cf = net.calls.find((c) => c.url.startsWith('https://rtc.live.cloudflare.com/'));
    assert.equal(cf.url, 'https://rtc.live.cloudflare.com/v1/turn/keys/key-1/credentials/generate-ice-servers');
    assert.equal(cf.init.headers.Authorization, 'Bearer tok-1');
    assert.equal(JSON.parse(cf.init.body).ttl, 3600);
  });

  test('a failing provider falls back to STUN so calls still work', async () => {
    net.restore();
    net = routeFetch([jwksRoute(signer.jwks), firestoreRoute(matched), ['https://rtc.live.cloudflare.com/', () => new Response('nope', { status: 500 })]]);
    const res = await ask({ requestId: 'r1' }, { e: env({ TURN_KEY_ID: 'k', TURN_API_TOKEN: 't' }) });
    assert.deepEqual((await res.json()).iceServers, STUN_ONLY);
  });

  test('strangers, unmatched requests and bad input are refused', async () => {
    withRequests({ ...matched, 'requests/r2': fs({ status: 'open', requester_uid: 'u1' }), 'requests/r3': 'forbidden' });
    assert.equal((await ask({ requestId: 'r1' }, { claims: { sub: 'stranger' } })).status, 403);
    assert.equal((await ask({ requestId: 'r2' })).status, 403);
    assert.equal((await ask({ requestId: 'r3' })).status, 403);
    assert.equal((await ask({ requestId: 'missing' })).status, 403);
    assert.equal((await ask({})).status, 400);
    assert.equal((await ask({ requestId: '../admins/x' })).status, 400);
    assert.equal((await ask(null, { method: 'GET' })).status, 405);
  });

  test('parseIceServers keeps only well-formed servers and needs a relay entry', () => {
    assert.deepEqual(parseIceServers(cloudflare), cloudflare.iceServers);
    assert.equal(parseIceServers(null), null);
    assert.equal(parseIceServers({ iceServers: 'x' }), null);
    assert.equal(parseIceServers({ iceServers: [{ urls: ['stun:a:1'] }] }), null);
    assert.equal(parseIceServers({ iceServers: [{ urls: ['http://evil'], username: 'u', credential: 'c' }] }), null);
    assert.deepEqual(
      parseIceServers({ iceServers: [{ urls: ['turn:t:3478', 'javascript:alert(1)'], username: 'u', credential: 'c', extra: 1 }] }),
      [{ urls: ['turn:t:3478'], username: 'u', credential: 'c' }],
    );
  });
});

describe('browser access (CORS)', () => {
  test('allowed origins may call private routes; others get no CORS headers', async () => {
    const pre = (origin) =>
      call('/ice', { method: 'OPTIONS', headers: { origin, 'access-control-request-method': 'POST' } });
    const ok = await pre('https://admin.example');
    assert.equal(ok.status, 204);
    assert.equal(ok.headers.get('access-control-allow-origin'), 'https://admin.example');
    assert.match(ok.headers.get('access-control-allow-headers'), /authorization/);
    const other = await pre('https://evil.example');
    assert.equal(other.status, 204);
    assert.equal(other.headers.get('access-control-allow-origin'), null);
  });

  test('errors carry the CORS header too, so the browser can read them', async () => {
    const res = await call('/ice', { method: 'POST', headers: { origin: 'https://app.example' }, body: '{}' });
    assert.equal(res.status, 401);
    assert.equal(res.headers.get('access-control-allow-origin'), 'https://app.example');
  });
});
