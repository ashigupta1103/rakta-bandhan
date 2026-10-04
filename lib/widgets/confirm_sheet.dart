import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Destructive-action confirmation as a bottom sheet (ported from
/// design/v2_new/flutter). A sheet rather than an AlertDialog so confirmations
/// sit inside the mobile composition; one solid action, the escape hatch is
/// plain text. Returns true only if the user taps the confirm action.
class ConfirmSheet {
  ConfirmSheet._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Keep it',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
              const SizedBox(height: 6),
              Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.pop(sheetContext, true), child: Text(confirmLabel)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: Text(cancelLabel),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}
