import 'package:flutter/material.dart';

import '../services/backend.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/brand_glyph.dart';
import '../widgets/identity_disc.dart';
import '../widgets/pressable.dart';
import '../widgets/state_card.dart';
import 'call_screen.dart';
import 'chat_screen.dart';
import 'create_request_screen.dart';
import 'main_navigation_screen.dart';
import 'tracking_screen.dart';
import '../widgets/rb_icon.dart';

/// Messages inbox — every person this user has been matched with, newest
/// activity first. One row = one request: who, what it's about, the last
/// line said, when, and whether it's unread. Live conversations get a call
/// button right on the row, so "call the donor" is one tap from here.
///
/// Reached from the chat icon on the Request tab (badged with the unread
/// count) and from the in-app message banner.
class ConversationsScreen extends StatelessWidget {
  /// Overrides for tests only — production reads the real services.
  final Stream<List<Conversation>>? conversations;
  final Stream<MyRequestState>? requestState;
  final String? myUidOverride;

  const ConversationsScreen({super.key, this.conversations, this.requestState, this.myUidOverride});

  @override
  Widget build(BuildContext context) {
    final myUid = myUidOverride ?? Backend.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const RbIcon(RbGlyph.back, color: AppColors.ink),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text('Messages', style: AppTextStyles.display(fontSize: 22, color: AppColors.ink)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Your conversations about donations', style: TextStyle(fontSize: 13.5, color: AppColors.ink2)),
            ),
            Expanded(
              child: StreamBuilder<List<Conversation>>(
                stream: conversations ?? ChatService.instance.watchConversations(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: StateCard.error(title: 'Couldn’t load your messages', message: 'Check your connection and try again.'));
                  }
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  final all = snap.data!;
                  if (all.isEmpty) {
                    return _EmptyMessages(requestState: requestState);
                  }
                  final active = all.where((c) => c.isOpen).toList();
                  final past = all.where((c) => !c.isOpen).toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      if (active.isNotEmpty) ...[
                        const _SectionLabel('Active'),
                        for (final c in active) _ConversationRow(c: c, myUid: myUid),
                      ],
                      if (past.isNotEmpty) ...[
                        const _SectionLabel('Earlier'),
                        for (final c in past) _ConversationRow(c: c, myUid: myUid),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the empty state needs to know about the user's own requests.
/// [openIds] are requests still waiting for a donor; [hasAny] is any
/// request at all (past ones included).
typedef MyRequestState = ({List<String> openIds, bool hasAny});

/// Read-only: reuses [Backend.myRequestsStream] (the requester's own
/// requests — nothing about anyone else).
Stream<MyRequestState> _myRequestState() => Backend.instance.myRequestsStream().map((q) {
      final open = q.docs.where((d) => d.data()['status'] == 'open').map((d) => d.id).toList();
      return (openIds: open, hasAny: q.docs.isNotEmpty);
    });

/// No conversations: explain what Messages is for and offer the next step
/// that fits the user's real state. Messaging only opens once a donor and
/// requester are matched (backend rules). If the lookup fails, falls back to
/// the generic state.
class _EmptyMessages extends StatelessWidget {
  final Stream<MyRequestState>? requestState;
  const _EmptyMessages({this.requestState});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MyRequestState>(
      stream: requestState ?? _myRequestState(),
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final s = snap.data; // null on error -> generic
        final openIds = s?.openIds ?? const <String>[];
        final active = openIds.isNotEmpty;
        final many = openIds.length > 1;
        final title = active ? (many ? 'Your requests are active' : 'Your request is active') : (s?.hasAny ?? false) ? 'No conversations yet' : 'No conversations yet';
        final body = active
            ? 'Your conversation will appear here when a donor responds. Phone numbers stay private.'
            : (s?.hasAny ?? false)
                ? 'Once a request is accepted or someone responds, your conversation will appear here.'
                : 'Your conversations with donors and requesters will appear here. Phone numbers stay private.';
        return Align(
          alignment: const Alignment(0, -0.35),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandGlyph(icon: RbGlyph.message, size: 52),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 22, color: AppColors.ink)),
                const SizedBox(height: 8),
                Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.ink2)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    // One open request -> its tracking screen; several -> the
                    // Request tab, where the user picks one.
                    onPressed: () => many
                        ? Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                            (_) => false,
                          )
                        : Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => active ? TrackingScreen(requestId: openIds.first) : const CreateRequestScreen()),
                          ),
                    child: Text(many ? 'View my requests' : active ? 'View my request' : 'Request blood'),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialTab: 1)),
                    (_) => false,
                  ),
                  child: const Text('Find donors'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink2)),
      );
}

class _ConversationRow extends StatelessWidget {
  final Conversation c;
  final String myUid;
  const _ConversationRow({required this.c, required this.myUid});

  String get _initials {
    final t = c.peerName.trim();
    if (t.isEmpty) return '?';
    return initialsOf(t);
  }

  String get _preview {
    if (c.lastText == null) {
      return c.isOpen ? 'Say hello and agree where to meet' : _statusLine;
    }
    final mine = c.lastSenderUid == myUid;
    return mine ? 'You: ${c.lastText}' : c.lastText!;
  }

  String get _statusLine => switch (c.status) {
        'fulfilled' => 'Donation completed',
        'cancelled' => 'Request cancelled',
        'expired' => 'Request expired',
        _ => c.closedByBlock ? 'Chat closed' : '',
      };

  static String _when(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24 && now.day == t.day) {
      final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
      return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
    }
    if (diff.inDays < 7) return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday - 1];
    return '${t.day}/${t.month}';
  }

  Future<void> _call(BuildContext context) async {
    final me = (await Backend.instance.myDonorDoc()).data();
    if (!context.mounted) return;
    await startCallFlow(
      context,
      requestId: c.requestId,
      peerUid: c.peerUid,
      peerName: c.peerName,
      myName: me?['name'] as String? ?? 'Rakta Bandhan user',
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = c.unreadFor(myUid);
    return Pressable(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: c.requestId))),
      semanticLabel: 'Conversation with ${c.peerName}${unread ? ', unread' : ''}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
        decoration: BoxDecoration(
          color: unread ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Opacity(opacity: c.isOpen ? 1 : 0.6, child: IdentityDisc(initials: _initials, size: 50, bloodGroup: c.bloodGroup)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15.5, fontWeight: unread ? FontWeight.w700 : FontWeight.w600, color: AppColors.ink),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_when(c.lastAt), style: TextStyle(fontSize: 12, color: unread ? AppColors.brandRed : AppColors.mutedInk, fontWeight: unread ? FontWeight.w600 : FontWeight.w400)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, color: unread ? AppColors.ink : AppColors.ink2, fontWeight: unread ? FontWeight.w500 : FontWeight.w400),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.brandRed, shape: BoxShape.circle)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    c.amRequester ? 'Your ${c.bloodGroup} request' : 'You’re donating ${c.bloodGroup}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
            if (c.isOpen && c.peerUid.isNotEmpty)
              IconButton(
                tooltip: 'Voice call ${c.peerName}',
                icon: const RbIcon(RbGlyph.phone, size: 19, color: AppColors.brandRed),
                onPressed: () => _call(context),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
