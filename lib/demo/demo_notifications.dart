import '../services/notifications_service.dart';
import 'demo.dart';

/// The notification feed during a client demo, derived from the one demo
/// request the same way FirestoreNotificationsService derives the real one.
class DemoNotificationsService implements NotificationsService {
  @override
  Stream<NotificationsFeed> watchNotifications() => Demo.instance.watch(() {
        final r = Demo.instance.request;
        final donor = Demo.instance.role == DemoRole.donor;
        final status = r?['status'];
        final items = <AppNotification>[
          if (r != null && donor && status == 'open')
            const AppNotification(
              id: '${Demo.requestId}_new',
              kind: NotificationKind.request,
              title: '${Demo.bloodGroup} blood needed nearby',
              body: '${Demo.requesterName} needs 1 unit at ${Demo.hospital}.',
              time: 'just now',
              requestId: Demo.requestId,
            ),
          if (r != null && !donor && (status == 'matched' || status == 'fulfilled'))
            const AppNotification(
              id: '${Demo.requestId}_match',
              kind: NotificationKind.match,
              title: '${Demo.donorName} accepted your request',
              body: 'Message or call them in the app to arrange the donation.',
              time: 'just now',
              requestId: Demo.requestId,
            ),
          if (status == 'fulfilled')
            const AppNotification(
              id: '${Demo.requestId}_done',
              kind: NotificationKind.donationConfirmed,
              title: 'Donation completed',
              body: 'Both of you confirmed the donation. Thank you.',
              time: 'just now',
              requestId: Demo.requestId,
            ),
        ];
        return NotificationsFeed(enabled: true, items: items.reversed.toList());
      });
}
