import { defineBoolean } from 'firebase-functions/params';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { FieldValue } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { auth, db, isEmulator, messaging } from './app';
import { sendMail, SMTP_URL } from './mailer';
import { supportContent, supportDeliveryMode } from './support-content';

const ENABLE_SUPPORT_DELIVERY = defineBoolean('ENABLE_SUPPORT_DELIVERY', { default: false });

/** In-app replies are already stored. Outbound delivery is owner-enabled after Blaze. */
export const onReplyCreated = onDocumentCreated({ document: 'support_replies/{id}', secrets: [SMTP_URL] }, async (event) => {
  const reply = event.data;
  if (!reply) return;
  const mode = supportDeliveryMode(ENABLE_SUPPORT_DELIVERY.value(), isEmulator);
  if (mode !== 'send') { await reply.ref.update({ delivery_state: mode }); return; }
  const data = reply.data();
  if (typeof data.to_uid !== 'string' || typeof data.body !== 'string') return;
  // Claim once before side effects: retries cannot send the same email twice.
  // A crash after this claim can lose delivery; the in-app reply remains available.
  const claimed = await db.runTransaction(async (tx) => {
    if ((await tx.get(reply.ref)).get('delivery_state')) return false;
    tx.update(reply.ref, { delivery_state: 'sending', delivery_attempted_at: FieldValue.serverTimestamp() });
    return true;
  });
  if (!claimed) return;
  try {
    const user = await auth.getUser(data.to_uid);
    if (user.disabled) { await reply.ref.update({ delivery_state: 'account-disabled' }); return; }
    if (user.email) await sendMail(user.email, supportContent(data.body));
    const token = (await db.doc(`donors/${data.to_uid}`).get()).get('fcm_token');
    if (typeof token === 'string' && token) {
      await messaging.send({ token, notification: { title: 'Rakta Bandhan support', body: 'You have a reply. Open My reports to read it.' },
        data: { type: 'support_reply', source_id: String(data.source_id ?? '') }, android: { notification: { channelId: 'general' } } });
    }
    await reply.ref.update({ delivery_state: 'sent', delivered_at: FieldValue.serverTimestamp() });
  } catch (e) {
    logger.warn('support delivery failed', { id: reply.id, code: (e as { code?: string }).code ?? 'delivery-failed' });
    await reply.ref.update({ delivery_state: 'failed' });
  }
});
