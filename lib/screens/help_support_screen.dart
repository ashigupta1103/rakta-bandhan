import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

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
      'Signing in only needs a one-time code sent to your phone — no password, no document. The green "Verified" badge on your profile is separate: an administrator reviews your profile and marks it verified by hand. Uploading an ID proof photo (Personal information screen) is optional and just helps that review go faster — it is not scanned or checked automatically.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
                  const Text('Help & support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(LucideIcons.search, size: 15, color: AppColors.disabledTint),
                        const SizedBox(width: 9),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() {
                              _query = v;
                              _expanded = null;
                            }),
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryWarm),
                            decoration: const InputDecoration(hintText: 'Search help', hintStyle: TextStyle(color: AppColors.disabledTint), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 11)),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 15, color: AppColors.disabledTint),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _query = '';
                            }),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 20),
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
