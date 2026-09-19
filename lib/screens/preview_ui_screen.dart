import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/dashed_border.dart';
import '../widgets/identity_disc.dart';
import '../widgets/impact_trail.dart';
import '../widgets/status_badge.dart';
import 'notifications_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// TEMPORARY PREVIEW UI — NOT PART OF THE REAL APP.
//
// Every value on every screen in this file is static sample content,
// clearly labelled "(sample)"/"Preview". Nothing here reads from or writes
// to Firebase Authentication or Firestore — this file makes zero Backend/
// FirebaseAuth/FirebaseFirestore calls at all. It exists only so the app's
// visual design can be screenshotted without depending on a working
// registration flow. Delete this file (and its one entry-point link in
// login_screen.dart) once it's no longer needed.
// ═══════════════════════════════════════════════════════════════════════

class PreviewUiScreen extends StatefulWidget {
  const PreviewUiScreen({super.key});

  @override
  State<PreviewUiScreen> createState() => _PreviewUiScreenState();
}

class _PreviewUiScreenState extends State<PreviewUiScreen> {
  int _tab = 0;

  static const _tabs = [
    (icon: LucideIcons.droplet, label: 'Request'),
    (icon: LucideIcons.radar, label: 'Find'),
    (icon: LucideIcons.heartHandshake, label: 'Community'),
    (icon: LucideIcons.user, label: 'My Page'),
  ];

  void _previewOnly(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — preview only, not wired to any backend.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _previewBanner(),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _PreviewRequestTab(onAction: _previewOnly),
                  _PreviewFindTab(onAction: _previewOnly),
                  _PreviewCommunityTab(onAction: _previewOnly),
                  _PreviewMyPageTab(onAction: _previewOnly),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _previewBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(LucideIcons.eye, size: 13, color: Colors.white),
          const SizedBox(width: 7),
          const Expanded(
            child: Text(
              'PREVIEW MODE — sample data only, no backend connection',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text('Exit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  Widget _bottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.warmBorder)),
        boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [for (var i = 0; i < _tabs.length; i++) Expanded(child: _tabButton(i))],
        ),
      ),
    );
  }

