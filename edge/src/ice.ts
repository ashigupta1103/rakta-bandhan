// Relay (TURN) credentials for in-app calls.
//
//   POST /ice  { "requestId": "..." }  →  { iceServers: [...], ttlS }
//
// STUN alone connects most calls; mobile-carrier NAT pairs (common in India)
// need a relay. Credentials are short-lived and handed only to the two people
// on a matched request: the Worker reads the request as the caller (see
// firestore.ts), so the rules say who is a participant. Provider: Cloudflare
// Realtime TURN (1,000 GB a month free). With the secrets unset, or if
// Cloudflare is unreachable, callers get STUN only and calls still work for
// the pairs that don't need a relay. To change provider, replace
// `relayServers` — nothing else knows who it is.

import { requireCaller } from './auth.js';
import { Fields, getDocument, text } from './firestore.js';
import { Env, HttpError } from './types.js';

export interface IceServer {
  urls: string | string[];
  username?: string;
  credential?: string;
}

/** Credential lifetime. Calls last minutes; this only has to outlive one. */
export const ICE_TTL_S = 3600;

export const STUN_ONLY: IceServer[] = [{ urls: ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'] }];

/** Only the two people on a matched request may fetch relay credentials. */
export function canUseRelay(fields: Fields | undefined, uid: string): boolean {
  if (text(fields, 'status') !== 'matched') return false;
  return text(fields, 'requester_uid') === uid || text(fields, 'matched_donor_id') === uid;
}

const isUrl = (u: unknown): u is string => typeof u === 'string' && /^(stun|turns?):/.test(u);

/**
 * Keeps only well-formed servers from the provider's response
 * (Cloudflare: `{ iceServers: [{ urls, username?, credential? }] }`), so a
 * surprise payload can't reach the phones. Null when nothing usable came back
 * or there is no relay entry; the caller then serves [STUN_ONLY].
 */
export function parseIceServers(body: unknown): IceServer[] | null {
  const list = (body as { iceServers?: unknown } | null)?.iceServers;
  if (!Array.isArray(list)) return null;
  const out: IceServer[] = [];
  for (const entry of list) {
    const e = entry as { urls?: unknown; username?: unknown; credential?: unknown } | null;
    const urls = Array.isArray(e?.urls) ? e.urls.filter(isUrl) : isUrl(e?.urls) ? [e.urls] : [];
    if (urls.length === 0) continue;
    const hasCreds = typeof e?.username === 'string' && typeof e?.credential === 'string';
    out.push(hasCreds ? { urls, username: e.username as string, credential: e.credential as string } : { urls });
  }
  return out.some((s) => s.username) ? out : null;
}

/** Cloudflare Realtime TURN: https://developers.cloudflare.com/realtime/turn/generate-credentials/ */
async function relayServers(env: Env): Promise<IceServer[]> {
  if (!env.TURN_KEY_ID || !env.TURN_API_TOKEN) return STUN_ONLY;
  try {
    const res = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${encodeURIComponent(env.TURN_KEY_ID)}/credentials/generate-ice-servers`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${env.TURN_API_TOKEN}`, 'content-type': 'application/json' },
        body: JSON.stringify({ ttl: ICE_TTL_S }),
        signal: AbortSignal.timeout(5000),
      },
    );
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return parseIceServers(await res.json()) ?? STUN_ONLY;
  } catch (e) {
    console.warn('relay credentials unavailable, serving STUN only', String(e));
    return STUN_ONLY;
  }
}

// ponytail: no per-user rate limit — phones cache the answer for its lifetime;
// add one if abuse shows up.
export async function handleIce(request: Request, env: Env): Promise<Response> {
  if (request.method !== 'POST') throw new HttpError(405, 'Method not allowed.');
  const caller = await requireCaller(request, env);
  const body = (await request.json().catch(() => null)) as { requestId?: unknown } | null;
  if (typeof body?.requestId !== 'string') throw new HttpError(400, 'Missing request.');
  const doc = await getDocument(env, caller, 'requests', body.requestId);
  if (doc.status !== 200 || !canUseRelay(doc.fields, caller.uid)) {
    throw new HttpError(403, 'Calls are only for the two people on a matched request.');
  }
  return Response.json({ iceServers: await relayServers(env), ttlS: ICE_TTL_S });
}
