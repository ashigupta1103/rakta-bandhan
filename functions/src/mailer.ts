import { defineSecret, defineString } from 'firebase-functions/params';
import { HttpsError } from 'firebase-functions/v2/https';
import nodemailer from 'nodemailer';
import { isEmulator } from './app';

export const SMTP_URL = defineSecret('SMTP_URL');
const MAIL_FROM = defineString('MAIL_FROM', { default: 'Rakta Bandhan <no-reply@raktabandhan.org>' });

export async function sendMail(to: string, content: { subject: string; text: string; html: string }): Promise<void> {
  if (isEmulator) return; // Never send from local smoke tests, even with a real SMTP URL.
  const smtp = SMTP_URL.value();
  if (!smtp) throw new HttpsError('failed-precondition', 'Email sign-in isn’t set up yet. Please try again later.');
  await nodemailer.createTransport(smtp).sendMail({ from: MAIL_FROM.value(), to, ...content });
}
