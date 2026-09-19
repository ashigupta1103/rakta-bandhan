import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../screens/about_screen.dart';
import '../screens/corporate_partnerships_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/legal_reader_screen.dart';
import '../screens/testimonials_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'pulsing_dot.dart';

/// Shared tab-root header from the final artifact's "One header, one live
/// state strip" pattern: brand/title on the left, at most two actions
/// (notifications, More) on the right, and an optional hairline state strip
/// underneath. Pushed screens keep using the platform [AppBar] with a back
/// affordance — this widget is for tab roots only.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onNotificationTap;
  final bool hasUnreadNotifications;
  final VoidCallback? onMoreTap;
  final Widget? stateStrip;

  const AppHeader({
    super.key,
    required this.title,
    this.onNotificationTap,
    this.hasUnreadNotifications = false,
    this.onMoreTap,
    this.stateStrip,
  });

  @override
  Size get preferredSize => Size.fromHeight(stateStrip == null ? 56 : 92);

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
                _HeaderIconButton(
                  icon: LucideIcons.bell,
                  showDot: hasUnreadNotifications,
                  onTap: onNotificationTap ?? () {},
                ),
                _HeaderIconButton(
                  icon: LucideIcons.ellipsis,
                  onTap: onMoreTap ?? () => showMoreSheet(context),
                ),
              ],
            ),
          ),
          ?stateStrip,
          Container(height: 1, color: AppColors.warmBorder),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
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
          Icon(icon, size: 22, color: AppColors.ink2),
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

/// The hairline "live state strip" — availability + verification + an
/// optional trailing count — repeated under every tab-root header.
class AppStateStrip extends StatelessWidget {
  final bool isAvailable;
  final String subtitle;
  final String? trailing;

  const AppStateStrip({super.key, required this.isAvailable, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.warmDivider)),
      ),
      child: Row(
        children: [
          PulsingDot(color: isAvailable ? AppColors.successText : AppColors.mutedInk, size: 8),
          const SizedBox(width: 8),
          Text(
            isAvailable ? 'Available' : 'Not available',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isAvailable ? AppColors.successText : AppColors.mutedInk),
          ),
          Text(' · $subtitle', style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
          if (trailing != null) ...[
            const Spacer(),
            Text(trailing!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.red700)),
          ],
        ],
      ),
    );
  }
}

/// The header's "More" sheet — About / Testimonials / Corporate / Help /
/// Privacy / Terms. Phase 1 establishes the sheet and its six destinations;
/// the destination pages themselves are a later batch, so each row surfaces
/// a "coming soon" notice rather than a dead toast with no follow-through.
void showMoreSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.warmGround,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
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
                (LucideIcons.sparkles, AppColors.goldTint, AppColors.goldDeep, 'About Rakta Bandhan', (ctx) => const AboutScreen()),
                (LucideIcons.quote, AppColors.red100, AppColors.brandRed, 'Testimonials', (ctx) => const TestimonialsScreen()),
                (LucideIcons.building2, AppColors.orangeTint, AppColors.orangeDeep, 'Corporate partnerships', (ctx) => const CorporatePartnershipsScreen()),
              ]),
              const SizedBox(height: 10),
              _moreGroup(sheetContext, [
                (LucideIcons.circleHelp, AppColors.warmBorder, AppColors.ink2, 'Help & support', (ctx) => const HelpSupportScreen()),
                (LucideIcons.shield, AppColors.warmBorder, AppColors.ink2, 'Privacy policy', (ctx) => const LegalReaderScreen(title: 'Privacy policy', sections: kPrivacyPolicySections)),
                (LucideIcons.fileText, AppColors.warmBorder, AppColors.ink2, 'Terms of use', (ctx) => const LegalReaderScreen(title: 'Terms of use', sections: kTermsOfUseSections)),
              ]),
              const SizedBox(height: 16),
              const Text('Rakta Bandhan · version placeholder', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.disabledTint)),
              const Text('An initiative of Rotary Club of Madras Cosmos', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.disabledTint)),
            ],
          ),
        ),
      );
    },
  );
}

Widget _moreGroup(BuildContext context, List<(IconData, Color, Color, String, WidgetBuilder)> rows) {
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
                Navigator.pop(context);
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
                      child: Icon(rows[i].$1, size: 16, color: rows[i].$3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(rows[i].$4, style: GoogleFonts.barlow(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink))),
                    const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.disabledTint),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
