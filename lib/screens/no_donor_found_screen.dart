import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/ring_field.dart';
import 'cancel_confirm_screen.dart';

/// Terminal-failure composition per Visual Richness Proposal #12: dashed
/// rings say the search reached its edge, empty avatar dots are the real
/// people it found, cream (not red) because this is a wait, not an
/// emergency. Blood group shown at centre comes from the real request doc.
class NoDonorFoundScreen extends StatefulWidget {
  final String requestId;
  final bool wasEscalated;

  const NoDonorFoundScreen({super.key, required this.requestId, this.wasEscalated = false});

  @override
  State<NoDonorFoundScreen> createState() => _NoDonorFoundScreenState();
}

class _NoDonorFoundScreenState extends State<NoDonorFoundScreen> {
  bool _cancelling = false;

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Cancel this request?',
      message: 'Donors will stop seeing it. Keep waiting instead if you still need blood — someone may become available.',
      confirmLabel: 'Cancel request',
    );
    if (!confirmed || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await Backend.instance.cancelRequest(widget.requestId);
    } catch (_) {
      // Already terminal (e.g. expired) server-side — fine either way.
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CancelConfirmScreen(requestId: widget.requestId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('requests').doc(widget.requestId).get(),
          builder: (context, snapshot) {
            final bloodGroup = snapshot.data?.data()?['blood_group'] as String? ?? '';

            return Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final px = constraints.maxWidth / 390;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: RingField(scale: 0.9, referenceWidth: 390, color: const Color(0xFFE0D5C4), outerOpacity: 1, middleOpacity: 1, innerOpacity: 0, innerDashed: true),
                          ),
                          Positioned(left: constraints.maxWidth * 0.5 - 96 * px, top: 40 * px, child: _emptyDot(30 * px, 0.6)),
                          Positioned(left: constraints.maxWidth * 0.5 + 66 * px, top: 28 * px, child: _emptyDot(26 * px, 0.5)),
                          Positioned(left: constraints.maxWidth * 0.5 - 76 * px, bottom: 30 * px, child: _emptyDot(22 * px, 0.4)),
                          if (bloodGroup.isNotEmpty)
                            BloodGroupDroplet(label: bloodGroup, size: 48, filled: true, color: AppColors.primaryLightTint, textColor: AppColors.primary, fontSize: 15, serif: true),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Still searching', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.warmAmberText)),
                      const SizedBox(height: 10),
                      Text(
                        'No donor within 15 km yet',
                        style: AppTextStyles.display(fontSize: 26, color: AppColors.textPrimaryWarm, height: 1.18),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.wasEscalated
                            ? "We've alerted every compatible donor in range. This critical request is now with our admin team for a manual broadcast."
                            : "We've alerted every compatible donor in range. Keep the request open and we'll notify you the moment one becomes available.",
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.55),
                      ),
                      const SizedBox(height: 20),
                      Container(height: 1, color: AppColors.dividerWarm),
                      const SizedBox(height: 16),
                      const Text(
                        "The request stays open for 6 hours. You'll be notified the moment someone accepts — you don't need to keep this screen open.",
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
                  child: Column(
                    children: [
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _goHome, child: const Text('Keep waiting'))),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _cancelling ? null : _cancel,
                        child: Text(_cancelling ? 'Cancelling…' : 'Cancel this request', style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyDot(double size, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(width: size, height: size, decoration: const BoxDecoration(color: AppColors.dividerWarm, shape: BoxShape.circle)),
    );
  }
}
