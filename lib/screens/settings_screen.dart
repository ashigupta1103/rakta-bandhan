import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/account_service.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/logout_flow.dart';
import '../widgets/urgent_alert_toggle.dart';
import 'legal_reader_screen.dart';
import 'login_screen.dart';

/// Settings & privacy — grouped rows, one destructive treatment.
///
/// - What others can see: the exact-address toggle (device-local via
///   SharedPreferences — there is no donors/{uid} field for it).
/// - Alerts: the opt-in urgent-request ring (same field as My Page).
/// - Your data: a JSON export of everything stored (DPDP right to access).
/// - Legal: Privacy policy and Terms of use.
/// - Delete account: real, in-app deletion (App Store 5.1.1(v) and Google
///   Play both require it) — see AccountService for exactly what is removed.
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
  bool _deleting = false;

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

  bool _exporting = false;

  Future<void> _downloadData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    String json;
    try {
      json = await AccountService.instance.exportMyData();
    } catch (_) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not prepare your data. Check your connection and try again.')));
      return;
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * 0.8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Your data', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 4),
                const Text('Everything stored against your account, as JSON. Copy it to keep a record.', style: TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.4)),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(12)),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(json, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: AppColors.ink, height: 1.4)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: json));
                    if (!sheet.mounted) return;
                    Navigator.pop(sheet);
                    messenger.showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
                  },
                  icon: const Icon(LucideIcons.clipboardList, size: 16),
                  label: const Text('Copy all'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Delete your account permanently?',
      message:
          'Your profile, public listing, ID photo and every message you sent are deleted. Open requests you raised are cancelled; a request you accepted goes back to other donors. This can’t be undone.',
      confirmLabel: 'Delete my account',
      cancelLabel: 'Keep my account',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await AccountService.instance.deleteMyAccount();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account has been deleted.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not finish deleting your account. Check your connection and try again — nothing is lost by retrying.')),
      );
    }
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
                          _sectionLabel('Alerts'),
                          _card([const UrgentAlertToggle(asCard: false)]),
                          const SizedBox(height: 18),
                          _sectionLabel('Your data'),
                          _card([
                            _actionRow('Download my data', onTap: _downloadData, trailing: _exporting ? _smallSpinner() : null),
                            _actionRow('Log out', onTap: _confirmLogOut, isLast: true, trailing: _loggingOut ? _smallSpinner() : null),
                          ]),
                          const SizedBox(height: 18),
                          _sectionLabel('Legal'),
                          _card([
                            _actionRow('Privacy policy', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalReaderScreen.privacy()))),
                            _actionRow('Terms of use', isLast: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalReaderScreen.terms()))),
                          ]),
                          const SizedBox(height: 24),
                          _sectionLabel('Delete account'),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _deleting ? null : _deleteAccount,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(border: Border.all(color: AppColors.red300), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  const Expanded(child: Text('Delete my account', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.red700))),
                                  if (_deleting) _smallSpinner() else const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.red300),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text('Permanent. You can register again later with the same number as a new donor.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4)),
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
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink2)),
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
