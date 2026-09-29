import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../screens/conversations_screen.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';

/// The way into the Messages inbox, badged with how many conversations
/// have something unread. Lives in the Request tab's app bar — the tab
/// where every match starts.
class MessagesButton extends StatelessWidget {
  const MessagesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ChatService.instance.watchUnreadCount(),
      builder: (context, snap) {
        final unread = snap.data ?? 0;
        return IconButton(
          tooltip: unread == 0 ? 'Messages' : 'Messages, $unread unread',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsScreen())),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(LucideIcons.messageSquare, size: 22, color: AppColors.ink),
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
