/**
 * FCM (Firebase Cloud Messaging) helper utilities.
 *
 * Wraps firebase-admin messaging to send push notifications
 * to individual donors and requesters.
 */

const admin = require('firebase-admin');
const { logger } = require('firebase-functions');

/**
 * Sends a FCM push notification to a single device token.
 *
 * @param {string} fcmToken  The device FCM registration token
 * @param {Object} notification  { title, body }
 * @param {Object} data  Key-value string pairs for the notification payload
 * @returns {Promise<string>} Message ID if successful
 */
async function sendPushToToken(fcmToken, notification, data = {}) {
  if (!fcmToken) {
    logger.warn('sendPushToToken: No FCM token provided, skipping.');
    return null;
  }

  // Convert all data values to strings (FCM requirement)
  const stringData = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v)])
  );

  const message = {
    token: fcmToken,
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: stringData,
    android: {
      priority: 'high',
      notification: {
        sound: 'blood_alert', // custom sound file in Flutter assets
        channelId: 'blood_requests',
        priority: 'max',
        visibility: 'public',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'blood_alert.wav',
          badge: 1,
          contentAvailable: true,
        },
      },
    },
  };

  try {
    const messageId = await admin.messaging().send(message);
    logger.info(`FCM sent to token ${fcmToken.substring(0, 20)}... | messageId: ${messageId}`);
    return messageId;
  } catch (error) {
    logger.error(`FCM send failed for token ${fcmToken.substring(0, 20)}...`, error.message);
    // Don't throw — a failed notification shouldn't abort the whole function
    return null;
  }
}

/**
 * Sends FCM push notifications to multiple tokens in a batch.
 * Uses sendEachForMulticast for per-token error handling.
 *
 * @param {string[]} fcmTokens  Array of device tokens
 * @param {Object} notification  { title, body }
 * @param {Object} data  Key-value data payload
 * @returns {Promise<{successCount: number, failureCount: number}>}
 */
async function sendPushToMultiple(fcmTokens, notification, data = {}) {
  const validTokens = fcmTokens.filter(Boolean);
  if (validTokens.length === 0) {
    logger.warn('sendPushToMultiple: No valid FCM tokens, skipping.');
    return { successCount: 0, failureCount: 0 };
  }

  const stringData = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v)])
  );

  const message = {
    tokens: validTokens,
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: stringData,
    android: {
      priority: 'high',
      notification: {
        sound: 'blood_alert',
        channelId: 'blood_requests',
        priority: 'max',
        visibility: 'public',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'blood_alert.wav',
          badge: 1,
          contentAvailable: true,
        },
      },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    logger.info(`FCM multicast: ${response.successCount} sent, ${response.failureCount} failed out of ${validTokens.length}`);

    // Log failed tokens for debugging
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        logger.warn(`FCM failed for token[${idx}]: ${resp.error?.message}`);
      }
    });

    return {
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    logger.error('FCM multicast failed:', error.message);
    return { successCount: 0, failureCount: validTokens.length };
  }
}

// ─── Notification Templates ──────────────────────────────────────────────

/**
 * Returns FCM payload for a new blood request alert sent to donors.
 * @param {string} bloodGroup
 * @param {string} urgency
 * @param {number} distanceKm
 * @param {string} requestId
 */
function buildDonorRequestAlert(bloodGroup, urgency, distanceKm, requestId) {
  const urgencyEmoji = urgency === 'critical' ? '🚨' : urgency === 'urgent' ? '⚡' : '🩸';
  return {
    notification: {
      title: `${urgencyEmoji} Blood Needed: ${bloodGroup}`,
      body: `Someone needs ${bloodGroup} blood ${distanceKm.toFixed(1)} km away. Tap to respond.`,
    },
    data: {
      type: 'BLOOD_REQUEST',
      requestId,
      bloodGroup,
      urgency,
    },
  };
}

/**
 * Returns FCM payload to notify a requester that a donor has been matched.
 * @param {string} donorName
 * @param {string} requestId
 */
function buildRequesterMatchAlert(donorName, requestId) {
  return {
    notification: {
      title: '✅ Donor Found!',
      body: `${donorName} has accepted your blood request and is on the way.`,
    },
    data: {
      type: 'DONOR_MATCHED',
      requestId,
    },
  };
}

/**
 * Returns FCM payload to notify other donors that a request was fulfilled.
 * @param {string} requestId
 */
function buildRequestFilledAlert(requestId) {
  return {
    notification: {
      title: '🙏 Request Fulfilled',
      body: 'Another donor has already responded. Thank you for your willingness to help!',
    },
    data: {
      type: 'REQUEST_FULFILLED',
      requestId,
    },
  };
}

/**
 * Returns FCM payload to notify a donor they are eligible to donate again.
 */
function buildReactivationAlert() {
  return {
    notification: {
      title: '💪 You\'re Eligible to Donate Again!',
      body: 'It\'s been 90 days since your last donation. Tap to reactivate your donor status.',
    },
    data: {
      type: 'DONOR_REACTIVATION',
    },
  };
}

module.exports = {
  sendPushToToken,
  sendPushToMultiple,
  buildDonorRequestAlert,
  buildRequesterMatchAlert,
  buildRequestFilledAlert,
  buildReactivationAlert,
};
