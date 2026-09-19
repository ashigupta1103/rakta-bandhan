import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/state_card.dart';
import 'create_experience_screen.dart';
import 'notifications_screen.dart';

/// Community tab root — Phase 5, frontend-only per the final artifact's
/// "Community — the flagship" section. Stories/comments/likes/leaderboard
/// all need a public-handle data model that does not exist yet (see the
/// Phase-5 handle proposal, on hold), so every tab below shows an honest
/// empty state instead of inventing posts, initiatives or rankings. The one
/// real number on the Impact tab — "donations this month" — reads the
/// existing `requests` collection directly (same broad cross-donor read
/// pattern `Backend.openRequestsStream()` already uses); nothing new is
/// added to Firestore.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

enum _CommunityTab { stories, whatsNew, impact }

class _CommunityScreenState extends State<CommunityScreen> {
  _CommunityTab _tab = _CommunityTab.stories;
  late Future<int> _impactFuture;

  @override
  void initState() {
    super.initState();
    // Computed once per screen visit, not per rebuild — switching tabs back
    // and forth would otherwise re-run the Firestore read every time.
    _impactFuture = _donationsThisMonth();
  }

  Future<int> _donationsThisMonth() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    // Single equality filter only, matching the same proven-safe shape used
    // elsewhere in this codebase (no orderBy/range filter that would need a
    // composite index this project has no way to verify) — "this month" is
    // computed client-side after fetching, on a demo-scale dataset, the
    // same tradeoff already made in donation_history_service.dart.
    final snap = await FirebaseFirestore.instance.collection('requests').where('status', isEqualTo: 'fulfilled').get();
    return snap.docs.where((d) {
      final ts = d.data()['fulfilled_at'] as Timestamp?;
      return ts != null && !ts.toDate().isBefore(startOfMonth);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppHeader(
        title: 'Community',
        onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
      ),
      body: Column(
        children: [
          _tabRow(),
          Expanded(
            child: switch (_tab) {
              _CommunityTab.stories => _storiesTab(),
              _CommunityTab.whatsNew => _whatsNewTab(),
              _CommunityTab.impact => _impactTab(),
            },
          ),
        ],
      ),
    );
  }

  Widget _tabRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.warmBorder))),
      child: Row(
        children: [
          _tabButton('Stories', _CommunityTab.stories),
          const SizedBox(width: 22),
          _tabButton("What's New", _CommunityTab.whatsNew),
          const SizedBox(width: 22),
          _tabButton('Impact', _CommunityTab.impact),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _CommunityTab tab) {
    final isActive = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: Container(
        padding: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isActive ? AppColors.brandRed : Colors.transparent, width: 2))),
        child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppColors.ink : AppColors.ink2)),
      ),
    );
  }

  // ------------------------------------------------------------- Stories

  Widget _storiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateExperienceScreen())),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(color: AppColors.goldTint, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(LucideIcons.sparkles, size: 16, color: AppColors.goldDeep),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(999)),
                    child: const Text('Share what your donation meant…', style: TextStyle(fontSize: 14, color: AppColors.disabledTint)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, 6))]),
            child: Column(
              children: [
                // Echoes the real post's 4:3 story frame so the empty state
                // reads as "this is the shape a story takes", not a generic
                // dashboard tile.
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.warmBorder)),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(color: AppColors.goldTint, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.heartHandshake, size: 18, color: AppColors.goldDeep),
                        ),
                        const SizedBox(height: 10),
                        Text('Your story could go here', style: AppTextStyles.display(fontSize: 15, color: AppColors.ink2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('No stories yet', style: AppTextStyles.display(fontSize: 19, color: AppColors.ink)),
                const SizedBox(height: 8),
                const Text(
                  'Community stories will appear here once sharing goes live. Real donors, real experiences — nothing here is invented.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- What's New

  Widget _whatsNewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('FROM RAKTA BANDHAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.goldDeep)),
          const SizedBox(height: 14),
          _emptyPanel(
            icon: LucideIcons.megaphone,
            iconBg: AppColors.goldTint,
            iconColor: AppColors.goldDeep,
            title: 'No announcements yet',
            message: 'Official camps, drives and initiatives will appear here once they are announced. No dates or venues are shown until they are real.',
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Impact

  Widget _impactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<int>(
            future: _impactFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SizedBox(
                  height: 160,
                  child: Center(
                    child: StateCard.error(
                      title: "Couldn't load this month's impact",
                      message: 'Check your connection and try again.',
                      onRetry: () => setState(() => _impactFuture = _donationsThisMonth()),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)));
              }
              final count = snapshot.data!;
              if (count == 0) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.red100, width: 1.5), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(color: AppColors.red100, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(LucideIcons.droplet, size: 22, color: AppColors.brandRed),
                      ),
                      const SizedBox(height: 16),
                      Text('No donations recorded this month yet', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 18, color: AppColors.ink)),
                      const SizedBox(height: 8),
                      const Text('This figure reads real fulfilled requests only — it will show up the moment the first one lands.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.5)),
                    ],
                  ),
                );
              }
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment(-0.3, -1),
                    end: Alignment(0.3, 1),
                    colors: [AppColors.emberFieldStart, AppColors.emberFieldMid, AppColors.emberFieldEnd],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOGETHER THIS MONTH', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.gold)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$count', style: AppTextStyles.display(fontSize: 46, color: const Color(0xFFFBEDE6), height: 0.9)),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Text(count == 1 ? 'donation by\nthe community' : 'donations by\nthe community', style: const TextStyle(fontSize: 14, height: 1.25, color: Color(0xDDFBEDE6))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Figure reads from existing donation records — no new counters invented.', style: TextStyle(fontSize: 12, color: Color(0xB3FBEDE6))),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          const Text('COMMUNITY IMPACT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.ink2)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.goldTint,
              border: const Border(left: BorderSide(color: AppColors.gold, width: 3)),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.sparkles, size: 15, color: AppColors.goldDeep),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Recognition is coming. Individual rankings and Donor of the Year need a public community identity, which hasn't launched yet — nothing here is a placeholder score.",
                    style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPanel({
    required IconData icon,
    required String title,
    required String message,
    Color iconBg = AppColors.sand,
    Color iconColor = AppColors.ink2,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 19, color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.5)),
        ],
      ),
    );
  }
}
