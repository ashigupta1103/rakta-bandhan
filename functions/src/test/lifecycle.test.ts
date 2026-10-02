import { test } from 'node:test';
import assert from 'node:assert/strict';

import { appCheckRefused, banTransition, dueForReactivation, monthKey, nextImpact } from '../lifecycle';

const at = (ms: number) => ({ toMillis: () => ms });

test('only a change of is_banned affects the sign-in account', () => {
  assert.equal(banTransition({ is_banned: false }, { is_banned: true }), 'ban');
  assert.equal(banTransition({ is_banned: true }, { is_banned: false }), 'unban');
  assert.equal(banTransition({ is_banned: false }, { is_banned: false }), null);
  assert.equal(banTransition({ is_banned: true }, { is_banned: true }), null);
  assert.equal(banTransition({}, { is_banned: true }), 'ban', 'a missing flag counts as not banned');
  assert.equal(banTransition(undefined, undefined), null);
  assert.equal(banTransition({ is_banned: 'yes' }, { is_banned: 'yes' }), null, 'only a real true bans');
});

test('a donor is reactivated only when resting, not banned, and the rest has ended', () => {
  const now = 1_000_000;
  assert.equal(dueForReactivation({ is_available: false, reactivation_scheduled_at: at(now - 1) }, now), true);
  assert.equal(dueForReactivation({ is_available: false, reactivation_scheduled_at: at(now) }, now), true);
  assert.equal(dueForReactivation({ is_available: false, reactivation_scheduled_at: at(now + 1) }, now), false, 'rest not over');
  assert.equal(dueForReactivation({ is_available: true, reactivation_scheduled_at: at(now - 1) }, now), false, 'already available');
  assert.equal(dueForReactivation({ is_available: false, is_banned: true, reactivation_scheduled_at: at(now - 1) }, now), false);
  assert.equal(dueForReactivation({ is_available: false }, now), false, 'no schedule: switched off by choice');
  assert.equal(dueForReactivation({ is_available: false, reactivation_scheduled_at: null }, now), false);
});

test('the impact counter counts up within a month and starts again in the next', () => {
  const oct = Date.UTC(2026, 9, 15, 6, 0);
  assert.deepEqual(nextImpact(undefined, oct), { month_key: '2026-10', donations_this_month: 1 });
  assert.deepEqual(nextImpact({ month_key: '2026-10', donations_this_month: 41 }, oct), { month_key: '2026-10', donations_this_month: 42 });
  assert.deepEqual(nextImpact({ month_key: '2026-09', donations_this_month: 90 }, oct), { month_key: '2026-10', donations_this_month: 1 });
  assert.deepEqual(nextImpact({ month_key: '2026-10', donations_this_month: 'lots' }, oct), { month_key: '2026-10', donations_this_month: 1 });
});

test('the month rolls over at midnight in India, not in UTC', () => {
  // 23:59 IST on 31 Oct is 18:29 UTC; two minutes later it is already November in India.
  assert.equal(monthKey(Date.UTC(2026, 9, 31, 18, 29)), '2026-10');
  assert.equal(monthKey(Date.UTC(2026, 9, 31, 18, 31)), '2026-11');
  assert.equal(monthKey(Date.UTC(2026, 11, 31, 18, 31)), '2027-01');
});

test('App Check refuses only when enforced, off the emulator, without a valid token', () => {
  assert.equal(appCheckRefused(true, false, false), true);
  assert.equal(appCheckRefused(true, false, true), false);
  assert.equal(appCheckRefused(true, true, false), false, 'the emulator never has tokens');
  assert.equal(appCheckRefused(false, false, false), false, 'enforcement is off by default');
});
