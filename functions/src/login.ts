// Passwordless sign-in: a 6-digit code sent to the user's email (SMS later),
// exchanged for a Firebase custom token.
//
//   app → requestLoginCode({ email })        → code emailed
//   app → verifyLoginCode({ email, code })   → { token } → signInWithCustomToken
//
// Codes are stored only as hashes in `login_codes/{key}` (no client access —
// the rules' catch-all denies it), expire after 10 minutes, allow 5 guesses,
// and are rate-limited per address (30 s gap, 8 a day) and per IP (20 an
// hour). Email goes out over SMTP — any provider (Brevo, Amazon SES, Zoho
// ZeptoMail…) — configured with one secret:
//   firebase functions:secrets:set SMTP_URL
//   e.g. smtps://USER:PASSWORD@smtp-relay.brevo.com:465
// The SMS channel is wired through the same functions; it only needs a
// provider in `sendSms` (DLT-registered sender, see cost-estimate.md).

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';
import { FieldValue } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';
import nodemailer from 'nodemailer';

import { auth, db, isEmulator } from './app';
import {
  CODE_TTL_MS,
  Channel,
  MAX_ATTEMPTS,
  MAX_SENDS_PER_IP_HOUR,
  RESEND_GAP_MS,
  SendState,
  VerifyState,
  checkCode,
  dayKey,
  destinationKey,
  emailContent,
  generateCode,
  hashCode,
  normalizeEmail,
  parseReviewEmails,
  reviewCodeFor,
  sendRefusal,
} from './otp';

const SMTP_URL = defineSecret('SMTP_URL');
const MAIL_FROM = defineString('MAIL_FROM', { default: 'Rakta Bandhan <no-reply@raktabandhan.org>' });
// App-store review access: for the addresses listed in REVIEW_EMAILS the sign-in
// code is the fixed REVIEW_CODE and no email is sent. Leave REVIEW_EMAILS empty
// (the default) and the feature doesn't exist. See docs/launch/AFTER_BLAZE_UPGRADE.md.
const REVIEW_EMAILS = defineString('REVIEW_EMAILS', { default: '' });
const REVIEW_CODE = defineSecret('REVIEW_CODE');

/** Mixed into code hashes so a leaked hash isn't a lookup-table hit. */
const PEPPER = 'rakta-bandhan-login-v1';

/** Custom claim on every token minted here; the rules accept it as "verified". */
export const LOGIN_CLAIM = { login: 'email_otp' };

function readSmtpUrl(): string {
  try {
    return SMTP_URL.value() ?? '';
  } catch {
    return '';
  }
}

function reviewList(): string[] {
  try {
    return parseReviewEmails(REVIEW_EMAILS.value());
  } catch {
    return [];
  }
}

/** The fixed review code for this address, or null when review access doesn't apply. */
function reviewCodeForEmail(email: string): string | null {
  try {
    return reviewCodeFor(email, reviewList(), REVIEW_CODE.value());
  } catch {
    return null;
  }
}

async function sendEmail(to: string, code: string): Promise<void> {
  const smtp = readSmtpUrl();
  if (!smtp) {
    if (isEmulator) {
      logger.info(`[emulator] login code for ${to}: ${code}`);
      return;
    }
    throw new HttpsError('failed-precondition', 'Email sign-in isn’t set up yet. Please try again later.');
  }
  const { subject, text, html } = emailContent(code);
  await nodemailer.createTransport(smtp).sendMail({ from: MAIL_FROM.value(), to, subject, text, html });
}

/** Per-IP hourly budget, so one client can't spray codes at many addresses. */
async function chargeIp(ip: string): Promise<void> {
  const hour = Math.floor(Date.now() / 3_600_000);
  const ref = db.doc(`login_ip/${createHash('sha256').update(ip).digest('hex').slice(0, 32)}`);
  await db.runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data();
    const count = d?.hour === hour ? (d.count as number) : 0;
    if (count >= MAX_SENDS_PER_IP_HOUR) {
      throw new HttpsError('resource-exhausted', 'Too many sign-in attempts from this network. Try again in an hour.');
    }
    tx.set(ref, { hour, count: count + 1, updated_at: FieldValue.serverTimestamp() });
  });
}

