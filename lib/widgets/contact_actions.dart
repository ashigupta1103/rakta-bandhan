import 'package:flutter/material.dart';

import '../screens/call_screen.dart';
import '../screens/chat_screen.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import 'rb_icon.dart';

/// The matched pair's ways to reach each other: an in-app voice call and an
/// in-app message. Phone numbers are never shown or dialled — the in-app
/// call rings their phone through a push notification. Sits on the ember
/// field.
class ContactActions extends StatelessWidget {
  final String requestId;
  final String peerUid;
  final String peerName;

  const ContactActions({
    super.key,
    required this.requestId,
    required this.peerUid,
    required this.peerName,
  });

  Future<void> _call(BuildContext context) async {
    final me = (await Backend.instance.myDonorDoc()).data();
    if (!context.mounted) return;
    await startCallFlow(
      context,
      requestId: requestId,
      peerUid: peerUid,
      peerName: peerName,
      myName: me?['name'] as String? ?? 'Rakta Bandhan user',
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = peerName.trim().isEmpty ? 'them' : peerName.trim().split(RegExp(r'\s+')).first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmPageBackground, foregroundColor: AppColors.gradientEmberMid),
          onPressed: peerUid.isEmpty ? null : () => _call(context),
          icon: const RbIcon(RbGlyph.phone, size: 16),
          label: Text('Call $first in the app', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.onEmber, side: const BorderSide(color: AppColors.onEmberOutline)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: requestId))),
          icon: const RbIcon(RbGlyph.message, size: 15),
          label: const Text('Message'),
        ),
      ],
    );
  }
}
