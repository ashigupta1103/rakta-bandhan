import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/call_screen.dart';
import '../screens/chat_screen.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';

/// The matched pair's ways to reach each other, in order of preference:
/// an in-app voice call (no numbers exchanged), an in-app message, and —
/// deliberately small — the phone number as a fallback for when the other
/// person doesn't have the app open (in-app calls only ring while it is,
/// until push is enabled on the Blaze plan). Sits on the ember field.
class ContactActions extends StatelessWidget {
  final String requestId;
  final String peerUid;
  final String peerName;
  final String peerPhone;

  const ContactActions({
    super.key,
    required this.requestId,
    required this.peerUid,
    required this.peerName,
    required this.peerPhone,
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
      peerPhone: peerPhone,
    );
  }

  Future<void> _dial(BuildContext context) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: peerPhone));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open the dialer. Their number is $peerPhone.')));
    }
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
          icon: const Icon(LucideIcons.phone, size: 16),
          label: Text('Call $first in the app', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.onEmber, side: const BorderSide(color: AppColors.onEmberOutline)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: requestId))),
          icon: const Icon(LucideIcons.messageSquare, size: 15),
          label: const Text('Message'),
        ),
        if (peerPhone.isNotEmpty) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _dial(context),
            child: Text(
              'Or call from your phone · $peerPhone',
              style: const TextStyle(fontSize: 12.5, color: AppColors.onEmberFaint, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ],
    );
  }
}
