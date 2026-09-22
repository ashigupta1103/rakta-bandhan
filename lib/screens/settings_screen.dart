import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../widgets/logout_flow.dart';

/// Settings & privacy — the final artifact's "persisted, grouped, one
/// destructive treatment" section. The exact-address toggle previously
/// lived only in widget state and was thrown away on every rebuild — the
/// design doc calls this out by name as a privacy promise the app was
/// breaking. It now persists via SharedPreferences: there is no
/// `donors/{uid}` field for it and this phase doesn't add one, but a
/// device-local setting that actually survives a rebuild is still strictly
/// more honest than one that silently resets. Every other toggle the design
/// mock shows (blood-group visibility in Community, "Appear in Find
/// results", notification preferences) has no backing field or
/// infrastructure at all and is left out rather than faked — Find/Request
/// visibility is already fully governed by the real `is_available` toggle
/// on My Page.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kShowExactAddress = 'rb_show_exact_address';

  bool _loaded = false;
  bool _showExactAddress = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showExactAddress = prefs.getBool(_kShowExactAddress) ?? false;
      _loaded = true;
    });
  }

  Future<void> _setShowExactAddress(bool value) async {
    setState(() => _showExactAddress = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowExactAddress, value);
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon.')));
  }

  Future<void> _confirmLogOut() => confirmAndLogOut(
        context,
        isLoading: _loggingOut,
        setLoading: (v) => setState(() => _loggingOut = v),
      );

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
                  const Text('Settings & privacy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('What others can see'),
                          _card([
                            _toggleRow(
                              'Show my exact address to matched donors',
                              'Off means they see a distance only — your real name and address are never shown either way',
                              _showExactAddress,
                              _setShowExactAddress,
                              isLast: true,
                            ),
                          ]),
                          const SizedBox(height: 18),
                          _sectionLabel('Your data'),
                          _card([
                            _actionRow('Download my data', onTap: () => _comingSoon('Data export')),
                            _actionRow('Log out', onTap: _confirmLogOut, isLast: true, trailing: _loggingOut ? _smallSpinner() : null),
                          ]),
                          const SizedBox(height: 24),
                          const Text('DANGER ZONE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.ink2)),
                          const SizedBox(height: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _comingSoon('Account deletion'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(border: Border.all(color: AppColors.red300), borderRadius: BorderRadius.circular(12)),
                              child: const Row(
                                children: [
                                  Expanded(child: Text('Delete my account', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.red700))),
                                  Text('Not yet available', style: TextStyle(fontSize: 11.5, color: AppColors.red700)),
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

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.ink2)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _toggleRow(String label, String? subtitle, bool value, ValueChanged<bool> onChanged, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.warmDivider))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.disabledTint)),
                ],
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _actionRow(String label, {required VoidCallback onTap, bool isLast = false, Widget? trailing}) {
    return InkWell(
      onTap: trailing != null ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.warmDivider))),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimaryWarm))),
            trailing ?? const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.chevronMuted),
          ],
        ),
      ),
    );
  }

  Widget _smallSpinner() => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
}
