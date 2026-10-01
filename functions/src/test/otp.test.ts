import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  CODE_TTL_MS,
  MAX_ATTEMPTS,
  MAX_SENDS_PER_DAY,
  RESEND_GAP_MS,
  checkCode,
  dayKey,
  destinationKey,
  emailContent,
  generateCode,
  hashCode,
  normalizeEmail,
  normalizeIndianMobile,
  parseReviewEmails,
  reviewCodeFor,
  sendRefusal,
} from '../otp';

test('emails are normalised and validated', () => {
  assert.equal(normalizeEmail('  Donor@Example.COM '), 'donor@example.com');
  assert.equal(normalizeEmail('no-at-sign'), null);
  assert.equal(normalizeEmail('a@b'), null);
  assert.equal(normalizeEmail(42), null);
});

test('Indian mobile numbers are normalised for the SMS channel', () => {
  assert.equal(normalizeIndianMobile('98765 43210'), '+919876543210');
  assert.equal(normalizeIndianMobile('+91-9876543210'), '+919876543210');
  assert.equal(normalizeIndianMobile('1234567890'), null);
});

test('codes are 6 digits, including leading zeros', () => {
  for (let i = 0; i < 500; i++) assert.match(generateCode(), /^\d{6}$/);
});

test('hashes depend on the code and the destination', () => {
  const a = hashCode('123456', 'a@x.com', 'p');
  assert.equal(a, hashCode('123456', 'a@x.com', 'p'));
  assert.notEqual(a, hashCode('123457', 'a@x.com', 'p'));
  assert.notEqual(a, hashCode('123456', 'b@x.com', 'p'));
  assert.notEqual(destinationKey('email', 'a@x.com'), destinationKey('sms', 'a@x.com'));
  assert.ok(!destinationKey('email', 'a@x.com').includes('a@x.com'));
});

test('resend gap and daily limit', () => {
  const now = 1_800_000_000_000;
  assert.equal(sendRefusal(undefined, now), null);
  assert.equal(sendRefusal({ last_sent_ms: now - 5000 }, now)?.reason, 'too_soon');
  assert.equal(sendRefusal({ last_sent_ms: now - RESEND_GAP_MS - 1 }, now), null);
  assert.equal(
    sendRefusal({ last_sent_ms: now - 60_000, day: dayKey(now), sends_today: MAX_SENDS_PER_DAY }, now)?.reason,
    'daily_limit',
  );
  // Yesterday's count doesn't block today.
  assert.equal(sendRefusal({ last_sent_ms: now - 60_000, day: '2000-01-01', sends_today: 99 }, now), null);
});

test('code check: right, wrong, expired, burned, missing', () => {
  const now = 1_800_000_000_000;
  const good = hashCode('111111', 'a@x.com', 'p');
  const state = { code_hash: good, expires_ms: now + CODE_TTL_MS, attempts: 0 };
  assert.equal(checkCode(state, good, now), 'ok');
  assert.equal(checkCode(state, hashCode('222222', 'a@x.com', 'p'), now), 'wrong_code');
  assert.equal(checkCode({ ...state, expires_ms: now - 1 }, good, now), 'expired');
  assert.equal(checkCode({ ...state, attempts: MAX_ATTEMPTS }, good, now), 'too_many_attempts');
  assert.equal(checkCode(undefined, good, now), 'no_code');
  assert.equal(checkCode({ attempts: 0 }, good, now), 'no_code');
});

test('the email shows the code in the subject and body', () => {
  const m = emailContent('012345');
  assert.match(m.subject, /^012345 /);
  assert.match(m.text, /012 345/);
  assert.match(m.html, /012 345/);
});

test('the review allow-list is parsed from a comma list and drops anything that is not an email', () => {
  assert.deepEqual(parseReviewEmails(' Review-A@Example.com , review-b@example.com,not-an-email,, '), [
    'review-a@example.com',
    'review-b@example.com',
  ]);
  assert.deepEqual(parseReviewEmails(''), []);
  assert.deepEqual(parseReviewEmails(undefined), []);
  assert.deepEqual(parseReviewEmails(42), []);
});

test('the review code applies only to a listed address and only when it is 6 digits', () => {
  const list = ['review-a@example.com'];
  assert.equal(reviewCodeFor('review-a@example.com', list, '246810'), '246810');
  assert.equal(reviewCodeFor('someone@example.com', list, '246810'), null, 'not on the list');
  assert.equal(reviewCodeFor('review-a@example.com', [], '246810'), null, 'empty list = feature off');
  for (const bad of [undefined, '', '12345', '1234567', 'abcdef', 246810]) {
    assert.equal(reviewCodeFor('review-a@example.com', list, bad), null, `configured=${String(bad)}`);
  }
});
