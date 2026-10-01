import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/admin_service.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../widgets/status_badge.dart';

/// Admin console → Content. Everything the app shows on its non-transactional
/// screens is edited here, so none of it is hardcoded copy any more:
///
/// * **What's New** — `announcements`, rendered by Community → What's New.
/// * **Testimonials** — `testimonials`, rendered by More → Testimonials.
///   Admin-write-only by rules, which is what keeps "curated and verified"
///   true rather than decorative.
/// * **Impact** — the `public_stats/impact` counter behind Community →
///   Impact. Donations bump it by +1 automatically; this is the correction
///   path (miscount, or donations confirmed offline).
/// * **Community stories** — moderation. Hiding is reversible (the feed
///   filters `is_hidden`); deleting isn't, so it asks first.
class AdminContentTab extends StatelessWidget {
  const AdminContentTab({super.key});

  AdminService get _service => AdminService.instance;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _sectionHeader(
          "WHAT'S NEW",
          '${_service.announcements.length} live in Community',
          onAdd: () => _editAnnouncement(context),
        ),
        if (_service.announcements.isEmpty)
          _emptyRow('No announcements published. Community → What\'s New shows its empty state.')
        else
          for (final a in _service.announcements)
            _contentCard(
              title: a.title,
              body: a.body,
              time: a.time,
              onEdit: () => _editAnnouncement(context, entry: a),
              onDelete: () => confirmAdminDelete(
                context,
                what: 'this announcement',
                onConfirm: () => _service.deleteAnnouncement(a.id),
              ),
            ),
        const SizedBox(height: 22),
        _sectionHeader(
          'TESTIMONIALS',
          '${_service.testimonials.length} live behind More → Testimonials',
          onAdd: () => _editTestimonial(context),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warmAmberBg,
            border: const Border(left: BorderSide(color: AppColors.warmAmberText, width: 3)),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
          ),
          child: const Text(
            'Publish a quote only with the person\'s written permission — these are attributed by name and are not member posts.',
            style: TextStyle(fontSize: 11.5, color: AppColors.warmAmberText, height: 1.45),
          ),
        ),
        if (_service.testimonials.isEmpty)
          _emptyRow('No testimonials published. The Testimonials page shows its empty state.')
        else
          for (final t in _service.testimonials)
            _contentCard(
              title: '${t.name}${t.role.isEmpty ? '' : ' · ${t.role}'}',
              body: '"${t.quote}"',
              time: t.time,
              onEdit: () => _editTestimonial(context, entry: t),
              onDelete: () => confirmAdminDelete(
                context,
                what: 'this testimonial',
                onConfirm: () => _service.deleteTestimonial(t.id),
              ),
            ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: Backend.instance.testimonialSubmissionsStream(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? const [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionHeader('SUBMITTED BY MEMBERS', '${docs.length} waiting · members consented to publishing'),
                if (docs.isEmpty)
                  _emptyRow('No member submissions waiting.')
                else
                  for (final d in docs)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${d.data()['name'] ?? 'Member'}${(d.data()['role'] as String? ?? '').isEmpty ? '' : ' · ${d.data()['role']}'}',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                          ),
                          const SizedBox(height: 6),
                          Text('"${d.data()['quote'] ?? ''}"', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => Backend.instance.adminApproveTestimonialSubmission(d.id, d.data()),
                                icon: const Icon(LucideIcons.check, size: 15),
                                label: const Text('Publish'),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                onPressed: () => confirmAdminDelete(
                                  context,
                                  what: 'this submission',
                                  onConfirm: () => Backend.instance.adminRejectTestimonialSubmission(d.id),
                                ),
                                icon: const Icon(LucideIcons.x, size: 15),
                                label: const Text('Reject'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _sectionHeader('IMPACT COUNTER', 'Community → Impact, this month'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _service.impactThisMonth == null ? '—' : '${_service.impactThisMonth}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'donations this month · +1 per confirmed donation, automatically',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _editImpact(context),
                child: const Text('Correct'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _sectionHeader('COMMUNITY STORIES', '${_service.stories.length} posted by members'),
        if (_service.stories.isEmpty)
          _emptyRow('No stories posted yet.')
        else
          for (final s in _service.stories)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.isHidden ? AppColors.sand : Colors.white,
                border: Border.all(color: AppColors.cardBorderWarm),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${s.authorName}${s.topic.isEmpty ? '' : ' · ${s.topic}'}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                        ),
                      ),
                      if (s.isHidden)
                        const StatusBadge(label: 'Hidden', background: AppColors.warmAmberBg, textColor: AppColors.warmAmberText, fontSize: 11),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(s.body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(s.time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => runAdminWrite(context, () => _service.setStoryHidden(s.id, !s.isHidden),
                            done: s.isHidden ? 'Story is visible again.' : 'Story hidden from Community.'),
                        child: Text(s.isHidden ? 'Unhide' : 'Hide'),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, size: 15, color: AppColors.primary),
                        tooltip: 'Delete permanently',
                        onPressed: () => confirmAdminDelete(
                          context,
                          what: 'this story',
                          onConfirm: () => _service.deleteStory(s.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }

  // ------------------------------------------------------------- pieces

  Widget _sectionHeader(String label, String subtitle, {VoidCallback? onAdd}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted, letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (onAdd != null)
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 13),
              label: const Text('Add'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderStrong),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyRow(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
      );

  Widget _contentCard({
    required String title,
    required String body,
    required String time,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const Spacer(),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
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

  // ------------------------------------------------------------- editors

  Future<void> _editAnnouncement(BuildContext context, {AdminAnnouncementEntry? entry}) async {
    final values = await openAdminEditor(
      context,
      title: entry == null ? 'New announcement' : 'Edit announcement',
      fields: [
        AdminEditorField(key: 'title', label: 'Title', initial: entry?.title, required: true),
        AdminEditorField(key: 'body', label: 'Body', initial: entry?.body, required: true, lines: 4),
      ],
    );
    if (values == null || !context.mounted) return;
    await runAdminWrite(
      context,
      () => _service.saveAnnouncement(id: entry?.id, title: values['title']!, body: values['body']!),
      done: entry == null ? 'Announcement published.' : 'Announcement updated.',
    );
  }

  Future<void> _editTestimonial(BuildContext context, {AdminTestimonialEntry? entry}) async {
    final values = await openAdminEditor(
      context,
      title: entry == null ? 'New testimonial' : 'Edit testimonial',
      fields: [
        AdminEditorField(key: 'quote', label: 'Quote', initial: entry?.quote, required: true, lines: 4),
        AdminEditorField(key: 'name', label: 'Attributed to', initial: entry?.name, required: true),
        AdminEditorField(key: 'role', label: 'Role (e.g. Donor, Hospital coordinator)', initial: entry?.role),
      ],
    );
    if (values == null || !context.mounted) return;
    await runAdminWrite(
      context,
      () => _service.saveTestimonial(
        id: entry?.id,
        quote: values['quote']!,
        name: values['name']!,
        role: values['role'] ?? '',
      ),
      done: entry == null ? 'Testimonial published.' : 'Testimonial updated.',
    );
  }

  Future<void> _editImpact(BuildContext context) async {
    final values = await openAdminEditor(
      context,
      title: 'Correct the impact figure',
      note: 'Sets this month\'s donation count outright. Confirmed donations keep adding +1 on top of whatever you set.',
      fields: [
        AdminEditorField(
          key: 'count',
          label: 'Donations this month',
          initial: '${AdminService.instance.impactThisMonth ?? 0}',
          required: true,
          numeric: true,
        ),
      ],
    );
    if (values == null || !context.mounted) return;
    final count = int.tryParse(values['count']!.trim());
    if (count == null || count < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a whole number, 0 or more.')));
      return;
    }
    await runAdminWrite(context, () => _service.setImpactCount(count), done: 'Impact figure set to $count.');
  }

}

/// Shared by this tab and the console's Inbox tab. Returns whether the
/// delete actually went through (confirmed AND the write succeeded) — a
/// caller that navigates away afterward (a detail screen popping back to
/// its list) needs that, not just "the user clicked Delete".
Future<bool> confirmAdminDelete(
  BuildContext context, {
  required String what,
  String? detail,
  required Future<void> Function() onConfirm,
  String done = 'Deleted.',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete $what?'),
      content: Text(detail ?? 'This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep')),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  return runAdminWrite(context, onConfirm, done: done);
}

/// One place for "await the write, report the outcome" — a rules rejection
/// has to surface, not disappear into a silent no-op. Returns true iff
/// [action] completed without throwing.
Future<bool> runAdminWrite(BuildContext context, Future<void> Function() action, {required String done}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('That write was rejected. Check you are still signed in as an admin.')));
    return false;
  }
}

Future<Map<String, String>?> openAdminEditor(
  BuildContext context, {
  required String title,
  required List<AdminEditorField> fields,
  String? note,
}) =>
    showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmGround,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _EditorSheet(title: title, fields: fields, note: note),
    );

class AdminEditorField {
  final String key;
  final String label;
  final String? initial;
  final bool required;
  final int lines;
  final bool numeric;

  const AdminEditorField({
    required this.key,
    required this.label,
    this.initial,
    this.required = false,
    this.lines = 1,
    this.numeric = false,
  });
}

/// Generic n-field bottom sheet — one form for announcements, testimonials,
/// the impact figure and the inbox note, instead of four near-identical ones.
class _EditorSheet extends StatefulWidget {
  final String title;
  final List<AdminEditorField> fields;
  final String? note;

  const _EditorSheet({required this.title, required this.fields, this.note});

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields) f.key: TextEditingController(text: f.initial ?? ''),
  };
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    for (final f in widget.fields) {
      if (f.required && _controllers[f.key]!.text.trim().isEmpty) {
        setState(() => _error = '${f.label} is required.');
        return;
      }
    }
    Navigator.pop(context, {for (final f in widget.fields) f.key: _controllers[f.key]!.text});
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.warmBorder, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
              if (widget.note != null) ...[
                const SizedBox(height: 8),
                Text(widget.note!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45)),
              ],
              const SizedBox(height: 14),
              for (final f in widget.fields) ...[
                TextField(
                  controller: _controllers[f.key],
                  minLines: f.lines,
                  maxLines: f.lines == 1 ? 1 : f.lines + 2,
                  keyboardType: f.numeric ? TextInputType.number : TextInputType.multiline,
                  decoration: InputDecoration(labelText: f.label),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                const SizedBox(height: 10),
              ],
              ElevatedButton(onPressed: _submit, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
