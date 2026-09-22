import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/filter_chip_row.dart';

/// Help & support — an accordion FAQ using the same grouped-row component
/// used everywhere else in the app. Every answer below is verified against
/// backend.dart, not guessed: OTP sign-in vs. the admin-reviewed "Verified"
/// badge are genuinely separate mechanisms (see registerDonor/OTP sign-in
/// vs. adminVerifyDonor); phone visibility follows donors_public (never has
/// a phone field) vs. the one-time reveal onto a matched request doc; the
/// cooldown numbers come straight from markFulfilled/maybeReactivate; and
/// community-name editing is honestly reported as not implemented — there
/// is no such field anywhere in the data model. Support contact route and
/// hours are undecided and not invented here.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expanded = 0;
  final _searchController = TextEditingController();
  String _query = '';

  static const _faqs = [
    (
      'How does verification work?',
      'Signing in only needs a one-time code sent to your phone — no password, no document. The green "Verified" badge on your profile is separate: an administrator reviews your profile and marks it verified by hand.',
    ),
    (
      'Who can see my number?',
      'Nobody sees it just by browsing. The donor and request lists only ever show name, blood group and distance — never a phone number. Your number is shared with exactly one person: whoever you match with on a specific request (the donor you accept, or the donor who accepts your request), and only for that match.',
    ),
    (
      'Why am I in a 90-day cooldown?',
      'Marking a donation as fulfilled automatically pauses your availability for 90 days from that date. It turns back on by itself once the 90 days pass — there is nothing to request or wait on manually.',
    ),
    (
      'How do I change my community name?',
      "This isn't available yet — there is no community-name field in the app today. Your profile only stores the name, phone number and blood group you registered with, and none of those can currently be edited after registration.",
    ),
    (
      'How do I create a blood request?',
      'From the Request tab, open My requests and use "Need blood yourself?" to start a new request. It walks you through blood group, urgency and location, then posts a real request that compatible nearby donors can see and accept.',
    ),
    (
      'How do I find compatible donors?',
      'Open the Find tab to search the map for available donors near a location, filtered by blood group. Tapping a donor shows their distance and blood group — never their phone number until you’re matched on a specific request.',
    ),
    (
      'How does donor matching work?',
      'When you raise a request, it becomes visible to nearby donors with a compatible blood group who have marked themselves available. Any of them can accept it — the app does not auto-assign or guarantee a match.',
    ),
    (
      'How do I check the status of my request?',
      'Open the Request tab and find it under My requests. Each request shows its real status — open, matched, completed, cancelled or expired — and updates live as things change.',
    ),
    (
      'How do I contact support?',
      'In-app support contact is not wired up yet — an official support email, phone number and hours are pending confirmation from the Rakta Bandhan team. This FAQ page is the current source of truth on how the app behaves.',
    ),
    (
      'What do I do if something looks incorrect?',
      'If a request, donor listing or your own profile shows something that looks wrong, avoid relying on it until it’s confirmed. An official process for correcting information is pending confirmation from the Rakta Bandhan team.',
    ),
    (
      'How do I report an issue?',
      'Use "Report an issue" below. There is no backend yet to receive or track reports, so nothing is sent anywhere — the form shows you what the flow will look like once that’s wired up.',
    ),
    (
      'Is this app a substitute for emergency medical services?',
      'No. Rakta Bandhan helps connect donors and requesters faster — it is not an emergency medical service. For a medical emergency, contact local emergency services or a medical professional directly, not just this app.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<(String, String)> get _filtered {
    if (_query.isEmpty) return _faqs;
    final q = _query.toLowerCase();
    return _faqs.where((f) => f.$1.toLowerCase().contains(q) || f.$2.toLowerCase().contains(q)).toList();
  }

  void _openReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmGround,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => const _ReportIssueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 4),
                    const Text('Help & support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.warmBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() {
                            _query = v;
                            _expanded = null;
                          }),
                          style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryWarm),
                          decoration: InputDecoration(
                            hintText: 'Search help',
                            hintStyle: const TextStyle(color: AppColors.disabledTint),
                            prefixIcon: const Icon(LucideIcons.search, size: 19, color: AppColors.disabledTint),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(LucideIcons.x, size: 15, color: AppColors.disabledTint),
                                    onPressed: () => setState(() {
                                      _searchController.clear();
                                      _query = '';
                                    }),
                                  ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isCollapsed: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('COMMON QUESTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.ink2)),
                    const SizedBox(height: 10),
                    if (_filtered.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                        child: const Text('No questions match your search.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < _filtered.length; i++)
                              InkWell(
                                onTap: () => setState(() => _expanded = _expanded == i ? null : i),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(border: i < _filtered.length - 1 ? const Border(bottom: BorderSide(color: AppColors.warmDivider)) : null),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(_filtered[i].$1, style: TextStyle(fontSize: 14.5, fontWeight: _expanded == i ? FontWeight.w600 : FontWeight.w500, color: AppColors.textPrimaryWarm))),
                                          Icon(_expanded == i ? LucideIcons.minus : LucideIcons.plus, size: 15, color: AppColors.disabledTint),
                                        ],
                                      ),
                                      if (_expanded == i) ...[
                                        const SizedBox(height: 10),
                                        Text(_filtered[i].$2, style: AppTextStyles.display(fontSize: 15, height: 1.55, color: const Color(0xFF3D2523))),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(color: AppColors.goldTint, border: const Border(left: BorderSide(color: AppColors.gold, width: 3)), borderRadius: const BorderRadius.horizontal(right: Radius.circular(12))),
                      child: const Text(
                        'These answers describe what the app actually does today. Support contact route and hours are undecided and not invented here.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openReportSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.flag, size: 17, color: AppColors.textSecondary),
                            SizedBox(width: 10),
                            Expanded(child: Text('Report an issue', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm))),
                            Icon(LucideIcons.chevronRight, size: 16, color: AppColors.chevronMuted),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Honest-by-design report form: there is no backend collection or admin
/// review flow for reports yet (verified against backend.dart), so
/// submitting never claims success or writes anything anywhere — it shows
/// exactly what the flow will look like once that capability exists.
class _ReportIssueSheet extends StatefulWidget {
  const _ReportIssueSheet();

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  static const _reasons = ['Incorrect information', 'Inappropriate content', 'App problem or bug', 'Something else'];

  String? _reason;
  final _detailsController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.warmBorder, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(_submitted ? 'Thanks for the details' : 'Report an issue', style: AppTextStyles.display(fontSize: 20, color: AppColors.ink)),
              const SizedBox(height: 16),
              if (_submitted) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.goldTint, border: const Border(left: BorderSide(color: AppColors.gold, width: 3)), borderRadius: const BorderRadius.horizontal(right: Radius.circular(12))),
                  child: const Text(
                    'There’s no backend yet to receive or track reports, so nothing was actually sent anywhere. This screen is showing you what submitting will look like once that’s wired up — your details above were not saved.',
                    style: TextStyle(fontSize: 13, color: AppColors.goldDeepest, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
              ] else ...[
                const Text('REASON', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.ink2)),
                const SizedBox(height: 8),
                FilterChipRow(
                  activeBg: AppColors.primary,
                  chips: [for (final r in _reasons) FilterChipItem(label: r, active: _reason == r, onTap: () => setState(() => _reason = r))],
                ),
                const SizedBox(height: 16),
                const Text('DETAILS (OPTIONAL)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.ink2)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    controller: _detailsController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(hintText: 'What went wrong?', border: InputBorder.none, filled: false, contentPadding: EdgeInsets.all(12)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reporting has no backend yet — this won’t reach a real team until that’s built. Submitting just previews the flow.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.disabledTint, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _reason == null ? null : () => setState(() => _submitted = true),
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
