// Rakta Bandhan — Cloud Functions.
//
// The app itself writes straight to Firestore under security rules; these
// functions only do what a phone can't:
//   - push notifications for chat, request updates and donation steps;
//   - ringing pushes for in-app calls (Android: native incoming-call UI via
//     a data message; iOS: a time-sensitive alert until PushKit is added);
//   - nearby-donor fan-out when a request is raised;
//   - admin broadcasts to FCM topics;
//   - expiring requests nobody accepted, and deleting a removed post's photo;
//   - passwordless sign-in codes (login.ts).
//
// Every function stays well inside the Blaze free tier (2M invocations a
// month) at the volumes in docs/publishing/cost-estimate.md.

import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';
import { DocumentData, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { Message } from 'firebase-admin/messaging';
import { getStorage } from 'firebase-admin/storage';

import { db, messaging } from './app';

import { BLOOD_COMPATIBILITY, bloodGroupTopic, cellsCovering, distanceKm } from './geo';
import { shortPlace } from './text';

export { REGION } from './app';


/** Small monochrome status-bar icon: android/app/src/main/res/drawable/ic_stat_notify.xml */
const ICON = 'ic_stat_notify';
const COLOR = '#B3261E';

/** Must match the channels created in MainActivity.kt. */
type Channel = 'messages' | 'requests' | 'urgent_alerts' | 'general';

interface Push {
  title: string;
  body: string;
  channel: Channel;
  /** Replaces an earlier notification with the same tag (one per chat/request). */
  tag?: string;
  data: Record<string, string>;
}

export function buildMessage(token: string, p: Push): Message {
  const urgent = p.channel === 'urgent_alerts';
  return {
    token,
    notification: { title: p.title, body: p.body },
    data: { ...p.data, title: p.title, body: p.body },
    android: {
      priority: 'high',
      notification: { channelId: p.channel, icon: ICON, color: COLOR, tag: p.tag },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          ...(p.tag ? { 'thread-id': p.tag } : {}),
          ...(urgent ? { 'interruption-level': 'time-sensitive' } : {}),
        },
      },
    },
  };
}

const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** A token FCM says is gone (app uninstalled / data cleared) is removed so we stop paying to try it. */
async function forgetToken(uid: string, token: string): Promise<void> {
  const ref = db.collection('donors').doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.get('fcm_token') === token) tx.update(ref, { fcm_token: FieldValue.delete() });
  });
}

async function tokenFor(uid: string | undefined | null): Promise<string | null> {
  if (!uid) return null;
  const snap = await db.collection('donors').doc(uid).get();
  const token = snap.get('fcm_token');
  return typeof token === 'string' && token.length > 0 ? token : null;
}

async function sendToUser(uid: string | undefined | null, p: Push): Promise<void> {
  const token = await tokenFor(uid);
  if (!token || !uid) return;
  try {
    await messaging.send(buildMessage(token, p));
  } catch (e) {
    const code = (e as { code?: string }).code ?? '';
    if (DEAD_TOKEN_CODES.has(code)) await forgetToken(uid, token);
    else logger.warn('push failed', { uid, code });
  }
}

/** Sends one notification to many devices, 500 per FCM call. */
async function sendToMany(targets: Array<{ uid: string; token: string }>, p: Push): Promise<number> {
  let sent = 0;
  for (let i = 0; i < targets.length; i += 500) {
    const chunk = targets.slice(i, i + 500);
    const res = await messaging.sendEach(chunk.map((t) => buildMessage(t.token, p)));
    sent += res.successCount;
    await Promise.all(
      res.responses.map((r, j) =>
        !r.success && DEAD_TOKEN_CODES.has(r.error?.code ?? '') ? forgetToken(chunk[j].uid, chunk[j].token) : null,
      ),
    );
  }
  return sent;
}

// ─────────────────────────────────────────────────────────────── Chat

export const onChatMessage = onDocumentCreated('requests/{requestId}/messages/{messageId}', async (event) => {
  const msg = event.data?.data();
  if (!msg) return;
  // Call-log rows are covered by the call pushes themselves.
  if (msg.kind !== 'text' && msg.kind !== 'location') return;
  const requestId = event.params.requestId;
  const req = (await db.collection('requests').doc(requestId).get()).data();
  if (!req) return;
  const sender = msg.sender_uid as string;
  const fromRequester = sender === req.requester_uid;
  const to = fromRequester ? req.matched_donor_id : req.requester_uid;
  if (!to || to === sender) return;
  const name = (fromRequester ? req.requester_name : req.matched_donor_name) || 'New message';
  const body = msg.kind === 'location' ? 'Shared a location' : String(msg.text ?? '').slice(0, 180);
  await sendToUser(to, {
    title: name,
    body,
    channel: 'messages',
    tag: `chat_${requestId}`,
    data: { type: 'chat', requestId },
  });
});

