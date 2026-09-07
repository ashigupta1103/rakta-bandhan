/**
 * Application-wide constants for Rakta Bandhan backend.
 * Adjust these values without touching business logic.
 */

// ─── Geo Matching ─────────────────────────────────────────────────────────

/** Default search radius in kilometers */
const DEFAULT_RADIUS_KM = 5;

/** Expanded radius if no donors found at default radius */
const EXPANDED_RADIUS_KM = 15;

/** Maximum number of donors to notify per request */
const MAX_DONORS_TO_NOTIFY = 10;

// ─── Donor Cooldown ───────────────────────────────────────────────────────

/** Days a donor must wait after donating before becoming eligible again */
const DONOR_COOLDOWN_DAYS = 90;

/** Milliseconds equivalent of cooldown */
const DONOR_COOLDOWN_MS = DONOR_COOLDOWN_DAYS * 24 * 60 * 60 * 1000;

// ─── Request Lifecycle ────────────────────────────────────────────────────

/** Hours after which an open, unmatched request is auto-expired */
const REQUEST_EXPIRY_HOURS = 6;

/** Milliseconds equivalent */
const REQUEST_EXPIRY_MS = REQUEST_EXPIRY_HOURS * 60 * 60 * 1000;

// ─── Notification Throttling ──────────────────────────────────────────────

/** Minimum minutes between two alerts to the same donor */
const DONOR_ALERT_COOLDOWN_MIN = 30;

/** If a donor's last_seen is older than this (minutes), fall back to SMS */
const SMS_FALLBACK_THRESHOLD_MIN = 30;

/** Max push alerts a single donor receives per day */
const MAX_ALERTS_PER_DONOR_PER_DAY = 5;

// ─── Blood Group Compatibility Map ───────────────────────────────────────
// Key = required blood group → Value = array of compatible donor groups
// (donor can donate TO the required group)
const BLOOD_COMPATIBILITY = {
  'A+':  ['A+', 'A-', 'O+', 'O-'],
  'A-':  ['A-', 'O-'],
  'B+':  ['B+', 'B-', 'O+', 'O-'],
  'B-':  ['B-', 'O-'],
  'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], // universal recipient
  'AB-': ['A-', 'B-', 'AB-', 'O-'],
  'O+':  ['O+', 'O-'],
  'O-':  ['O-'], // universal donor — should be prioritized carefully
};

/** All valid blood groups */
const VALID_BLOOD_GROUPS = Object.keys(BLOOD_COMPATIBILITY);

// ─── Request Status Enum ──────────────────────────────────────────────────
const REQUEST_STATUS = {
  OPEN:      'open',
  MATCHED:   'matched',
  FULFILLED: 'fulfilled',
  EXPIRED:   'expired',
  CANCELLED: 'cancelled',
};

// ─── Notification Status Enum ─────────────────────────────────────────────
const NOTIFICATION_STATUS = {
  SENT:     'sent',
  ACCEPTED: 'accepted',
  DECLINED: 'declined',
  EXPIRED:  'expired',
};

// ─── Urgency Levels ───────────────────────────────────────────────────────
const URGENCY = {
  CRITICAL: 'critical',
  URGENT:   'urgent',
  NORMAL:   'normal',
};

module.exports = {
  DEFAULT_RADIUS_KM,
  EXPANDED_RADIUS_KM,
  MAX_DONORS_TO_NOTIFY,
  DONOR_COOLDOWN_DAYS,
  DONOR_COOLDOWN_MS,
  REQUEST_EXPIRY_HOURS,
  REQUEST_EXPIRY_MS,
  DONOR_ALERT_COOLDOWN_MIN,
  SMS_FALLBACK_THRESHOLD_MIN,
  MAX_ALERTS_PER_DONOR_PER_DAY,
  BLOOD_COMPATIBILITY,
  VALID_BLOOD_GROUPS,
  REQUEST_STATUS,
  NOTIFICATION_STATUS,
  URGENCY,
};
