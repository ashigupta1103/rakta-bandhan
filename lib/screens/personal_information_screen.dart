import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../services/phone_privacy.dart';
import 'location_picker_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';

/// The donor's own record: identity, verification, location and the two
/// fields they can edit (name, mobile number). The phone number is only
/// ever shown masked to its last three digits — including here, to its
/// owner — and the edit sheet never pre-fills it.
class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  late final Future<String?> _publicArea = Backend.instance.myPublicArea();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  bool _uploading = false;

  String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return initialsOf(trimmed);
  }

  Future<void> _openEditSheet({required String name, required String phone}) async {
    final nameController = TextEditingController(text: name);
    final phoneController = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _EditProfileSheet(
        nameController: nameController,
        phoneController: phoneController,
        currentPhone: phone,
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    }
  }

  Future<void> _uploadIdProof() async {
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take a photo'),
              onTap: () async {
                final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 70);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Choose from gallery'),
              onTap: () async {
                final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 70);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await Backend.instance.uploadIdProof(picked);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload ID proof. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
                    'Personal information',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: Backend.instance.myDonorDocStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  final data = snapshot.data!.data() ?? {};
                  final name = data['name'] as String? ?? '—';
                  final phone = data['phone'] as String? ?? '—';
                  final bloodGroup = data['blood_group'] as String? ?? '—';
                  final isVerified = data['is_verified'] as bool? ?? false;
                  final hasIdProof = data['has_id_proof'] == true || data['id_proof_base64'] != null;
                  final createdAt = data['created_at'] as Timestamp?;
                  final lat = data['lat'] as num?;
                  final lng = data['lng'] as num?;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipOval(
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    color: AppColors.primaryLightTint,
                                    alignment: Alignment.center,
                                    child: data['photo_url'] is String
                                        ? Image.network(
                                            data['photo_url'] as String,
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stack) =>
                                                Text(_initials(name), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                          )
                                        : Text(_initials(name), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                  ),
                                ),
                                if (bloodGroup != '—')
                                  Positioned(
                                    right: -6,
                                    bottom: -4,
                                    child: BloodGroupDroplet(label: bloodGroup, size: 26, filled: true, color: AppColors.primary, textColor: AppColors.onEmber, fontSize: 9),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name.isEmpty ? '—' : name, style: AppTextStyles.display(fontSize: 20, color: AppColors.textPrimaryWarm)),
                                  const SizedBox(height: 4),
                                  Text(maskPhone(phone), style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, fontFeatures: [FontFeature.tabularFigures()])),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _card([
                          _row(LucideIcons.droplet, 'Blood group', bloodGroup, emphasise: true),
                          _row(LucideIcons.phone, 'Mobile number', maskPhone(phone)),
                          _row(
                            LucideIcons.calendar,
                            'Member since',
                            createdAt == null ? '—' : _formatDate(createdAt.toDate()),
                            isLast: true,
                          ),
                        ]),
                        const SizedBox(height: 18),
                        _sectionLabel('Verification'),
                        _card([
                          _row(
                            isVerified ? LucideIcons.badgeCheck : LucideIcons.clock,
                            'Status',
                            isVerified ? 'Verified' : 'Pending review',
                            valueColor: isVerified ? AppColors.warmGreenText : AppColors.warmAmberText,
                            iconBg: isVerified ? AppColors.warmGreenBg : AppColors.warmAmberBg,
                            iconColor: isVerified ? AppColors.warmGreenText : AppColors.warmAmberText,
                            isLast: hasIdProof,
                          ),
                          if (!hasIdProof)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text('No ID proof uploaded — speeds up review', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                                  ),
                                  TextButton(
                                    onPressed: _uploading ? null : _uploadIdProof,
                                    child: _uploading
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Text('Upload'),
                                  ),
                                ],
                              ),
                            ),
                        ]),
                        const SizedBox(height: 18),
                        _sectionLabel('Location'),
                        _card([
                          _row(
                            LucideIcons.mapPin,
                            'Your area',
                            lat == null || lng == null
                                ? 'Not set'
                                : Backend.shortPlace(data['location_label'] as String?, fallback: 'Pinned on the map'),
                            stacked: true,
                          ),
                          FutureBuilder<String?>(
                            future: _publicArea,
                            builder: (context, snap) => _row(
                              LucideIcons.locateFixed,
                              'Nearby',
                              snap.data == null ? 'Approx. area not available yet' : 'Approx. area: ${snap.data}',
                              stacked: true,
                              isLast: true,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _changeArea(lat?.toDouble(), lng?.toDouble()),
                            icon: const Icon(LucideIcons.mapPinned, size: 15),
                            label: const Text('Change my area'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Other people see only your neighbourhood (for example “Adyar, Chennai”) and your distance — never your address.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textMutedWarm, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openEditSheet(
                              name: data['name'] as String? ?? '',
                              phone: data['phone'] as String? ?? '',
                            ),
                            icon: const Icon(LucideIcons.pencil, size: 15),
                            label: const Text('Edit name & number'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: AppColors.dividerWarm,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Blood group and verification status are set by an administrator and cannot be changed here.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cardBorderWarm),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  /// Moved house or job? Re-pin the area requests are matched against.
  Future<void> _changeArea(double? lat, double? lng) async {
    final picked = await LocationPickerScreen.open(
      context,
      title: 'Where do you usually live or work?',
      confirmLabel: 'Use this area',
      initialLat: lat,
      initialLng: lng,
    );
    if (picked == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Backend.instance.updateMyLocation(lat: picked.lat, lng: picked.lng, label: picked.label);
      messenger.showSnackBar(const SnackBar(content: Text('Your area is updated. Nearby requests will now match your new area.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn’t update your area. Please try again.')));
    }
  }

  Widget _row(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
    bool emphasise = false,
    bool stacked = false,
    Color? valueColor,
    Color iconBg = AppColors.dividerWarm,
    Color iconColor = AppColors.textSecondary,
  }) {
    final valueStyle = emphasise
        ? AppTextStyles.display(fontSize: 17, color: AppColors.primary)
        : TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimaryWarm, height: 1.35);
    final iconBox = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Icon(icon, size: 15, color: iconColor),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.dividerWarm)),
      ),
      child: stacked
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconBox,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      const SizedBox(height: 3),
                      Text(value, maxLines: 3, overflow: TextOverflow.ellipsis, style: valueStyle),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                iconBox,
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(value, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: valueStyle),
                ),
              ],
            ),
    );
  }
}

