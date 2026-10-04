import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/emergency_contact_service.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_button.dart';
import '../widgets/state_card.dart';

/// Emergency contact capture.
///
/// Backed by MockEmergencyContactService — see that file for the backend
/// boundary. Device-local until the donor schema carries the field, which
/// the screen tells the user rather than implying a synced record.
class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({super.key});

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final EmergencyContactService _service = MockEmergencyContactService();

  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _nameError;
  String? _phoneError;
  EmergencyContact? _contact;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final contact = await _service.load();
    if (!mounted) return;
    setState(() {
      _contact = contact;
      _loading = false;
      _editing = contact == null;
      if (contact != null) {
        _nameController.text = contact.name;
        _relationshipController.text = contact.relationship;
        _phoneController.text = contact.phone;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'Enter a name' : null;
      _phoneError = phone.isEmpty
          ? 'Enter a phone number'
          : (phone.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(phone))
              ? 'Enter a valid 10-digit number'
              : null;
    });
    if (_nameError != null || _phoneError != null) return;

    setState(() => _saving = true);
    final contact = EmergencyContact(
      name: name,
      relationship: _relationshipController.text.trim(),
      phone: phone,
    );
    await _service.save(contact);
    if (!mounted) return;
    setState(() {
      _contact = contact;
      _saving = false;
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency contact saved')),
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
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Emergency contact',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      child: _editing ? _form() : _summary(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    final contact = _contact!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.cardBorderWarm),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(LucideIcons.phone, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                    ),
                    if (contact.relationship.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.relationship,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      contact.phone,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => setState(() => _editing = true),
          child: const Text('Edit contact'),
        ),
        const SizedBox(height: 20),
        _localNote(),
      ],
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_contact == null) ...[
          StateCard.empty(
            title: 'No emergency contact yet',
            icon: LucideIcons.phone,
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Add someone we can reach if something goes wrong during a donation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 22),
        ],
        _label('Full name'),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: 'e.g. Meera Sharma', errorText: _nameError),
        ),
        const SizedBox(height: 16),
        _label('Relationship'),
        TextField(
          controller: _relationshipController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Sister (optional)'),
        ),
        const SizedBox(height: 16),
        _label('Phone number'),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(hintText: '10-digit number', errorText: _phoneError),
        ),
        const SizedBox(height: 24),
        LoadingButton(
          label: 'Save contact',
          isLoading: _saving,
          onPressed: _save,
        ),
        if (_contact != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving ? null : () => setState(() => _editing = false),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Cancel'),
          ),
        ],
        const SizedBox(height: 20),
        _localNote(),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
      );

  Widget _localNote() => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.dividerWarm,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Saved on this device only. Emergency contacts will sync to your account once the backend field is added.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
        ),
      );
}
