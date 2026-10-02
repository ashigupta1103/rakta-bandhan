// Pure helpers for the login-code flow (no Firebase imports, so they're
// unit-testable). The callables that use them live in login.ts.

import { createHash, randomInt, timingSafeEqual } from 'node:crypto';

export const CODE_LENGTH = 6;
/** A code works for 10 minutes. */
export const CODE_TTL_MS = 10 * 60 * 1000;
/** Wait between two sends to the same address. */
export const RESEND_GAP_MS = 30 * 1000;
/** Codes per address per day (resends included). */
export const MAX_SENDS_PER_DAY = 8;
/** Wrong guesses before a code is burned. */
export const MAX_ATTEMPTS = 5;
/** Codes requested per IP address per hour (stops one attacker spraying addresses). */
export const MAX_SENDS_PER_IP_HOUR = 20;

export type Channel = 'email' | 'sms';

export function normalizeEmail(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const email = raw.trim().toLowerCase();
  if (email.length > 254 || !/^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.test(email)) return null;
  return email;
}

/** Indian mobile numbers only, as +91XXXXXXXXXX (for the SMS channel later). */
export function normalizeIndianMobile(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const digits = raw.replace(/\D/g, '').replace(/^91(?=\d{10}$)/, '');
  return /^[6-9]\d{9}$/.test(digits) ? `+91${digits}` : null;
}

/** The REVIEW_EMAILS setting: a comma list of addresses, normalised; anything that isn't an email is dropped. */
export function parseReviewEmails(raw: unknown): string[] {
  if (typeof raw !== 'string') return [];
  return raw.split(',').map((e) => normalizeEmail(e)).filter((e): e is string => e !== null);
}

/**
 * The fixed sign-in code app-store reviewers use (they can't read an email),
 * when it applies to this address: it is on the allow-list and the configured
 * code is 6 digits. Null otherwise, including when either setting is missing,
 * so with nothing configured the feature doesn't exist.
 */
export function reviewCodeFor(email: string, allowList: string[], configured: unknown): string | null {
  if (!allowList.includes(email)) return null;
  return typeof configured === 'string' && /^\d{6}$/.test(configured) ? configured : null;
}

export function generateCode(): string {
  return String(randomInt(0, 10 ** CODE_LENGTH)).padStart(CODE_LENGTH, '0');
}

/** Codes are stored only as a salted hash, keyed to the destination. */
export function hashCode(code: string, destination: string, pepper: string): string {
  return createHash('sha256').update(`${pepper}|${destination}|${code}`).digest('hex');
}

export function sameHash(a: string, b: string): boolean {
  const x = Buffer.from(a, 'hex');
  const y = Buffer.from(b, 'hex');
  return x.length === y.length && timingSafeEqual(x, y);
}

/** Document id for a destination — never the raw email or number. */
export function destinationKey(channel: Channel, destination: string): string {
  return createHash('sha256').update(`${channel}:${destination}`).digest('hex').slice(0, 40);
}

export function dayKey(now: number): string {
  // India time, so the daily limit resets at local midnight.
  return new Date(now + 5.5 * 3600 * 1000).toISOString().slice(0, 10);
}

export interface SendState {
  last_sent_ms?: number;
  day?: string;
  sends_today?: number;
}

/** Why a send must be refused, or null if it may go ahead. */
export function sendRefusal(state: SendState | undefined, now: number): { reason: 'too_soon' | 'daily_limit'; retryAfterS: number } | null {
  if (state?.last_sent_ms && now - state.last_sent_ms < RESEND_GAP_MS) {
    return { reason: 'too_soon', retryAfterS: Math.ceil((RESEND_GAP_MS - (now - state.last_sent_ms)) / 1000) };
  }
  if (state?.day === dayKey(now) && (state.sends_today ?? 0) >= MAX_SENDS_PER_DAY) {
    return { reason: 'daily_limit', retryAfterS: 0 };
  }
  return null;
}

export interface VerifyState {
  code_hash?: string;
  expires_ms?: number;
  attempts?: number;
}

export type VerifyOutcome = 'ok' | 'no_code' | 'expired' | 'too_many_attempts' | 'wrong_code';

export function checkCode(state: VerifyState | undefined, submittedHash: string, now: number): VerifyOutcome {
  if (!state?.code_hash || !state.expires_ms) return 'no_code';
  if (now > state.expires_ms) return 'expired';
  if ((state.attempts ?? 0) >= MAX_ATTEMPTS) return 'too_many_attempts';
  return sameHash(state.code_hash, submittedHash) ? 'ok' : 'wrong_code';
}

export function emailContent(code: string): { subject: string; text: string; html: string } {
  const spaced = `${code.slice(0, 3)} ${code.slice(3)}`;
  return {
    subject: `${code} is your Rakta Bandhan code`,
    text:
      `Your Rakta Bandhan sign-in code is ${spaced}.\n\n` +
      'It works for 10 minutes. If you didn’t ask for it, you can ignore this email — nobody can sign in without the code.\n\n' +
      '— Rakta Bandhan, a service project of Rotary Club of Madras Cosmos & Rotary Club of Chennai Capital',
    html: `<!doctype html><html><body style="margin:0;background:#FCF8F2;font-family:Arial,Helvetica,sans-serif;color:#241413">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px">
<table role="presentation" width="100%" style="max-width:440px;background:#ffffff;border:1px solid #EADFCF;border-radius:16px" cellpadding="0" cellspacing="0">
<tr><td style="height:6px;background:#B81E14;border-radius:16px 16px 0 0"></td></tr>
<tr><td style="padding:28px 28px 8px;font-size:20px;font-weight:bold">Your sign-in code</td></tr>
<tr><td style="padding:0 28px;font-size:14px;color:#6B534E;line-height:1.5">Enter this code in the Rakta Bandhan app. It works for 10 minutes.</td></tr>
<tr><td style="padding:22px 28px"><div style="font-size:34px;letter-spacing:8px;font-weight:bold;color:#B81E14;text-align:center;background:#FBF0D9;border-radius:12px;padding:16px 0">${spaced}</div></td></tr>
<tr><td style="padding:0 28px 26px;font-size:12.5px;color:#6B534E;line-height:1.5">Didn’t ask for this? Ignore this email — nobody can sign in without the code. Never share it, not even with someone claiming to be from Rakta Bandhan.</td></tr>
</table>
<p style="font-size:11.5px;color:#A2908A;margin-top:16px">Rakta Bandhan · a service project of Rotary Club of Madras Cosmos &amp; Rotary Club of Chennai Capital</p>
</td></tr></table></body></html>`,
  };
}
