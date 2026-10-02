import 'package:flutter/material.dart';

import '../services/backend.dart' as backend show initialsOf;

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'brand_glyph.dart';
import 'pressable.dart';
import 'rb_icon.dart';

/// The handful of building blocks every tab root and flow screen shares, so
/// Requests, Community, Find, My Page, Settings and the rest read as one
/// product: one card surface, one section label, one tab bar, one chip, one
/// list row. Screen-specific layouts compose these rather than restyling a
/// Container each time.

/// Page gutter used by every scrolling body.
const EdgeInsets kRbPagePadding = EdgeInsets.fromLTRB(20, 16, 20, 28);

/// Raised content card: white, radius 20, hairline border, soft warm shadow.
class RbCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final bool clip;

  const RbCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color = Colors.white, this.clip = false});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warmBorder.withValues(alpha: 0.7)),
        boxShadow: const [BoxShadow(color: AppColors.shadowCard, blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}

/// Sentence-case section heading with an optional trailing action/count.
class RbSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const RbSectionLabel(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(2, 22, 2, 10)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink2))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Underline tabs under a tab-root header (Requests, Community).
class RbTabBar extends StatelessWidget {
  /// (label, count) — a count of 0 shows no badge.
  final List<(String, int)> tabs;
  final int selected;
  final ValueChanged<int> onChanged;

  /// The full-width hairline under the tabs; the active indicator stays either way.
  final bool showDivider;

  const RbTabBar({super.key, required this.tabs, required this.selected, required this.onChanged, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    // One control: equal-width tabs on a shared baseline, the active one
    // marked by an indicator sitting exactly on the divider.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.warmGround, border: showDivider ? const Border(bottom: BorderSide(color: AppColors.warmBorder)) : null),
      child: Row(
        children: [for (var i = 0; i < tabs.length; i++) Expanded(child: _tab(i))],
      ),
    );
  }

  Widget _tab(int i) {
    final active = i == selected;
    final (label, count) = tabs[i];
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(i),
        child: SizedBox(
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, height: 1.2, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? AppColors.ink : AppColors.ink2),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: active ? AppColors.red100 : AppColors.warmDivider, borderRadius: BorderRadius.circular(999)),
                      child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? AppColors.red700 : AppColors.ink2)),
                    ),
                  ],
                ],
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: active ? AppColors.brandRed : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum RbTone { red, gold, success, neutral, orange }

/// Small status pill: "Verified", "Urgent", "2 km away".
class RbChip extends StatelessWidget {
  final String text;
  final RbGlyph? icon;
  final Widget? leading;
  final RbTone tone;

  const RbChip(this.text, {super.key, this.icon, this.leading, this.tone = RbTone.neutral});

  static (Color, Color) colors(RbTone tone) => switch (tone) {
        RbTone.red => (AppColors.red100, AppColors.red700),
        RbTone.gold => (AppColors.goldTint, AppColors.goldDeep),
        RbTone.success => (AppColors.successBg, AppColors.successText),
        RbTone.orange => (AppColors.orangeTint, AppColors.orangeDeep),
        RbTone.neutral => (AppColors.sand, AppColors.ink2),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)] else if (icon != null) ...[RbIcon(icon!, size: 13, color: fg), const SizedBox(width: 5)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg))),
        ],
      ),
    );
  }
}

/// A bordered group of [RbRow]s with dividers between them.
class RbListGroup extends StatelessWidget {
  final List<Widget> children;
  const RbListGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.warmBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, indent: 58, color: AppColors.warmDivider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One settings/menu row: tinted icon tile, title, optional subtitle, and a
/// trailing chevron, switch or value.
class RbRow extends StatelessWidget {
  final RbGlyph icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final RbTone tone;

  /// Menu-style row: the glyph stands on its own (no tinted tile), so a
  /// list of plain destinations doesn't read as a stack of icon boxes.
  final bool bare;

  const RbRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.tone = RbTone.red,
    this.bare = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = RbChip.colors(destructive ? RbTone.red : tone);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        child: Row(
          children: [
            if (bare)
              SizedBox(width: 32, child: Center(child: RbIcon(icon, size: 21, color: destructive ? AppColors.red700 : AppColors.brandRed)))
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: RbIcon(icon, size: 16, color: fg),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: destructive ? AppColors.red700 : AppColors.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.35)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ?? (onTap == null ? const SizedBox.shrink() : const RbIcon(RbGlyph.chevron, size: 16, color: AppColors.chevronMuted)),
          ],
        ),
      ),
    );
  }
}

/// Brand-styled switch used in every settings/availability toggle.
class RbSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const RbSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) => Switch(
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.brandRed,
        inactiveThumbColor: AppColors.mutedInk,
        inactiveTrackColor: AppColors.warmBorder,
        onChanged: onChanged,
      );
}

/// Empty / error / info panel inside a scrolling list: droplet glyph,
/// serif title, explanation, optional action.
class RbStatePanel extends StatelessWidget {
  final RbGlyph icon;
  final String title;
  final String message;
  final GlyphTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  const RbStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = GlyphTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  factory RbStatePanel.error({required String title, required String message, required VoidCallback onRetry}) => RbStatePanel(
        icon: RbGlyph.offline,
        title: title,
        message: message,
        tone: GlyphTone.red,
        actionLabel: 'Try again',
        onAction: onRetry,
      );

  @override
  Widget build(BuildContext context) {
    return RbCard(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      child: Column(
        children: [
          BrandGlyph(icon: icon, tone: tone, size: 50),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 19, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.45)),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                side: const BorderSide(color: AppColors.red300),
                foregroundColor: AppColors.brandRed,
              ),
              onPressed: onAction,
              icon: const RbIcon(RbGlyph.retry, size: 15),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Centred progress for a section that is still loading.
class RbLoading extends StatelessWidget {
  final double height;
  const RbLoading({super.key, this.height = 160});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandRed))),
      );
}

/// Round avatar: network photo when there is one, initials otherwise.
class RbAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  final bool gold;

  const RbAvatar({super.key, required this.name, this.photoUrl, this.size = 44, this.gold = false});

  /// Punctuation-safe initials — the shared helper in backend.dart.
  static String initialsOf(String name) => backend.initialsOf(name);

  @override
  Widget build(BuildContext context) {
    final initials = Container(
      color: gold ? AppColors.goldTint : AppColors.red100,
      alignment: Alignment.center,
      child: Text(initialsOf(name), style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w600, color: gold ? AppColors.goldDeep : AppColors.brandRed)),
    );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photoUrl == null
            ? initials
            : Image.network(photoUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => initials),
      ),
    );
  }
}