/// Edit sheet for the two fields a donor owns outright. Blood group is
/// excluded on purpose: it drives matching, and an unverified self-edit of
/// it would silently change who this donor can give to.
class _EditProfileSheet extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  /// The saved number, used only when the field is left empty — never shown.
  final String currentPhone;

  const _EditProfileSheet({required this.nameController, required this.phoneController, required this.currentPhone});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  bool _saving = false;
  String? _nameError;
  String? _phoneError;

  Future<void> _save() async {
    final name = widget.nameController.text.trim();
    final phone = widget.phoneController.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Name is required' : null;
      _phoneError = phone.isNotEmpty && phone.length != 10 ? 'Enter a valid 10-digit number' : null;
    });
    if (_nameError != null || _phoneError != null) return;

    setState(() => _saving = true);
    try {
      await Backend.instance.updateProfile(name: name, phone: phone.isEmpty ? widget.currentPhone : phone);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameError = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit your details', style: AppTextStyles.display(fontSize: 19, color: AppColors.textPrimaryWarm)),
          const SizedBox(height: 18),
          const Text('Full name', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
          const SizedBox(height: 6),
          TextField(
            controller: widget.nameController,
            decoration: InputDecoration(hintText: 'Your name', errorText: _nameError),
          ),
          const SizedBox(height: 14),
          const Text('Mobile number', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
          const SizedBox(height: 6),
          TextField(
            controller: widget.phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              hintText: 'New 10-digit number',
              helperText: 'Leave empty to keep ${maskPhone(widget.currentPhone)}',
              errorText: _phoneError,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
