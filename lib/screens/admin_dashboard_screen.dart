import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/admin_service.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/status_badge.dart';
import 'admin_content_tab.dart';
import 'admin_donor_detail_screen.dart';
import 'admin_hospital_form_screen.dart';
import 'admin_request_detail_screen.dart';

enum _AdminTab { dashboard, donors, requests, hospitals, inbox, content, activity }

/// Mobile-companion admin console. All data/actions route through
/// AdminService (real Firestore, gated by firestore.rules' isAdmin()).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = AdminService.instance;
  _AdminTab _tab = _AdminTab.dashboard;

  @override
  void initState() {
    super.initState();
    _service.init();
  }

  String _donorSearch = '';
  DonorVerificationStatus? _donorFilter;
  String? _requestFilter;
  String _hospitalSearch = '';
  InboxStatus? _inboxFilter;

  final _broadcastController = TextEditingController();
  String _audience = 'All donors';
  String? _broadcastError;

  @override
  void dispose() {
    _broadcastController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: AppColors.textPrimaryWarm, borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: const Icon(LucideIcons.shieldCheck, size: 13, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text('Admin console', style: AppTextStyles.display(fontSize: 19, color: AppColors.textPrimaryWarm)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.logOut, size: 18, color: AppColors.textMuted),
                    onPressed: () async {
                      await Backend.instance.signOut();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            // Rebuilt on service changes too — the Inbox chip carries the
            // untriaged count, which has to move without a tab switch.
            ListenableBuilder(
              listenable: _service,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: FilterChipRow(
                  activeBg: AppColors.textPrimaryWarm,
                  chips: [
                    for (final t in _AdminTab.values)
                      FilterChipItem(label: _tabLabel(t), active: _tab == t, onTap: () => setState(() => _tab = t)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _service,
                builder: (context, _) => switch (_tab) {
                  _AdminTab.dashboard => _buildDashboard(),
                  _AdminTab.donors => _buildDonors(),
                  _AdminTab.requests => _buildRequests(),
                  _AdminTab.hospitals => _buildHospitals(),
                  _AdminTab.inbox => _buildInbox(),
                  _AdminTab.content => const AdminContentTab(),
                  _AdminTab.activity => _buildActivity(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tabLabel(_AdminTab tab) => switch (tab) {
        _AdminTab.dashboard => 'Dashboard',
        _AdminTab.donors => 'Donors',
        _AdminTab.requests => 'Requests',
        _AdminTab.hospitals => 'Hospitals',
        _AdminTab.inbox => _inboxLabel(),
        _AdminTab.content => 'Content',
        _AdminTab.activity => 'Activity',
      };

  /// Unhandled count on the tab itself — an untriaged report shouldn't need
  /// the admin to open the tab to discover it exists.
  String _inboxLabel() {
    final open = _service.issueReports.where((r) => r.status != InboxStatus.resolved).length +
        _service.partnershipInquiries.where((p) => p.status != InboxStatus.resolved).length +
        _service.reports.where((r) => r.status != InboxStatus.resolved).length;
    return open == 0 ? 'Inbox' : 'Inbox ($open)';
  }

  // ---------------------------------------------------------------- Dashboard

  Widget _buildDashboard() {
    final donors = _service.donors;
    final requests = _service.requests;
    final pendingCount = donors.where((d) => d.status == DonorVerificationStatus.pending).length;
    final openCount = requests.where((r) => r.status == 'open').length;
    final fulfilledCount = requests.where((r) => r.status == 'fulfilled').length;
    final fulfilmentRate = requests.isEmpty ? 0 : ((fulfilledCount / requests.length) * 100).round();
    final needsAttention = requests.where((r) => r.status == 'open' && r.urgency == 'critical').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text(
          'Companion view for on-the-go staff · full analytics & bulk actions live on the desktop console',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _statCard(LucideIcons.users, AppColors.textMuted, '${donors.length}', 'Registered donors'),
            _statCard(LucideIcons.droplet, AppColors.primary, '$openCount', 'Open requests'),
            _statCard(LucideIcons.clock, AppColors.warmAmberText, '$pendingCount', 'Pending verifications'),
            _statCard(LucideIcons.checkCircle, AppColors.warmGreenText, '$fulfilmentRate%', 'Fulfilled (all-time)'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Fulfilment, last 7 days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < _service.weeklyFulfilmentRates.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: FractionallySizedBox(
                          heightFactor: _service.weeklyFulfilmentRates[i],
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: i == _service.weeklyFulfilmentRates.length - 1 ? AppColors.primary : const Color(0xFFF0E7E8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(width: 4, height: 14, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 7),
            const Text('Needs attention', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
          ],
        ),
        const SizedBox(height: 10),
        if (needsAttention.isEmpty)
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16)),
            child: const Text('Nothing needs attention right now.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          )
        else
          for (final r in needsAttention)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: AppColors.gradientMatchingStart, borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.alertTriangle, size: 15, color: Color(0xFFF0B4BA)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Critical ${r.bloodGroup} request, no donor matched', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onEmberStrong)),
                        const SizedBox(height: 3),
                        Text('${r.location} · ${r.time} — ready for manual broadcast', style: const TextStyle(fontSize: 11.5, color: Color(0xFFD9A5AA))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _statCard(IconData icon, Color iconColor, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.display(fontSize: 24, color: AppColors.textPrimaryWarm)),
          const SizedBox(height: 1),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- Donors

  Widget _buildDonors() {
    final filtered = _service.donors
        .where((d) => _donorFilter == null || d.status == _donorFilter)
        .where((d) => _donorSearch.trim().isEmpty || d.name.toLowerCase().contains(_donorSearch.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _donorSearch = v),
            decoration: const InputDecoration(hintText: 'Search donors by name', prefixIcon: Icon(LucideIcons.search, size: 16)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FilterChipRow(
            chips: [
              FilterChipItem(label: 'All', active: _donorFilter == null, onTap: () => setState(() => _donorFilter = null)),
              FilterChipItem(label: 'Pending', active: _donorFilter == DonorVerificationStatus.pending, onTap: () => setState(() => _donorFilter = DonorVerificationStatus.pending)),
              FilterChipItem(label: 'Verified', active: _donorFilter == DonorVerificationStatus.verified, onTap: () => setState(() => _donorFilter = DonorVerificationStatus.verified)),
              FilterChipItem(label: 'Banned', active: _donorFilter == DonorVerificationStatus.banned, onTap: () => setState(() => _donorFilter = DonorVerificationStatus.banned)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No donors match this filter.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _donorCard(filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _donorCard(AdminDonorEntry donor) {
    final (statusBg, statusText, statusLabel) = switch (donor.status) {
      DonorVerificationStatus.pending => (AppColors.warmAmberBg, AppColors.warmAmberText, 'Pending'),
      DonorVerificationStatus.verified => (AppColors.warmGreenBg, AppColors.warmGreenText, 'Verified'),
      DonorVerificationStatus.banned => (AppColors.statusUrgentBg, AppColors.primary, 'Banned'),
    };

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminDonorDetailScreen(donorId: donor.id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(donor.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm))),
                StatusBadge.bloodGroup(donor.bloodGroup),
                const SizedBox(width: 6),
                StatusBadge(label: statusLabel, background: statusBg, textColor: statusText, fontSize: 11),
              ],
            ),
            const SizedBox(height: 6),
            Text(donor.phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const Divider(height: 20, color: AppColors.cardBorderWarm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: donor.available ? AppColors.warmGreenText : AppColors.textMuted)),
                    const SizedBox(width: 6),
                    Text(donor.available ? 'Available' : 'Unavailable', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                Switch(
                  value: donor.available,
                  activeThumbColor: AppColors.primary,
                  onChanged: (_) => _service.toggleAvailability(donor.id),
                ),
              ],
            ),
            Row(
              children: [
                if (donor.status != DonorVerificationStatus.verified)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _service.verifyDonor(donor.id),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.warmGreenText, side: const BorderSide(color: AppColors.warmGreenBorder)),
                      child: const Text('Verify'),
                    ),
                  ),
                if (donor.status != DonorVerificationStatus.verified) const SizedBox(width: 8),
                Expanded(
                  child: donor.status == DonorVerificationStatus.banned
                      ? OutlinedButton(onPressed: () => _service.unbanDonor(donor.id), child: const Text('Unban'))
                      : OutlinedButton(onPressed: () => _service.banDonor(donor.id), child: const Text('Ban')),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.primary),
                  tooltip: 'Delete donor profile',
                  onPressed: () => confirmAdminDelete(
                    context,
                    what: '${donor.name}\'s profile',
                    detail: 'This removes their profile. Once the backend is deployed, it also removes their sign-in account and ID proof.',
                    onConfirm: () => _service.deleteDonor(donor.id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Requests

  Widget _buildRequests() {
    final filtered = _service.requests.where((r) => _requestFilter == null || r.status == _requestFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: FilterChipRow(
            chips: [
              FilterChipItem(label: 'All', active: _requestFilter == null, onTap: () => setState(() => _requestFilter = null)),
              FilterChipItem(label: 'Open', active: _requestFilter == 'open', onTap: () => setState(() => _requestFilter = 'open')),
              FilterChipItem(label: 'Matched', active: _requestFilter == 'matched', onTap: () => setState(() => _requestFilter = 'matched')),
              FilterChipItem(label: 'Fulfilled', active: _requestFilter == 'fulfilled', onTap: () => setState(() => _requestFilter = 'fulfilled')),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No requests match this filter.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _requestCard(filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _requestCard(AdminRequestEntry request) {
    final (bg, text) = switch (request.status) {
      'open' => (AppColors.statusUrgentBg, AppColors.statusUrgentText),
      'matched' => (AppColors.statusPendingBg, AppColors.statusPendingText),
      'fulfilled' => (AppColors.statusAvailableBg, AppColors.statusAvailableText),
      _ => (AppColors.cardBorderWarm, AppColors.textPrimaryWarm),
    };
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminRequestDetailScreen(request: request))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StatusBadge.bloodGroup(request.bloodGroup),
                const SizedBox(width: 6),
                StatusBadge(label: request.statusLabel, background: bg, textColor: text, fontSize: 11),
                const Spacer(),
                Text(request.time, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            Text(request.location, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (request.matchedDonorName != null) ...[
              const SizedBox(height: 4),
              Text('Matched: ${request.matchedDonorName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.primary),
                tooltip: 'Delete request',
                onPressed: () => confirmAdminDelete(
                  context,
                  what: 'this request',
                  detail: 'Removes it outright — for spam, duplicates or test postings. Use Cancel from the requester\'s side for a normal withdrawal.',
                  onConfirm: () => _service.deleteRequest(request.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- Hospitals

  Widget _buildHospitals() {
    final filtered = _service.hospitals.where((h) => _hospitalSearch.trim().isEmpty || h.name.toLowerCase().contains(_hospitalSearch.toLowerCase())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: TextField(
            onChanged: (v) => setState(() => _hospitalSearch = v),
            decoration: const InputDecoration(hintText: 'Search hospitals', prefixIcon: Icon(LucideIcons.search, size: 16)),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              for (final hospital in filtered) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.building, color: AppColors.primary, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(hospital.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
                            const SizedBox(height: 2),
                            Text(hospital.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminHospitalFormScreen(hospital: hospital))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminHospitalFormScreen())),
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('Add hospital'),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.borderStrong)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------- Inbox

  /// Inbox = the two one-way submission forms, triaged. A report can be
  /// moved New → In progress → Resolved, carry an admin-only note, or be
  /// deleted outright (spam). Everything here is audit-logged by
  /// Backend.adminSet*Status. Community-story moderation moved to the
  /// Content tab, where the rest of the member-facing content lives.
  Widget _buildInbox() {
    final issueReports = _service.issueReports.where((r) => _inboxFilter == null || r.status == _inboxFilter).toList();
    final inquiries = _service.partnershipInquiries.where((p) => _inboxFilter == null || p.status == _inboxFilter).toList();
    final abuseReports = _service.reports.where((r) => _inboxFilter == null || r.status == _inboxFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: FilterChipRow(
            chips: [
              FilterChipItem(label: 'All', active: _inboxFilter == null, onTap: () => setState(() => _inboxFilter = null)),
              for (final s in InboxStatus.values)
                FilterChipItem(
                  label: inboxStatusLabel(s),
                  active: _inboxFilter == s,
                  onTap: () => setState(() => _inboxFilter = s),
                ),
            ],
          ),
        ),
        Expanded(
          child: issueReports.isEmpty && inquiries.isEmpty && abuseReports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _inboxFilter == null
                          ? 'No reports or inquiries yet.'
                          : 'Nothing is ${inboxStatusLabel(_inboxFilter!).toLowerCase()}.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    if (abuseReports.isNotEmpty) ...[
                      _inboxSectionLabel('CHAT & CALL REPORTS'),
                      for (final entry in abuseReports)
                        _inboxCard(
                          title: entry.reason,
                          subtitle: entry.subject,
                          body: entry.details,
                          meta: entry.time,
                          status: entry.status,
                          note: entry.adminNote,
                          onStatus: (s) => runAdminWrite(context, () => _service.setReportStatus(entry.id, s),
                              done: 'Marked ${inboxStatusLabel(s).toLowerCase()}.'),
                          onNote: () => _editInboxNote(
                            current: entry.adminNote,
                            save: (note) => _service.setReportStatus(entry.id, entry.status, note: note),
                          ),
                        ),
                      const SizedBox(height: 14),
                    ],
                    if (issueReports.isNotEmpty) ...[
                      _inboxSectionLabel('ISSUE REPORTS'),
                      for (final entry in issueReports)
                        _inboxCard(
                          title: entry.reason,
                          body: entry.details,
                          meta: entry.time,
                          status: entry.status,
                          note: entry.adminNote,
                          onStatus: (s) => runAdminWrite(context, () => _service.setIssueStatus(entry.id, s),
                              done: 'Marked ${inboxStatusLabel(s).toLowerCase()}.'),
                          onNote: () => _editInboxNote(
                            current: entry.adminNote,
                            save: (note) => _service.setIssueStatus(entry.id, entry.status, note: note),
                          ),
                          onDelete: () => confirmAdminDelete(
                            context,
                            what: 'this report',
                            onConfirm: () => _service.deleteIssueReport(entry.id),
                          ),
                        ),
                      const SizedBox(height: 14),
                    ],
                    if (inquiries.isNotEmpty) ...[
                      _inboxSectionLabel('PARTNERSHIP INQUIRIES'),
                      for (final entry in inquiries)
                        _inboxCard(
                          title: entry.orgName,
                          subtitle: '${entry.contactName} · ${entry.workEmail}',
                          highlight: entry.interest,
                          body: entry.message,
                          meta: entry.time,
                          status: entry.status,
                          note: entry.adminNote,
                          onStatus: (s) => runAdminWrite(context, () => _service.setPartnershipStatus(entry.id, s),
                              done: 'Marked ${inboxStatusLabel(s).toLowerCase()}.'),
                          onNote: () => _editInboxNote(
                            current: entry.adminNote,
                            save: (note) => _service.setPartnershipStatus(entry.id, entry.status, note: note),
                          ),
                          onDelete: () => confirmAdminDelete(
                            context,
                            what: 'this inquiry',
                            onConfirm: () => _service.deletePartnershipInquiry(entry.id),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _inboxSectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted, letterSpacing: 0.4)),
      );

  Future<void> _editInboxNote({required String current, required Future<void> Function(String) save}) async {
    final values = await openAdminEditor(
      context,
      title: 'Internal note',
      note: 'Only admins can read this. The person who submitted never sees it — there is no reply channel.',
      fields: [AdminEditorField(key: 'note', label: 'Note', initial: current, lines: 3)],
    );
    if (values == null || !mounted) return;
    await runAdminWrite(context, () => save(values['note'] ?? ''), done: 'Note saved.');
  }

  Widget _inboxCard({
    required String title,
    String? subtitle,
    String? highlight,
    required String body,
    required String meta,
    required InboxStatus status,
    required String note,
    required void Function(InboxStatus) onStatus,
    required VoidCallback onNote,
    VoidCallback? onDelete,
  }) {
    final (bg, fg) = switch (status) {
      InboxStatus.isNew => (AppColors.statusUrgentBg, AppColors.statusUrgentText),
      InboxStatus.inProgress => (AppColors.warmAmberBg, AppColors.warmAmberText),
      InboxStatus.resolved => (AppColors.warmGreenBg, AppColors.warmGreenText),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm))),
              const SizedBox(width: 6),
              StatusBadge(label: inboxStatusLabel(status), background: bg, textColor: fg, fontSize: 11),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
          if (highlight != null && highlight.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(highlight, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.primary)),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45)),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.sand,
                border: const Border(left: BorderSide(color: AppColors.textMuted, width: 2)),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
              ),
              child: Text(note, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)),
            ),
          ],
          const SizedBox(height: 8),
          Text(meta, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const Divider(height: 18, color: AppColors.cardBorderWarm),
          FilterChipRow(
            chips: [
              for (final s in InboxStatus.values)
                FilterChipItem(label: inboxStatusLabel(s), active: status == s, onTap: () => onStatus(s)),
            ],
          ),
          Row(
            children: [
              TextButton(onPressed: onNote, child: Text(note.isEmpty ? 'Add note' : 'Edit note')),
              const Spacer(),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 15, color: AppColors.primary),
                  tooltip: 'Delete',
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Activity

  Widget _buildActivity() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text('BROADCAST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Audience', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              FilterChipRow(
                chips: [
                  for (final option in const ['All donors', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'])
                    FilterChipItem(label: option, active: _audience == option, onTap: () => setState(() => _audience = option)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _broadcastController,
                maxLines: 3,
                onChanged: (_) {
                  if (_broadcastError != null) setState(() => _broadcastError = null);
                },
                decoration: const InputDecoration(hintText: 'Message to notify donors in this audience…'),
              ),
              if (_broadcastError != null) ...[
                const SizedBox(height: 6),
                Text(_broadcastError!, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
              ],
              const SizedBox(height: 6),
              const Text('Sent as a push notification to every signed-in phone in this audience.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  if (_broadcastController.text.trim().isEmpty) {
                    setState(() => _broadcastError = 'Write a message before sending.');
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await _service.sendBroadcast(_broadcastController.text, _audience);
                    _broadcastController.clear();
                    messenger.showSnackBar(const SnackBar(content: Text('Broadcast queued — phones receive it within a minute.')));
                  } catch (_) {
                    messenger.showSnackBar(const SnackBar(content: Text('Could not send the broadcast. Please try again.')));
                  }
                },
                icon: const Icon(LucideIcons.megaphone, size: 14),
                label: const Text('Send broadcast'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('AUDIT LOG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        for (final entry in _service.auditLog) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
                      const SizedBox(height: 3),
                      Text('${entry.actor} · ${entry.time}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
