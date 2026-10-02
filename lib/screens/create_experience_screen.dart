import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../demo/demo.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/dashed_border.dart';
import '../widgets/rb_icon.dart';

/// "Share an experience" — posts a real story to `community_stories`, shown
/// on the Community → Stories tab, optionally with one photo. The photo is
/// downscaled on the phone (1440 px, JPEG ~78%) before upload, so a post
/// costs ~150–300 KB of storage instead of a 4–6 MB camera original.
class CreateExperienceScreen extends StatefulWidget {
  /// Set when editing the user's own story: the form opens pre-filled with
  /// its text and topic. Saves use the author's authenticated backend path.
  final String? editStoryId;
  final String initialBody;
  final String? initialTopic;

  const CreateExperienceScreen({super.key, this.editStoryId, this.initialBody = '', this.initialTopic});

  @override
  State<CreateExperienceScreen> createState() => _CreateExperienceScreenState();
}

class _CreateExperienceScreenState extends State<CreateExperienceScreen> {
  static const _topics = ['My first donation', 'Donation experience', 'Helping someone', 'Blood camp', 'Gratitude', 'Awareness', 'Other'];

  late final _textController = TextEditingController(text: widget.initialBody);
  final _focusNode = FocusNode();
  late String _topic = _topics.contains(widget.initialTopic) ? widget.initialTopic! : 'My first donation';
  bool get _editing => widget.editStoryId != null;
  bool _showBloodGroup = true;
  bool _tagLocation = false;
  XFile? _photo;
  Uint8List? _photoBytes;

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const RbIcon(RbGlyph.photo), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(sheet, ImageSource.gallery)),
            ListTile(leading: const RbIcon(RbGlyph.camera), title: const Text('Take a photo'), onTap: () => Navigator.pop(sheet, ImageSource.camera)),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1440, maxHeight: 1440, imageQuality: 78);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That photo is too large. Try a different one.')));
        return;
      }
      if (!mounted) return;
      setState(() {
        _photo = picked;
        _photoBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t open photos. Check the app’s permission in Settings.')));
    }
  }

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

  bool _submitting = false;

  Future<void> _submit() async {
    final body = _textController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write something to share first.')));
      return;
    }
    if (_editing) {
      final messenger = ScaffoldMessenger.of(context);
      if (Demo.isDemoId(widget.editStoryId)) {
        Demo.instance.updateStory(widget.editStoryId!, body: body, topic: _topic, photo: _photoBytes);
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(content: Text('Story updated.')));
        return;
      }
      setState(() => _submitting = true);
      try {
        await Backend.instance.updateCommunityStory(widget.editStoryId!, body: body, topic: _topic, photo: _photo);
        if (!mounted) return;
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(content: Text('Story updated.')));
      } catch (_) {
        if (!mounted) return;
        setState(() => _submitting = false);
        messenger.showSnackBar(const SnackBar(content: Text('Could not save your changes. Please try again.')));
      }
      return;
    }
    if (Demo.on) {
      // Kept in the demo's own feed only — never posted.
      Demo.instance.addStory(body, _topic, photo: _photoBytes, showBloodGroup: _showBloodGroup, showArea: _tagLocation);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo · added to the demo feed on this device. Nothing was posted or uploaded.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final donor = (await Backend.instance.myDonorDoc()).data();
      // Neighbourhood only ("Adyar, Chennai") — never the registered address.
      final area = _tagLocation ? await Backend.instance.myPublicArea() : null;
      await Backend.instance.submitCommunityStory(topic: _topic, body: body, bloodGroup: _showBloodGroup ? (donor?['blood_group'] as String?) : null, locationLabel: area, photo: _photo);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared with the community.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not share this. Please try again.')));
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
                  IconButton(
                    tooltip: 'Close',
                    icon: const RbIcon(RbGlyph.close, color: AppColors.textPrimaryWarm),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    _editing ? 'Edit story' : 'Share an experience',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_editing ? 'Your story' : 'What happened?', style: AppTextStyles.display(fontSize: 25, color: AppColors.ink, height: 1.2)),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13.5, color: AppColors.ink2),
                        children: [
                          const TextSpan(text: 'You post as '),
                          TextSpan(
                            text: 'your first name and @username',
                            style: TextStyle(color: AppColors.goldDeep, fontWeight: FontWeight.w700),
                          ),
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
                    // Editing changes the words and topic only; the photo and
                    // privacy choices stay as originally posted.
                    if (_editing) ...[
                      const SizedBox(height: 10),
                      const Text('The photo and privacy settings stay as you posted them.', style: TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.4)),
                    ],
                    if (!_editing) ...[
                      const SizedBox(height: 14),
                      if (_photoBytes != null)
                        // Preview exactly as the feed will show it.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 4 / 5,
                                child: Image.memory(_photoBytes!, fit: BoxFit.cover, width: double.infinity),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton.filled(
                                  tooltip: 'Remove photo',
                                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                  icon: const RbIcon(RbGlyph.close, size: 16, color: Colors.white),
                                  onPressed: () => setState(() {
                                    _photo = null;
                                    _photoBytes = null;
                                  }),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                                  onPressed: _pickPhoto,
                                  icon: const RbIcon(RbGlyph.retry, size: 14),
                                  label: const Text('Change'),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _pickPhoto,
                          child: CustomPaint(
                            painter: DashedRRectPainter(color: AppColors.warmBorder, radius: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RbIcon(RbGlyph.photoAdd, size: 16, color: AppColors.ink2),
                                  SizedBox(width: 8),
                                  Text('Add a photo (optional)', style: TextStyle(fontSize: 13.5, color: AppColors.ink2)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (Demo.on) ...[
                        const SizedBox(height: 8),
                        const Text('Demo · a photo you pick stays on this device for the demo feed. Nothing is uploaded.', style: TextStyle(fontSize: 12, color: AppColors.goldDeep, height: 1.4)),
                      ],
                    ],
                    const SizedBox(height: 22),
                    const Text(
                      'Choose a topic',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.ink2),
                    ),
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
                              child: Text(
                                topic,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: _topic == topic ? FontWeight.w600 : FontWeight.w400,
                                  color: _topic == topic ? AppColors.whiteTextOnPrimary : AppColors.textPrimaryWarm,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!_editing) ...[
                      const SizedBox(height: 22),
                      const Text(
                        'Privacy',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.ink2),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.warmBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _privacyRow('Show my blood group', 'Adds the droplet to your disc', _showBloodGroup, (v) => setState(() => _showBloodGroup = v)),
                            _privacyRow('Show my area', 'Neighbourhood only, e.g. “Adyar, Chennai” — never your address', _tagLocation, (v) => setState(() => _tagLocation = v), isLast: true),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.warmBorder)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_textController.text.trim().isEmpty || _submitting) ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_editing ? 'Save changes' : 'Share experience'),
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Visible to everyone signed in to Rakta Bandhan. Follow the community guidelines — no phone numbers, no payment for blood.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: AppColors.disabledTint, height: 1.4),
                  ),
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
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.warmDivider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm),
                ),
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
