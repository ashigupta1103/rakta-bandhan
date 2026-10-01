import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_glyph.dart';
import '../widgets/rb_icon.dart';

class CancelConfirmScreen extends StatelessWidget {
  final String requestId;

  const CancelConfirmScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandGlyph(icon: RbGlyph.close, tone: GlyphTone.neutral, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Request cancelled',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm),
              ),
              const SizedBox(height: 8),
              const Text(
                'It no longer appears to donors or in your requests. If you still need blood later, raise a new request.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Back to home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