export const requestLoginCode = onCall({ secrets: [SMTP_URL, REVIEW_CODE] }, async (req) => {
  const channel: Channel = req.data?.channel === 'sms' ? 'sms' : 'email';
  if (channel === 'sms') {
    throw new HttpsError('unimplemented', 'Codes by SMS are coming soon. Please use your email for now.');
  }
  const email = normalizeEmail(req.data?.email);
  if (!email) throw new HttpsError('invalid-argument', 'Enter a valid email address.');

  await chargeIp(req.rawRequest?.ip ?? 'unknown');

  const now = Date.now();
  const ref = db.doc(`login_codes/${destinationKey(channel, email)}`);
  // A review address signs in with the fixed code, through the same hashing,
  // expiry and five-try limit as any code; only the email is skipped.
  const reviewCode = reviewCodeForEmail(email);
  const code = reviewCode ?? generateCode();
  await db.runTransaction(async (tx) => {
    const state = (await tx.get(ref)).data() as SendState | undefined;
    const refusal = sendRefusal(state, now);
    if (refusal?.reason === 'too_soon') {
      throw new HttpsError('resource-exhausted', `Please wait ${refusal.retryAfterS} seconds before asking for another code.`, {
        retryAfterS: refusal.retryAfterS,
      });
    }
    if (refusal?.reason === 'daily_limit') {
      throw new HttpsError('resource-exhausted', 'Too many codes for this email today. Try again tomorrow.');
    }
    const today = dayKey(now);
    tx.set(ref, {
      channel,
      code_hash: hashCode(code, email, PEPPER),
      expires_ms: now + CODE_TTL_MS,
      attempts: 0,
      last_sent_ms: now,
      day: today,
      sends_today: state?.day === today ? (state.sends_today ?? 0) + 1 : 1,
      updated_at: FieldValue.serverTimestamp(),
      // Emulator only: lets automated tests read the code back.
      ...(isEmulator ? { dev_code: code } : {}),
    });
  });

  try {
    if (!reviewCode) await sendEmail(email, code);
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    logger.error('login email failed', { error: String(e) });
    throw new HttpsError('unavailable', 'We couldn’t send the email. Check the address and try again.');
  }
  return { sent: true, resendAfterS: Math.round(RESEND_GAP_MS / 1000) };
});

export const verifyLoginCode = onCall(async (req) => {
  const email = normalizeEmail(req.data?.email);
  const code = typeof req.data?.code === 'string' ? req.data.code.trim() : '';
  if (!email || !/^\d{6}$/.test(code)) throw new HttpsError('invalid-argument', 'Enter the 6-digit code from the email.');

  const ref = db.doc(`login_codes/${destinationKey('email', email)}`);
  const now = Date.now();
  let attemptsLeft = 0;
  const outcome = await db.runTransaction(async (tx) => {
    const state = (await tx.get(ref)).data() as VerifyState | undefined;
    const result = checkCode(state, hashCode(code, email, PEPPER), now);
    if (result === 'ok') {
      // One use only. Keep the send counters for the daily limit.
      tx.update(ref, { code_hash: FieldValue.delete(), expires_ms: FieldValue.delete(), dev_code: FieldValue.delete() });
    } else if (result === 'wrong_code') {
      const attempts = (state?.attempts ?? 0) + 1;
      attemptsLeft = Math.max(0, MAX_ATTEMPTS - attempts);
      tx.update(ref, { attempts });
    }
    return result;
  });

  switch (outcome) {
    case 'no_code':
      throw new HttpsError('failed-precondition', 'This code has already been used or replaced. Ask for a new one.');
    case 'expired':
      throw new HttpsError('deadline-exceeded', 'This code has expired. Ask for a new one.');
    case 'too_many_attempts':
      throw new HttpsError('resource-exhausted', 'Too many wrong tries. Ask for a new code.');
    case 'wrong_code':
      throw new HttpsError(
        'permission-denied',
        attemptsLeft > 0 ? `That code isn’t right. ${attemptsLeft} ${attemptsLeft === 1 ? 'try' : 'tries'} left.` : 'Too many wrong tries. Ask for a new code.',
      );
  }

  // The same email always lands on the same account (and its profile).
  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (e) {
    if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
    user = await auth.createUser({ email, emailVerified: true });
  }
  if (user.disabled) throw new HttpsError('permission-denied', 'This account has been disabled. Contact support.');
  // A review address is a stand-in for a reviewer, never for staff: the fixed
  // code must never open an admin account. Every review sign-in is logged.
  if (reviewList().includes(email)) {
    if ((await db.doc(`admins/${user.uid}`).get()).exists) {
      throw new HttpsError('permission-denied', 'This account can’t be used for review sign-in.');
    }
    logger.warn('review account signed in', { uid: user.uid });
  }
  if (!user.emailVerified) await auth.updateUser(user.uid, { emailVerified: true });
  const token = await auth.createCustomToken(user.uid, LOGIN_CLAIM);
  return { token, isNewUser: user.metadata.lastSignInTime == null };
});

/**
 * In-app account deletion, last step: removes the sign-in account itself
 * (the app has already removed the user's data — see AccountService).
 * Done here because a passwordless account can't "re-enter its password"
 * to satisfy Firebase's recent-login rule on the client.
 */
export const deleteMyAuthAccount = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  await auth.deleteUser(uid);
  return { deleted: true };
});
