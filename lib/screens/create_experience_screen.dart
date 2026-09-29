import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/dashed_border.dart';

/// "Share an experience" — posts a real story to `community_stories`, shown
/// on the Community → Stories tab. Photo attachment is still not offered:
/// images would need Cloud Storage (Blaze-only since Sep 2026) and the
/// base64-in-Firestore trick used for ID proof doesn't scale to a public
/// feed of images.
class CreateExperienceScreen extends StatefulWidget {
  const CreateExperienceScreen({super.key});

  @override
  State<CreateExperienceScreen> createState() => _CreateExperienceScreenState();
}

class _CreateExperienceScreenState extends State<CreateExperienceScreen> {
  static const _topics = ['My first donation', 'Donation experience', 'Helping someone', 'Blood camp', 'Gratitude', 'Awareness', 'Other'];

  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  String _topic = 'My first donation';
  bool _showBloodGroup = true;
  bool _tagLocation = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon.')));
  }

  bool _submitting = false;

  Future<void> _submit() async {
    final body = _textController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something to share first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final donor = (await Backend.instance.myDonorDoc()).data();
      await Backend.instance.submitCommunityStory(
        topic: _topic,
        body: body,
        bloodGroup: _showBloodGroup ? (donor?['blood_group'] as String?) : null,
        locationLabel: _tagLocation ? (donor?['location_label'] as String?) : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shared with the community.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share this. Please try again.')),
      );
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
              height: 48,
              child: Row(
                children: [
                  IconButton(icon: const Icon(LucideIcons.x, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
                  const Text('Share an experience', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What happened?', style: AppTextStyles.display(fontSize: 25, color: AppColors.ink, height: 1.2)),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13.5, color: AppColors.ink2),
                        children: [
                          const TextSpan(text: 'You post as '),
                          TextSpan(text: 'your registered name', style: TextStyle(color: AppColors.goldDeep, fontWeight: FontWeight.w700)),
                          const TextSpan(text: '. Your phone number and exact address are never shown.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 132),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _focusNode.hasFocus ? AppColors.brandRed : AppColors.warmBorder, width: _focusNode.hasFocus ? 1.5 : 1),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, 6))],
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        maxLines: null,
                        minLines: 4,
                        onChanged: (_) => setState(() {}),
                        style: AppTextStyles.display(fontSize: 17, color: AppColors.ink, height: 1.55),
                        decoration: InputDecoration(
                          hintText: "Tell it the way you'd tell a friend — how you felt, who you helped, what surprised you.",
                          hintStyle: AppTextStyles.display(fontSize: 17, color: AppColors.disabledTint, height: 1.55),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _comingSoon('Adding a photo'),
                            child: CustomPaint(
                              painter: DashedRRectPainter(color: AppColors.warmBorder, radius: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                alignment: Alignment.center,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.plus, size: 15, color: AppColors.ink2),
                                    SizedBox(width: 7),
                                    Text('Add photo', style: TextStyle(fontSize: 13.5, color: AppColors.ink2)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 74,
                          height: 50,
                          decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: const Text('4:3\ncrop', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 1.3, color: AppColors.disabledTint)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text('Choose a topic', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.ink2)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final topic in _topics)
                          GestureDetector(
                            onTap: () => setState(() => _topic = topic),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: _topic == topic ? AppColors.brandRed : Colors.white,
                                border: _topic == topic ? null : Border.all(color: AppColors.warmBorder),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(topic, style: TextStyle(fontSize: 13.5, fontWeight: _topic == topic ? FontWeight.w600 : FontWeight.w400, color: _topic == topic ? AppColors.whiteTextOnPrimary : AppColors.textPrimaryWarm)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text('Privacy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.ink2)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          _privacyRow('Show my blood group', 'Adds the droplet to your disc', _showBloodGroup, (v) => setState(() => _showBloodGroup = v)),
                          _privacyRow('Tag the camp or hospital', 'Location only — never your address', _tagLocation, (v) => setState(() => _tagLocation = v), isLast: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.warmBorder))),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_textController.text.trim().isEmpty || _submitting) ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Share experience'),
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text('Your story appears on the Community tab for other donors', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.disabledTint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacyRow(String label, String subtitle, bool value, ValueChanged<bool> onChanged, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.warmDivider))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.disabledTint)),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
