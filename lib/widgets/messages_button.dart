import 'package:flutter/material.dart';

import '../demo/demo.dart';
import '../screens/chat_screen.dart';
import '../screens/conversations_screen.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import 'rb_icon.dart';

/// The way into the Messages inbox, badged with how many conversations
/// have something unread. Lives in the Request tab's app bar — the tab
/// where every match starts.
class MessagesButton extends StatelessWidget {
  const MessagesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Demo.on ? Stream.value(0) : ChatService.instance.watchUnreadCount(),
      builder: (context, snap) {
        final unread = snap.data ?? 0;
        return IconButton(
          tooltip: unread == 0 ? 'Messages' : 'Messages, $unread unread',
          onPressed: () {
            if (Demo.on) {
              // The demo has at most one conversation: the matched request.
              if (Demo.instance.request?['status'] == 'matched') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen(requestId: Demo.requestId)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No conversations yet — they start when a donor accepts.')));
              }
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsScreen()));
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const RbIcon(RbGlyph.message, size: 22, color: AppColors.ink),
              if (unread > 0)
                Positioned(
                  right: -7,
                  top: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: AppColors.brandRed,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.warmPageBackground, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, height: 1),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