  Widget _tabButton(int index) {
    final isActive = _tab == index;
    final tab = _tabs[index];
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(color: isActive ? AppColors.red100 : Colors.transparent, borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 3,
              width: 20,
              child: isActive ? DecoratedBox(decoration: BoxDecoration(color: AppColors.brandRed, borderRadius: BorderRadius.circular(999))) : null,
            ),
            const SizedBox(height: 3),
            Icon(tab.icon, size: 22, color: isActive ? AppColors.brandRed : AppColors.ink2),
            const SizedBox(height: 3),
            Text(tab.label, style: TextStyle(fontSize: 10.5, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppColors.brandRed : AppColors.ink2)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Request tab

class _PreviewRequestTab extends StatelessWidget {
  final void Function(String) onAction;
  const _PreviewRequestTab({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(title: 'Requests', onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.shadowHero, blurRadius: 22, offset: const Offset(0, 8))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 4, color: AppColors.brandRed),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const BloodGroupDroplet(label: 'AB+', size: 50, filled: true, color: AppColors.brandRed, textColor: AppColors.whiteTextOnPrimary, fontSize: 17, serif: true),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('CRITICAL', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: AppColors.red700)),
                                    const SizedBox(height: 3),
                                    Text('Apollo Hospital (sample)', style: AppTextStyles.display(fontSize: 19, color: AppColors.ink)),
                                    const SizedBox(height: 3),
                                    const Text('2 units · sample data', style: TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton(onPressed: () => onAction('Accept & help'), child: const Text('Accept & help')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const BloodGroupDroplet(label: 'O+', size: 38, filled: true, color: AppColors.sand, textColor: AppColors.ink2, fontSize: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [StatusBadge.pill('urgent'), const SizedBox(width: 7), const Text('4.2 km · sample', style: TextStyle(fontSize: 12, color: AppColors.ink2))]),
                          const SizedBox(height: 4),
                          Text('Lilavati Hospital (sample)', style: AppTextStyles.display(fontSize: 16.5, color: AppColors.ink)),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.disabledTint),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => onAction('Need blood yourself?'),
                child: CustomPaint(
                  painter: DashedRRectPainter(color: AppColors.warmBorder, radius: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    child: Row(
                      children: [
                        Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppColors.red100, shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(LucideIcons.plus, size: 17, color: AppColors.brandRed)),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Need blood yourself?', style: AppTextStyles.display(fontSize: 16.5, color: AppColors.ink)),
                              const Text('Alert nearby compatible donors', style: TextStyle(fontSize: 12, color: AppColors.ink2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- Find tab

class _PreviewFindTab extends StatelessWidget {
  final void Function(String) onAction;
  const _PreviewFindTab({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(title: 'Find', onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(15)),
            child: const Row(children: [Icon(LucideIcons.search, size: 16, color: AppColors.textSecondary), SizedBox(width: 10), Text('Search location (preview)', style: TextStyle(fontSize: 14, color: AppColors.disabledTint))]),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const Text('Nearby donors', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
              const SizedBox(height: 12),
              for (final donor in const [('Sample Donor A', 'O+', '2.4 km (sample)'), ('Sample Donor B', 'A+', '3.8 km (sample)')]) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorderWarm)),
                  child: Row(
                    children: [
                      IdentityDisc(initials: donor.$1.substring(0, 2).toUpperCase(), size: 44, isPublic: false, bloodGroup: donor.$2),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(donor.$1, style: AppTextStyles.display(fontSize: 15, color: AppColors.ink)),
                            const SizedBox(height: 3),
                            Text(donor.$3, style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
                          ],
                        ),
                      ),
                      OutlinedButton(onPressed: () => onAction('Request'), child: const Text('Request')),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- Community tab

class _PreviewCommunityTab extends StatefulWidget {
  final void Function(String) onAction;
  const _PreviewCommunityTab({required this.onAction});

  @override
  State<_PreviewCommunityTab> createState() => _PreviewCommunityTabState();
}

class _PreviewCommunityTabState extends State<_PreviewCommunityTab> {
  int _sub = 0;
  static const _subTabs = ['Stories', "What's New", 'Impact'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(title: 'Community', onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.warmBorder))),
          child: Row(
            children: [
              for (var i = 0; i < _subTabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 22),
                GestureDetector(
                  onTap: () => setState(() => _sub = i),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 9),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _sub == i ? AppColors.brandRed : Colors.transparent, width: 2))),
                    child: Text(_subTabs[i], style: TextStyle(fontSize: 14.5, fontWeight: _sub == i ? FontWeight.w600 : FontWeight.w400, color: _sub == i ? AppColors.ink : AppColors.ink2)),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: _sub == 0
                ? _storiesSample(widget.onAction)
                : _sub == 1
                    ? _whatsNewSample()
                    : _impactSample(),
          ),
        ),
      ],
    );
  }

  Widget _storiesSample(void Function(String) onAction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => onAction('Share an experience'),
          child: Row(
            children: [
              Container(width: 38, height: 38, decoration: const BoxDecoration(color: AppColors.goldTint, shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(LucideIcons.sparkles, size: 16, color: AppColors.goldDeep)),
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
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, 6))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IdentityDisc(initials: 'W', size: 42, isPublic: true, bloodGroup: 'O+'),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Warrior (sample)', style: AppTextStyles.display(fontSize: 17, color: AppColors.ink)),
                        const Text('Sample story · 2h ago', style: TextStyle(fontSize: 12, color: AppColors.ink2)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Today was my first blood donation. Sample story text for preview only.', style: AppTextStyles.display(fontSize: 16, color: AppColors.ink, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _whatsNewSample() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(
        children: [
          Container(width: 52, height: 52, decoration: const BoxDecoration(color: AppColors.goldTint, shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(LucideIcons.megaphone, size: 22, color: AppColors.goldDeep)),
          const SizedBox(height: 16),
          Text('Sample announcement', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 18, color: AppColors.ink)),
          const SizedBox(height: 8),
          const Text('Preview only — official initiatives appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.ink2)),
        ],
      ),
    );
  }

  Widget _impactSample() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment(-0.3, -1), end: Alignment(0.3, 1), colors: [AppColors.emberFieldStart, AppColors.emberFieldMid, AppColors.emberFieldEnd]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOGETHER THIS MONTH', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.gold)),
          const SizedBox(height: 10),
          Text('12', style: AppTextStyles.display(fontSize: 46, color: const Color(0xFFFBEDE6), height: 0.9)),
          const SizedBox(height: 8),
          const Text('donations by the community (sample number)', style: TextStyle(fontSize: 13, color: Color(0xDDFBEDE6))),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- My Page tab

class _PreviewMyPageTab extends StatefulWidget {
  final void Function(String) onAction;
  const _PreviewMyPageTab({required this.onAction});

  @override
  State<_PreviewMyPageTab> createState() => _PreviewMyPageTabState();
}

class _PreviewMyPageTabState extends State<_PreviewMyPageTab> {
  bool _available = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(title: 'My page', onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IdentityDisc(initials: 'PD', size: 78, isPublic: false, bloodGroup: 'AB+'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Preview Donor', style: AppTextStyles.display(fontSize: 26, color: AppColors.textPrimaryWarm)),
                          const SizedBox(height: 8),
                          const Text('Sample profile — not a real account', style: TextStyle(fontSize: 12, color: AppColors.disabledTint)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: const Offset(0, 3))]),
                child: Row(
                  children: [
                    Expanded(child: Text(_available ? 'Available to donate' : 'Not available', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm))),
                    Switch(value: _available, activeThumbColor: AppColors.primary, onChanged: (v) => setState(() => _available = v)),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Text('YOUR IMPACT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.3, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              const ImpactTrail(count: 3, caption: '3 donations (sample) · 3 lives helped'),
              const SizedBox(height: 20),
              Container(height: 1, color: AppColors.dividerWarm),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: const Offset(0, 3))]),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final row in const ['Personal information', 'Donation history', 'Emergency contact', 'Settings'])
                      InkWell(
                        onTap: () => widget.onAction(row),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(border: row != 'Settings' ? const Border(bottom: BorderSide(color: AppColors.dividerWarm)) : null),
                          child: Row(children: [Expanded(child: Text(row, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm))), const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.chevronMuted)]),
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => widget.onAction('Log out'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                  child: Row(children: [Icon(LucideIcons.logOut, color: AppColors.textMuted, size: 17), SizedBox(width: 10), Text('Log out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted))]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
