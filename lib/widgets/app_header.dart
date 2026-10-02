import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_info.dart';
import '../screens/about_screen.dart';
import '../screens/corporate_partnerships_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/legal_reader_screen.dart';
import '../screens/testimonials_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'rb_icon.dart';

/// Shared tab-root header from the final artifact's "One header, one live
/// state strip" pattern: brand/title on the left, at most two actions
/// (notifications, More) on the right. No global status strip: a donor's
/// availability lives on My Page only. Pushed screens keep using the platform [AppBar] with a back
/// affordance — this widget is for tab roots only.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onNotificationTap;
  final bool hasUnreadNotifications;
  final VoidCallback? onMoreTap;
  /// Replaces the notifications button (the Messages inbox on Requests), so
  /// a header never carries more than two actions.
  final Widget? primaryAction;
  /// The hairline under the header. Off where a tab bar sits directly below.
  final bool showDivider;

  const AppHeader({
    super.key,
    required this.title,
    this.onNotificationTap,
    this.hasUnreadNotifications = false,
    this.onMoreTap,
    this.primaryAction,
    this.showDivider = true,
  });

  // 20px vertical padding (10+10) plus a bare IconButton's Material default
  // minimum tap target (48px) needs 68px before the 1px divider even fits --
  // 56 clips it. Caught by a widget test, not eyeballed: a bare
  // MaterialApp(theme: AppTheme.lightTheme) render of this header overflows
  // its own preferredSize by ~13px on every screen that uses it (Community,
  // Profile), because nothing in AppTheme shrinks IconButton's default
  // minimum size.
  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
            child: Row(
              children: [
                Text(title, style: AppTextStyles.display(fontSize: 22, color: AppColors.ink)),
                const Spacer(),
                primaryAction ??
                    _HeaderIconButton(
                      icon: RbGlyph.bell,
                      showDot: hasUnreadNotifications,
                      onTap: onNotificationTap ?? () {},
                    ),
                _HeaderIconButton(
                  icon: RbGlyph.more,
                  onTap: onMoreTap ?? () => showMoreSheet(context),
                ),
              ],
            ),
          ),
          Container(height: 1, color: showDivider ? AppColors.warmBorder : Colors.transparent),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final RbGlyph icon;
  final VoidCallback onTap;
  final bool showDot;

  const _HeaderIconButton({required this.icon, required this.onTap, this.showDot = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          RbIcon(icon, size: 22, color: AppColors.ink2),
          if (showDot)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.brandRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.warmGround, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The header's "More" sheet — About / Testimonials / Corporate / Help /
/// Privacy / Terms, all six wired to their real destination screens.
void showMoreSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.warmGround,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      // Bottom inset applied explicitly here (not via SafeArea) so it's
      // never silently doubled up; scroll view is the fallback for short
      // screens or larger system text scale.
      final bottomInset = MediaQuery.of(sheetContext).padding.bottom;
      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, 12 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.warmBorder, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('More', style: AppTextStyles.display(fontSize: 22, color: AppColors.ink)),
                ),
              ),
              _moreGroup(sheetContext, [
                (RbGlyph.heart, AppColors.goldTint, AppColors.goldDeep, 'About Rakta Bandhan', (ctx) => const AboutScreen()),
                (RbGlyph.quote, AppColors.red100, AppColors.brandRed, 'Testimonials', (ctx) => const TestimonialsScreen()),
                (RbGlyph.building, AppColors.orangeTint, AppColors.orangeDeep, 'Corporate partnerships', (ctx) => const CorporatePartnershipsScreen()),
              ]),
              const SizedBox(height: 10),
              _moreGroup(sheetContext, [
                (RbGlyph.info, AppColors.warmBorder, AppColors.ink2, 'Help & support', (ctx) => const HelpSupportScreen()),
                (RbGlyph.shield, AppColors.warmBorder, AppColors.ink2, 'Privacy policy', (ctx) => const LegalReaderScreen(title: 'Privacy policy')),
                (RbGlyph.page, AppColors.warmBorder, AppColors.ink2, 'Terms of use', (ctx) => const LegalReaderScreen(title: 'Terms of use')),
              ]),
              const SizedBox(height: 16),
              const Text('Rakta Bandhan · version $kAppVersion', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.disabledTint)),
              const Text('An initiative of Rotary Club of Madras Cosmos', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.disabledTint)),
            ],
          ),
        ),
      );
    },
  );
}

Widget _moreGroup(BuildContext context, List<(RbGlyph, Color, Color, String, WidgetBuilder)> rows) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.warmBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: () {
                // Deliberately not popping the sheet first: pushing the
                // destination on top of the still-open modal route means
                // back from the destination lands on the options menu
                // (not straight past it to the tab root) — the sheet's own
                // back/scrim dismissal still closes it from there.
                Navigator.push(context, MaterialPageRoute(builder: rows[i].$5));
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: i < rows.length - 1 ? const Border(bottom: BorderSide(color: AppColors.warmDivider)) : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: rows[i].$2, borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: RbIcon(rows[i].$1, size: 16, color: rows[i].$3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(rows[i].$4, style: GoogleFonts.barlow(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink))),
                    const RbIcon(RbGlyph.chevron, size: 16, color: AppColors.disabledTint),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
