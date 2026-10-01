import 'dart:async';

import 'package:flutter/material.dart';
import '../services/backend.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'identity_disc.dart';

/// Top-of-screen "new message" banner — the in-app stand-in for a push
/// notification while the app is open. Slides down (220ms ease-out), leaves
/// faster than it came (160ms), dismisses itself after [_visibleFor], and a
/// flick upward dismisses it immediately. Tapping opens the conversation.
class MessageBanner {
  MessageBanner._();

  static OverlayEntry? _current;
  static const _visibleFor = Duration(seconds: 4);

  static void show(
    BuildContext context, {
    required String name,
    required String text,
    required VoidCallback onOpen,
  }) {
    _current?.remove();
    _current = null;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    HapticFeedback.lightImpact();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Banner(
        name: name,
        text: text,
        onOpen: onOpen,
        onGone: () {
          if (identical(_current, entry)) _current = null;
          entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _Banner extends StatefulWidget {
  final String name;
  final String text;
  final VoidCallback onOpen;
  final VoidCallback onGone;

  const _Banner({required this.name, required this.text, required this.onOpen, required this.onGone});

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 160),
  );
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(MessageBanner._visibleFor, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    await _c.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  String get _initials {
    final t = widget.name.trim();
    if (t.isEmpty) return '?';
    return initialsOf(t);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AnimatedBuilder(
              animation: curve,
              builder: (context, child) => Opacity(
                opacity: curve.value,
                child: Transform.translate(offset: Offset(0, reduce ? 0 : -24 * (1 - curve.value)), child: child),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: GestureDetector(
                  onTap: () {
                    _dismiss();
                    widget.onOpen();
                  },
                  onVerticalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) < -100) _dismiss();
                  },
                  child: Material(
                    color: Colors.white,
                    elevation: 0,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.warmBorder),
                        boxShadow: const [BoxShadow(color: AppColors.shadowHero, blurRadius: 24, offset: Offset(0, 8))],
                      ),
                      child: Row(
                        children: [
                          IdentityDisc(initials: _initials, size: 38),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                                const SizedBox(height: 1),
                                Text(widget.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.3)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Reply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandRed)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
