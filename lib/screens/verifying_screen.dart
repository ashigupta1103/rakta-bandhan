import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'main_navigation_screen.dart';
import '../widgets/rb_icon.dart';

class VerifyingScreen extends StatelessWidget {
  const VerifyingScreen({super.key});

  void _continue(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppColors.warmAmberBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const RbIcon(RbGlyph.shield, size: 28, color: AppColors.warmAmberText),
              ),
              const SizedBox(height: 16),
              Text(
                'Verification pending',
                style: AppTextStyles.display(fontSize: 21, color: AppColors.textPrimaryWarm),
              ),
              const SizedBox(height: 8),
              const Text(
                "We're reviewing your details — usually within a few hours. You can browse and receive requests in the meantime; donating unlocks once verified.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.55),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _continue(context),
                  child: const Text('Continue to Rakta Bandhan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
