import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Testimonials — curated and verified by Rakta Bandhan, distinct from the
/// anonymous-handle Community stories feed. Every quote and name here is an
/// explicit placeholder per the design ("Real testimonial copy has not
/// been supplied and has deliberately not been written").
class TestimonialsScreen extends StatelessWidget {
  const TestimonialsScreen({super.key});

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
                  IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
                  const Text('Testimonials', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stories we\'ve been given permission to tell', style: AppTextStyles.display(fontSize: 25, color: AppColors.ink, height: 1.25)),
                    const SizedBox(height: 8),
                    const Text('Curated and verified by Rakta Bandhan. Member stories live in Community.', style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                    const SizedBox(height: 20),
                    _featuredQuote(),
                    const SizedBox(height: 14),
                    _quoteCard(
                      quote: 'Placeholder quote — shorter variant, two to three lines.',
                      name: 'Name — to be supplied',
                      subtitle: 'Donor · 12 donations',
                      avatarIcon: null,
                    ),
                    const SizedBox(height: 12),
                    _quoteCard(
                      quote: 'Placeholder quote — hospital or partner voice.',
                      name: 'Partner — to be supplied',
                      subtitle: 'Hospital partner',
                      avatarIcon: LucideIcons.sparkles,
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

  Widget _featuredQuote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.shadowHero, blurRadius: 22, offset: const Offset(0, 8))]),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: -8,
            child: Text('“', style: AppTextStyles.display(fontSize: 46, color: const Color(0xFFEFCE8C), height: 1)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Placeholder quote. Real testimonial copy has not been supplied and has deliberately not been written — this frame holds four to six lines.',
                style: AppTextStyles.display(fontSize: 19, color: AppColors.ink, height: 1.6),
              ),
              const SizedBox(height: 18),
              Container(height: 1, color: AppColors.warmDivider),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.sand, shape: BoxShape.circle, border: Border.all(color: AppColors.warmBorder))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Name — to be supplied', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                        const Text('Recipient family · Chennai', style: TextStyle(fontSize: 12, color: AppColors.ink2)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(999)),
                    child: const Text('Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successText)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quoteCard({required String quote, required String name, required String subtitle, IconData? avatarIcon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quote, style: AppTextStyles.display(fontSize: 17, color: AppColors.ink, height: 1.55)),
          const SizedBox(height: 14),
          Row(
            children: [
              avatarIcon == null
                  ? Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.sand, shape: BoxShape.circle, border: Border.all(color: AppColors.warmBorder)))
                  : Container(width: 34, height: 34, decoration: const BoxDecoration(color: AppColors.goldTint, shape: BoxShape.circle), alignment: Alignment.center, child: Icon(avatarIcon, size: 15, color: AppColors.goldDeep)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
