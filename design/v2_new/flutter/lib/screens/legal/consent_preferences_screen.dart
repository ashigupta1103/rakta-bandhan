import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/consent_preferences_service.dart';
import '../../theme/app_colors.dart';

/// Granular, revocable consent controls.
///
/// This is the mobile-appropriate equivalent of a web cookie banner: the
/// app has no cookie store, so what actually needs consent is contact
/// reveal, location use, notifications and (once it exists) analytics.
///
/// Backed by MockConsentPreferencesService — see that file for the backend
/// boundary.
class ConsentPreferencesScreen extends StatefulWidget {
  const ConsentPreferencesScreen({super.key});

  @override
  State<ConsentPreferencesScreen> createState() => _ConsentPreferencesScreenState();
}

class _ConsentPreferencesScreenState extends State<ConsentPreferencesScreen> {
  final ConsentPreferencesService _service = MockConsentPreferencesService();
  Map<String, bool> _values = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await _service.load();
    if (!mounted) return;
    setState(() {
      _values = values;
      _loading = false;
    });
  }

  Future<void> _set(ConsentOption option, bool value) async {
    setState(() => _values = {..._values, option.id: value});
    await _service.setConsent(option.id, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? '${option.title} turned on' : '${option.title} withdrawn',
        ),
      ),
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
                    'Consent preferences',
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'You can withdraw any non-essential consent at any time. Withdrawing one does not delete your account.',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.55),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.cardBorderWarm),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: Offset(0, 3)),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (var i = 0; i < kConsentOptions.length; i++)
                                  _tile(
                                    kConsentOptions[i],
                                    isLast: i == kConsentOptions.length - 1,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.dividerWarm,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'Preferences are stored on this device for now. They will move to your account once the consent field is added to the backend.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
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

  Widget _tile(ConsentOption option, {required bool isLast}) {
    final value = _values[option.id] ?? option.defaultValue;
    final locked = option.essential || option.notYetActive;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.dividerWarm)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        option.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryWarm,
                        ),
                      ),
                    ),
                    if (option.essential) _pill('Required'),
                    if (option.notYetActive) _pill('Not active yet'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  option.description,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryLightTint,
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.border,
            onChanged: locked ? null : (val) => _set(option, val),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label) => Container(
        margin: const EdgeInsets.only(left: 7),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.dividerWarm,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
      );
}