// ─────────────────────────────────────────────────────────────── Calls

/**
 * Rings the callee's phone even when the app is closed. Android gets a
 * data-only, high-priority message that the app turns into the native
 * incoming-call screen (flutter_callkit_incoming); iOS, which doesn't wake
 * a closed app for data messages, gets a time-sensitive alert instead.
 */
export const onCallCreated = onDocumentCreated('requests/{requestId}/calls/{callId}', async (event) => {
  const call = event.data?.data();
  if (!call || call.status !== 'ringing') return;
  const callee = call.callee_uid as string;
  const token = await tokenFor(callee);
  if (!token) return;
  const callerName = (call.caller_name as string) || 'Someone';
  const { requestId, callId } = event.params;
  try {
    await messaging.send({
      token,
      data: { type: 'call', requestId, callId, callerUid: String(call.caller_uid ?? ''), callerName },
      android: { priority: 'high', ttl: 45_000 },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
          'apns-expiration': String(Math.floor(Date.now() / 1000) + 45),
        },
        payload: {
          aps: {
            alert: { title: 'Incoming voice call', body: `${callerName} is calling you on Rakta Bandhan` },
            sound: 'default',
            'interruption-level': 'time-sensitive',
            'thread-id': `call_${callId}`,
          },
        },
      },
    });
  } catch (e) {
    const code = (e as { code?: string }).code ?? '';
    if (DEAD_TOKEN_CODES.has(code)) await forgetToken(callee, token);
    else logger.warn('call push failed', { code });
  }
});

/** Stops the ringing on the callee's phone once the call is answered, declined, cancelled or missed. */
export const onCallUpdated = onDocumentUpdated('requests/{requestId}/calls/{callId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status !== 'ringing' || after.status === 'ringing') return;
  const callee = after.callee_uid as string;
  const { requestId, callId } = event.params;
  const token = await tokenFor(callee);
  if (token) {
    await messaging
      .send({
        token,
        data: { type: 'call_ended', requestId, callId, status: String(after.status) },
        android: { priority: 'high', ttl: 60_000 },
      })
      .catch((e) => logger.warn('call_ended push failed', { code: (e as { code?: string }).code }));
  }
  if (after.status === 'missed') {
    const callerName = (after.caller_name as string) || 'Someone';
    await sendToUser(callee, {
      title: 'Missed call',
      body: `${callerName} tried to call you. Tap to message or call back.`,
      channel: 'messages',
      tag: `chat_${requestId}`,
      data: { type: 'chat', requestId },
    });
  }
});

// ──────────────────────────────────────────────────────────── Requests

/**
 * Tells compatible, available donors near a new request. Donors who opted
 * in to urgent alerts get the loud channel for urgent/critical requests;
 * everyone else a normal notification. Bounded: ≤ 60 donors per ~39×20 km
 * geohash cell, so a request costs at most a few hundred reads.
 */
