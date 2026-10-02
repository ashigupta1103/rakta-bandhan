// Small pure decisions the Cloud Functions make, with no Firebase imports so
// they can be unit-tested directly.

/** What an update to a donor doc means for their sign-in account. */
export function banTransition(
  before: { is_banned?: unknown } | undefined,
  after: { is_banned?: unknown } | undefined,
): 'ban' | 'unban' | null {
  const was = before?.is_banned === true;
  const now = after?.is_banned === true;
  if (!was && now) return 'ban';
  if (was && !now) return 'unban';
  return null;
}

/** A resting donor whose rest period has ended and who can be made available again. */
export function dueForReactivation(
  donor: { is_available?: unknown; is_banned?: unknown; reactivation_scheduled_at?: { toMillis?: () => number } | null },
  nowMs: number,
): boolean {
  if (donor.is_banned === true || donor.is_available === true) return false;
  const until = donor.reactivation_scheduled_at?.toMillis?.();
  return typeof until === 'number' && until <= nowMs;
}

/** "2026-10" in India time, the month the impact counter belongs to. */
export function monthKey(nowMs: number): string {
  return new Date(nowMs + 5.5 * 3600 * 1000).toISOString().slice(0, 7);
}

/** The impact counter after one more completed donation; a new month starts again at 1. */
export function nextImpact(
  prev: { month_key?: unknown; donations_this_month?: unknown } | undefined,
  nowMs: number,
): { month_key: string; donations_this_month: number } {
  const month = monthKey(nowMs);
  const count = prev?.month_key === month && typeof prev.donations_this_month === 'number' ? prev.donations_this_month : 0;
  return { month_key: month, donations_this_month: count + 1 };
}

/** A callable is refused when enforcement is on, it isn't the emulator, and the request carries no valid App Check token. */
export function appCheckRefused(enforce: boolean, emulator: boolean, hasValidToken: boolean): boolean {
  return enforce && !emulator && !hasValidToken;
}
