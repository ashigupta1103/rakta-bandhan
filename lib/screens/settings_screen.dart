import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import '../services/account_service.dart';
import '../services/backend.dart';
import '../services/features.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/logout_flow.dart';
import '../widgets/rb_ui.dart';
import '../widgets/urgent_alert_toggle.dart';
import 'legal_reader_screen.dart';
import 'login_screen.dart';
import '../widgets/rb_icon.dart';

/// Settings & privacy — same grouped rows as My Page, one destructive
/// treatment.
///
/// - Notifications: the opt-in urgent-request ring (same field as My Page)
///   and a shortcut to the phone's own notification settings.
/// - What others can see: a plain statement of what is and isn't shared.
///   (An old "show my exact address" switch was removed — it was saved on
///   the device but nothing ever read it.)
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
  bool _loggingOut = false;
  bool _deleting = false;

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
                  icon: const RbIcon(RbGlyph.clipboard, size: 16),
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
    String? password;
    if (!kEmailCodeLive) {
      password = await _askPassword();
      if (password == null || !mounted) return;
    }
    setState(() => _deleting = true);
    try {
      await AccountService.instance.deleteMyAccount(password: password);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account has been deleted.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      // A wrong password is caught before anything is deleted.
      final wrongPassword = e is FirebaseAuthException && const {'wrong-password', 'invalid-credential', 'user-mismatch'}.contains(e.code);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(wrongPassword
            ? Backend.authErrorMessage(e)
            : 'Could not finish deleting your account. Check your connection and try again — nothing is lost by retrying.'),
      ));
    }
  }

  /// Password sign-in only: Firebase wants a recent sign-in before it lets
  /// an account be deleted.
  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter your password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: 'Your password'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Delete account', style: TextStyle(color: AppColors.red700)),
          ),
        ],
      ),
    );
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
      appBar: AppBar(
        backgroundColor: AppColors.warmPageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const RbIcon(RbGlyph.back, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings & privacy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const RbSectionLabel('Notifications', padding: EdgeInsets.fromLTRB(2, 8, 2, 10)),
          RbListGroup(
            children: [
              const UrgentAlertToggle(asCard: false),
              RbRow(
                icon: RbGlyph.bell,
                tone: RbTone.gold,
                title: 'Phone notifications',
                subtitle: 'Messages, calls and nearby requests. Sound and banners are managed in your phone’s settings.',
                trailing: const RbIcon(RbGlyph.forward, size: 15, color: AppColors.chevronMuted),
                onTap: () => Geolocator.openAppSettings(),
              ),
            ],
          ),
          const RbSectionLabel('What others can see'),
          RbCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              children: [
                _privacyLine(RbGlyph.hangUp, 'Your phone number', 'Never shown to anyone. You see only its last three digits.'),
                _privacyLine(RbGlyph.pin, 'Your location', 'Others see your neighbourhood, rounded to about 1 km — never an exact address.'),
                _privacyLine(RbGlyph.photo, 'Your profile photo', 'Visible only to you.'),
                _privacyLine(RbGlyph.idCard, 'Your ID proof', 'Seen only by the verification team, then deleted.'),
                _privacyLine(RbGlyph.message, 'Chats and calls', 'Only between you and the person you’re matched with. Calls are never recorded.'),
              ],
            ),
          ),
          const RbSectionLabel('Your data'),
          RbListGroup(
            children: [
              RbRow(
                icon: RbGlyph.download,
                title: 'Download my data',
                subtitle: 'Everything stored against your account',
                onTap: _exporting ? null : _downloadData,
                trailing: _exporting ? _smallSpinner() : null,
              ),
              RbRow(
                icon: RbGlyph.logout,
                tone: RbTone.neutral,
                title: 'Log out',
                onTap: _loggingOut ? null : _confirmLogOut,
                trailing: _loggingOut ? _smallSpinner() : null,
              ),
            ],
          ),
          const RbSectionLabel('Legal'),
          RbListGroup(
            children: [
              RbRow(icon: RbGlyph.shield, tone: RbTone.neutral, title: 'Privacy policy', onTap: () => _open(const LegalReaderScreen.privacy())),
              RbRow(icon: RbGlyph.page, tone: RbTone.neutral, title: 'Terms of use', onTap: () => _open(const LegalReaderScreen.terms())),
              RbRow(icon: RbGlyph.community, tone: RbTone.neutral, title: 'Community guidelines', onTap: () => _open(const LegalReaderScreen.guidelines())),
            ],
          ),
          const RbSectionLabel('Delete account'),
          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.red200), borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: RbRow(
              icon: RbGlyph.trash,
              destructive: true,
              title: 'Delete my account',
              subtitle: 'Permanent. Your profile, listing, photos and messages are removed.',
              onTap: _deleting ? null : _deleteAccount,
              trailing: _deleting ? _smallSpinner() : null,
            ),
          ),
        ],
      ),
    );
  }

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _privacyLine(RbGlyph icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: RbIcon(icon, size: 17, color: AppColors.brandRed)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 1),
                  Text(body, style: const TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _smallSpinner() => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
}