export const onRequestCreated = onDocumentCreated('requests/{requestId}', async (event) => {
  const req = event.data?.data();
  if (!req || req.status !== 'open') return;
  const lat = Number(req.lat);
  const lng = Number(req.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
  const groups = BLOOD_COMPATIBILITY[req.blood_group as string] ?? [];
  if (groups.length === 0) return;
  const urgent = req.urgency === 'urgent' || req.urgency === 'critical';
  const radiusKm = urgent ? 25 : 15;
  const requestId = event.params.requestId;

  const snaps = await Promise.all(
    cellsCovering(lat, lng, radiusKm, 4).map((cell) =>
      db
        .collection('donors')
        .where('is_available', '==', true)
        .where('blood_group', 'in', groups)
        .where('geohash', '>=', cell)
        .where('geohash', '<', `${cell}~`)
        .limit(60)
        .get(),
    ),
  );

  const now = Date.now();
  const seen = new Set<string>();
  const loud: Array<{ uid: string; token: string }> = [];
  const quiet: Array<{ uid: string; token: string }> = [];
  for (const snap of snaps) {
    for (const doc of snap.docs) {
      if (seen.has(doc.id)) continue;
      seen.add(doc.id);
      const d = doc.data();
      if (!eligibleDonor(doc.id, d, req, now)) continue;
      if (distanceKm(lat, lng, Number(d.lat), Number(d.lng)) > radiusKm) continue;
      (urgent && d.urgent_alerts === true ? loud : quiet).push({ uid: doc.id, token: d.fcm_token });
    }
  }

  const place = shortPlace(req.location_label as string | undefined);
  const units = Number(req.units_needed ?? 1);
  const unitText = `${units} ${units === 1 ? 'unit' : 'units'}`;
  const label = req.urgency === 'critical' ? 'Critical' : 'Urgent';
  const data = { type: 'request', requestId };
  const sentLoud = await sendToMany(loud, {
    title: `${label}: ${req.blood_group} blood needed near you`,
    body: `${unitText} · ${place}. Tap to help.`,
    channel: 'urgent_alerts',
    tag: `req_${requestId}`,
    data: { ...data, type: 'urgent_request' },
  });
  const sentQuiet = await sendToMany(quiet, {
    title: `${urgent ? `${label}: ` : ''}${req.blood_group} blood needed nearby`,
    body: `${unitText} · ${place}. You're a compatible donor.`,
    channel: 'requests',
    tag: `req_${requestId}`,
    data,
  });
  logger.info('request fan-out', { requestId, candidates: seen.size, sentLoud, sentQuiet });
});

export function eligibleDonor(uid: string, d: DocumentData, req: DocumentData, now: number): boolean {
  if (uid === req.requester_uid) return false;
  if (d.is_banned === true || d.active_request_id) return false;
  if (typeof d.fcm_token !== 'string' || d.fcm_token.length === 0) return false;
  const until = d.reactivation_scheduled_at as Timestamp | undefined;
  if (until && until.toMillis() > now) return false;
  return typeof d.lat === 'number' && typeof d.lng === 'number';
}

/** Every status change either side needs to hear about while the app is closed. */
export const onRequestUpdated = onDocumentUpdated('requests/{requestId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  const requestId = event.params.requestId;
  const donorName = (after.matched_donor_name as string) || 'Your donor';
  const requesterName = (after.requester_name as string) || 'The requester';
  const push = (title: string, body: string): Push => ({
    title,
    body,
    channel: 'requests',
    tag: `req_${requestId}`,
    data: { type: 'request', requestId },
  });

  const jobs: Array<Promise<void>> = [];
  const was = before.status;
  const now = after.status;

  if (was === 'open' && now === 'matched') {
    jobs.push(sendToUser(after.requester_uid, push(
      'A donor accepted your request',
      `${donorName} can donate ${after.blood_group}. Message or call them in the app.`,
    )));
  }
  if (was === 'matched' && now === 'open' && before.matched_donor_id) {
    jobs.push(sendToUser(after.requester_uid, push(
      'Your donor can’t make it',
      'Your request is open to nearby donors again.',
    )));
  }
  if (was === 'matched' && now === 'cancelled' && after.matched_donor_id) {
    jobs.push(sendToUser(after.matched_donor_id, push(
      'Request cancelled',
      `${requesterName} no longer needs this donation. Thank you for stepping up.`,
    )));
  }
  if (now === 'matched' && !before.donor_confirmed_at && after.donor_confirmed_at) {
    jobs.push(sendToUser(after.requester_uid, push(
      'Please confirm the donation',
      `${donorName} says they have donated. Confirm in the app to complete your request.`,
    )));
  }
  if (now === 'matched' && !before.requester_confirmed_at && after.requester_confirmed_at) {
    jobs.push(sendToUser(after.matched_donor_id, push(
      'Did you donate?',
      `${requesterName} confirmed receiving your donation. Tap to record it.`,
    )));
  }
  if (was !== 'fulfilled' && now === 'fulfilled') {
    jobs.push(applyDonorCompletion(requestId, after));
    jobs.push(sendToUser(after.requester_uid, push('Donation completed', `Thank you for using Rakta Bandhan. ${donorName} helped today.`)));
    jobs.push(sendToUser(after.matched_donor_id, push('Donation recorded — thank you', 'Your donation certificate is ready in Donation history.')));
  }
  if (was === 'open' && now === 'expired') {
    jobs.push(sendToUser(after.requester_uid, push(
      'No donor found in time',
      'Your request has closed. You can raise a new one from the app.',
    )));
  }
  await Promise.all(jobs);
});

