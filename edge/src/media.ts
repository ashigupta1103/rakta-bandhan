// Photos on R2, behind the Worker.
//
//   PUT    /media/{kind}/{uid}/{name}   upload (owner, signed in with a verified account)
//   GET    /media/{kind}/{uid}/{name}   download
//   DELETE /media/{kind}/{uid}/{name}   remove (owner; an admin for community and id_proofs)
//
// kind = community  post photos: any signed-in user can see them, and the link is
//                   unguessable, like a Firebase Storage download link was.
//        avatars    the private profile photo. Each upload gets a fresh random
//                   name and replaces the old one; the link lives only on the
//                   owner's private profile doc.
//        id_proofs  the ID photo for verification: only its owner or an admin
//                   can fetch it, every time, with their sign-in.

import { Caller, requireCaller } from './auth.js';
import { isAdmin } from './firestore.js';
import { Env, HttpError } from './types.js';

export const MAX_BYTES = 2 * 1024 * 1024;

const KINDS = ['community', 'avatars', 'id_proofs'] as const;
type Kind = (typeof KINDS)[number];

const isPublic = (kind: Kind) => kind !== 'id_proofs';
/** A new upload replaces whatever the owner had before. */
const replaces = (kind: Kind) => kind !== 'community';

const NAME = /^[A-Za-z0-9_-]{4,80}\.(jpg|png|webp)$/;
const UID = /^[A-Za-z0-9_-]{1,128}$/;
const EXT_TYPE: Record<string, string> = { jpg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };

export interface MediaPath {
  kind: Kind;
  uid: string;
  name: string;
}

/** `/media/community/u1/abc.jpg` → its parts, or null when it isn't a media path. */
export function parseMediaPath(pathname: string): MediaPath | null {
  const m = /^\/media\/([a-z_]+)\/([^/]+)\/([^/]+)$/.exec(pathname);
  if (!m) return null;
  const [, kind, uid, name] = m;
  if (!(KINDS as readonly string[]).includes(kind) || !UID.test(uid) || !NAME.test(name)) return null;
  return { kind: kind as Kind, uid, name };
}

const ascii = (b: Uint8Array, from: number, to: number) => String.fromCharCode(...b.slice(from, to));

/** What the bytes really are, whatever the caller claims. */
export function sniffImage(b: Uint8Array): string | null {
  if (b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return 'image/jpeg';
  if (b.length >= 8 && ascii(b, 1, 4) === 'PNG' && b[0] === 0x89 && b[4] === 0x0d && b[5] === 0x0a && b[6] === 0x1a && b[7] === 0x0a) {
    return 'image/png';
  }
  if (b.length >= 12 && ascii(b, 0, 4) === 'RIFF' && ascii(b, 8, 12) === 'WEBP') return 'image/webp';
  return null;
}

/** Reads the body, refusing anything over `max` without buffering it all. */
export async function readLimited(request: Request, max: number): Promise<Uint8Array> {
  const declared = Number(request.headers.get('content-length') ?? NaN);
  if (Number.isFinite(declared) && declared > max) throw new HttpError(413, 'That photo is too large (2 MB at most).');
  const reader = request.body?.getReader();
  if (!reader) throw new HttpError(400, 'Send the photo as the request body.');
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > max) {
      await reader.cancel();
      throw new HttpError(413, 'That photo is too large (2 MB at most).');
    }
    chunks.push(value);
  }
  const out = new Uint8Array(total);
  let at = 0;
  for (const c of chunks) {
    out.set(c, at);
    at += c.byteLength;
  }
  return out;
}

const keyOf = (p: MediaPath) => `${p.kind}/${p.uid}/${p.name}`;

function publicBase(request: Request, env: Env): string {
  return (env.PUBLIC_BASE_URL ?? new URL(request.url).origin).replace(/\/$/, '');
}

async function upload(request: Request, env: Env, p: MediaPath): Promise<Response> {
  const caller = await requireCaller(request, env);
  if (caller.uid !== p.uid) throw new HttpError(403, 'You can only upload to your own folder.');
  if (!caller.verified) throw new HttpError(403, 'Confirm your email first.');

  const bytes = await readLimited(request, MAX_BYTES);
  const real = sniffImage(bytes);
  const declared = (request.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase();
  const wanted = EXT_TYPE[p.name.split('.').pop() as string];
  if (!real || real !== declared || real !== wanted) throw new HttpError(415, 'Only JPEG, PNG or WebP photos are accepted.');

  await env.MEDIA.put(keyOf(p), bytes, {
    httpMetadata: {
      contentType: real,
      cacheControl: isPublic(p.kind) ? 'public, max-age=31536000, immutable' : 'private, no-store',
    },
    customMetadata: { uploader: caller.uid },
  });

  if (replaces(p.kind)) {
    const prefix = `${p.kind}/${p.uid}/`;
    const old = (await env.MEDIA.list({ prefix })).objects.map((o) => o.key).filter((k) => k !== keyOf(p));
    if (old.length > 0) await env.MEDIA.delete(old);
  }

  const path = keyOf(p);
  return Response.json({ path, url: `${publicBase(request, env)}/media/${path}` }, { status: 201 });
}

async function download(request: Request, env: Env, p: MediaPath): Promise<Response> {
  if (!isPublic(p.kind)) {
    const caller = await requireCaller(request, env);
    if (caller.uid !== p.uid && !(await isAdmin(env, caller))) throw new HttpError(403, 'Not allowed.');
  }
  const object = await env.MEDIA.get(keyOf(p));
  if (!object) throw new HttpError(404, 'Not found.');
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);
  headers.set('x-content-type-options', 'nosniff');
  return new Response(object.body, { headers });
}

async function remove(request: Request, env: Env, p: MediaPath): Promise<Response> {
  const caller: Caller = await requireCaller(request, env);
  if (caller.uid !== p.uid && !(p.kind !== 'avatars' && (await isAdmin(env, caller)))) {
    throw new HttpError(403, 'Not allowed.');
  }
  await env.MEDIA.delete(keyOf(p));
  return new Response(null, { status: 204 });
}

export async function handleMedia(request: Request, env: Env, p: MediaPath): Promise<Response> {
  switch (request.method) {
    case 'PUT':
      return upload(request, env, p);
    case 'GET':
    case 'HEAD':
      return download(request, env, p);
    case 'DELETE':
      return remove(request, env, p);
    default:
      throw new HttpError(405, 'Method not allowed.');
  }
}

export { isPublic };
