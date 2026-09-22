import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';

/// Single logout confirmation + sign-out flow shared by every screen that
/// exposes a "Log out" action (Settings, My Page) — one dialog, one
/// duplicate-tap guard, one real Backend.instance.signOut() call, so the
/// two screens can never drift into different behaviors again.
///
/// [isLoading] lets the caller show its own inline spinner state; pass the
/// current value and a setter. Confirming shows the dialog; only a
/// confirmed tap ever signs the user out.
Future<void> confirmAndLogOut(
  BuildContext context, {
  required bool isLoading,
  required ValueChanged<bool> setLoading,
}) async {
  if (isLoading) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You’ll need to sign in again next time you open Rakta Bandhan.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Log out', style: TextStyle(color: AppColors.red700)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  setLoading(true);
  try {
    await Backend.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  } catch (_) {
    if (!context.mounted) return;
    setLoading(false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't log out — check your connection and try again.")),
    );
  }
}
