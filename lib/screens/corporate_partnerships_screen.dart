import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/rb_icon.dart';

/// Corporate partnerships — per the final artifact's "Trust & brand"
/// section. "Start a conversation" writes a real inquiry to Firestore
/// (Backend.submitPartnershipInquiry), visible to admins in the console.
/// What's genuinely undecided is the commercial side of it — sponsor
/// names, tiers, pricing; see the stakeholder checklist's "Corporate
/// partnerships" section for that.
class CorporatePartnershipsScreen extends StatelessWidget {
  const CorporatePartnershipsScreen({super.key});

  void _startConversation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmGround,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => const _ConversationSheet(),
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
                    IconButton(
                      tooltip: 'Back',icon: const RbIcon(RbGlyph.back, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 4),
                    const Text('Partner with us', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('For organisations', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.goldDeep)),
                    const SizedBox(height: 10),
                    Text('Put your name behind something that saves lives', style: AppTextStyles.display(fontSize: 26, color: AppColors.ink, height: 1.2)),
                    const SizedBox(height: 12),
                    Text(
                      'Organisations can support Rakta Bandhan through donation drives, health initiatives, donor recognition or volunteering — the shape of each partnership is defined together with the team.',
                      style: AppTextStyles.display(fontSize: 16, color: const Color(0xFF3D2523), height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        _sponsorCard(RbGlyph.droplet, AppColors.red100, AppColors.brandRed, 'Sponsor a donation drive'),
                        _sponsorCard(RbGlyph.plus, AppColors.goldTint, AppColors.goldDeep, 'Sponsor a health initiative'),
                        _sponsorCard(RbGlyph.certificate, AppColors.orangeTint, AppColors.orangeDeep, 'Sponsor donor recognition'),
                        _sponsorCard(RbGlyph.community, AppColors.successBg, AppColors.successText, 'Corporate volunteering'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment(-0.3, -1), end: Alignment(0.3, 1), colors: [AppColors.emberFieldStart, AppColors.emberFieldMid]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Where your name appears', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.gold)),
                          const SizedBox(height: 10),
                          const Text(
                            'Camp materials, the initiative card in What\'s New, donor certificates and recognition moments. Never over a blood request, and never inside an emergency flow.',
                            style: TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xD9FBEDE6)),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(border: Border.all(color: const Color(0x66E0A030)), borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: const Text('Sponsor lockup slot · sizes defined in the system', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Color(0x99FBEDE6))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(color: AppColors.goldTint, border: const Border(left: BorderSide(color: AppColors.gold, width: 3)), borderRadius: const BorderRadius.horizontal(right: Radius.circular(12))),
                      child: const Text(
                        'No real sponsor, tier, price or benefit has been invented — commercial terms and real partner details are yours to define and supply.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(onPressed: () => _startConversation(context), child: const Text('Start a conversation')),
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

  Widget _sponsorCard(RbGlyph icon, Color bg, Color fg, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: RbIcon(icon, size: 16, color: fg)),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
        ],
      ),
    );
  }
}

/// A real, validated frontend form — organisation, contact, email,
/// interest and an optional message — with proper loading/success states.
/// What it honestly does NOT have is a backend to send to: there is no
/// lead-capture endpoint or Firestore collection for this yet (verified
/// against backend.dart), so submitting never claims the message reached
/// anyone. Backend requirement: a write-only "partnership_enquiries"
/// endpoint/collection plus a way for the Rakta Bandhan team to see
/// submissions — tracked in STAKEHOLDER_REQUIREMENTS_CHECKLIST.md.
class _ConversationSheet extends StatefulWidget {
  const _ConversationSheet();

  @override
  State<_ConversationSheet> createState() => _ConversationSheetState();
}

class _ConversationSheetState extends State<_ConversationSheet> {
  static const _interests = [
    'Sponsor a donation drive',
    'Sponsor a health initiative',
    'Sponsor donor recognition',
    'Corporate volunteering',
  ];

  final _formKey = GlobalKey<FormState>();
  final _orgController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  String? _interest;
  bool _interestError = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _orgController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() {
      _interestError = _interest == null;
      _error = null;
    });
    if (!formOk || _interest == null) return;
    setState(() => _submitting = true);
    try {
      await Backend.instance.submitPartnershipInquiry(
        orgName: _orgController.text,
        contactName: _nameController.text,
        workEmail: _emailController.text,
        interest: _interest!,
        message: _messageController.text,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not send this. Please try again.';
      });
    }
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
              Text(_submitted ? 'Details sent' : 'Start a conversation', style: AppTextStyles.display(fontSize: 21, color: AppColors.ink)),
              const SizedBox(height: 16),
              if (_submitted) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.goldTint, border: const Border(left: BorderSide(color: AppColors.gold, width: 3)), borderRadius: const BorderRadius.horizontal(right: Radius.circular(12))),
                  child: const Text(
                    'Your details have been sent to the team. They will follow up at the work email you provided.',
                    style: TextStyle(fontSize: 13, color: AppColors.goldDeepest, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
              ] else ...[
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Organisation name', _orgController, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                      const SizedBox(height: 14),
                      _field('CONTACT PERSON’S NAME', _nameController, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                      const SizedBox(height: 14),
                      _field(
                        'Work email',
                        _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return 'Enter a valid email';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Partnership interest', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.ink2)),
                const SizedBox(height: 8),
                FilterChipRow(
                  activeBg: AppColors.primary,
                  chips: [for (final i in _interests) FilterChipItem(label: i, active: _interest == i, onTap: () => setState(() { _interest = i; _interestError = false; }))],
                ),
                if (_interestError) ...[
                  const SizedBox(height: 6),
                  const Text('Pick one to continue', style: TextStyle(fontSize: 11.5, color: AppColors.brandRed)),
                ],
                const SizedBox(height: 14),
                _field('Message (optional)', _messageController, minLines: 3, maxLines: 5, hint: 'Tell us a bit about what you have in mind'),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(fontSize: 11.5, color: AppColors.brandRed)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.ink2)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            minLines: minLines,
            maxLines: maxLines,
            decoration: InputDecoration(hintText: hint, border: InputBorder.none, filled: false, contentPadding: const EdgeInsets.all(12)),
          ),
        ),
      ],
    );
  }
}