/**
 * The donor's side of a completed donation, when the requester's
 * confirmation completed it (the requester can't write the donor's
 * profile): 90-day cooldown, availability off, lock released, one history
 * record keyed by the request id. Guarded by the donor's own
 * `active_request_id`, which the app clears in the same write when it
 * applies this itself — so the two paths can never both apply.
 * Keep in step with Backend._writeDonorCompletion.
 */
export const DONOR_COOLDOWN_DAYS = 90;

export async function applyDonorCompletion(requestId: string, req: DocumentData): Promise<void> {
  const donorId = req.matched_donor_id as string | undefined;
  if (!donorId) return;
  const donorRef = db.collection('donors').doc(donorId);
  await db.runTransaction(async (tx) => {
    const donor = await tx.get(donorRef);
    if (!donor.exists || donor.get('active_request_id') !== requestId) return;
    const until = Timestamp.fromMillis(Date.now() + DONOR_COOLDOWN_DAYS * 86400000);
    tx.update(donorRef, {
      last_donation_date: FieldValue.serverTimestamp(),
      is_available: false,
      active_request_id: null,
      reactivation_scheduled_at: until,
    });
    tx.set(db.collection('donors_public').doc(donorId), { is_available: false, updated_at: FieldValue.serverTimestamp() }, { merge: true });
    tx.set(db.collection('donation_history').doc(requestId), {
      donor_id: donorId,
      request_id: requestId,
      donation_date: FieldValue.serverTimestamp(),
      confirmed_by: 'both',
      hospital: req.location_label ?? '',
      blood_group: req.blood_group ?? '',
    });
  });
}

/** Closes open requests nobody accepted before `expires_at` (6 hours). */
export const expireOldRequests = onSchedule({ schedule: 'every 15 minutes', timeZone: 'Asia/Kolkata' }, async () => {
  const snap = await db
    .collection('requests')
    .where('status', '==', 'open')
    .where('expires_at', '<', Timestamp.now())
    .limit(400)
    .get();
  if (snap.empty) return;
  const batch = db.batch();
  for (const doc of snap.docs) {
    batch.update(doc.ref, { status: 'expired', expired_at: FieldValue.serverTimestamp() });
  }
  await batch.commit();
  logger.info('expired requests', { count: snap.size });
});

// ────────────────────────────────────────────────────────── Broadcasts

/**
 * An admin writes `broadcasts/{id}` from the console ({title, body,
 * blood_group?}); this delivers it to the FCM topic every signed-in phone
 * subscribes to ("all", or its blood group's topic) and records the result.
 */
export const onBroadcast = onDocumentCreated('broadcasts/{id}', async (event) => {
  const b = event.data?.data();
  if (!b || !event.data) return;
  const title = String(b.title ?? '').slice(0, 80);
  const body = String(b.body ?? '').slice(0, 300);
  if (!title && !body) return;
  const topic = b.blood_group ? bloodGroupTopic(String(b.blood_group)) : 'all';
  try {
    const messageId = await messaging.send({
      topic,
      notification: { title: title || 'Rakta Bandhan', body },
      data: { type: 'broadcast', title, body },
      android: { priority: 'high', notification: { channelId: 'general', icon: ICON, color: COLOR } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    await event.data.ref.update({ status: 'sent', topic, message_id: messageId, sent_at: FieldValue.serverTimestamp() });
  } catch (e) {
    logger.error('broadcast failed', e);
    await event.data.ref.update({ status: 'failed', topic, error: String((e as Error).message ?? e) });
  }
});

// ─────────────────────────────────────────────────────────── Community

/** A deleted post takes its photo (and thumbnail) with it. */
export const onStoryDeleted = onDocumentDeleted('community_stories/{id}', async (event) => {
  const data = event.data?.data();
  const paths = [data?.image_path, data?.thumb_path].filter((p): p is string => typeof p === 'string' && p.length > 0);
  const bucket = getStorage().bucket();
  await Promise.all(paths.map((p) => bucket.file(p).delete({ ignoreNotFound: true })));
});

export { requestLoginCode, verifyLoginCode, deleteMyAuthAccount } from './login';
