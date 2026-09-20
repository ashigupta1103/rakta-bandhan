import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../widgets/state_card.dart';
import 'verifying_screen.dart';

/// Explicit location-permission ask, shown once right after signup
/// (Consent → here → Verifying) rather than leaving the first ask to
/// happen silently whenever the donor first opens the Find tab. Never
/// blocks onboarding — "Not now" and a failed/denied request both fall
/// through to VerifyingScreen exactly the same as Allow does.
class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _requesting = false;

  Future<void> _allow() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    await Backend.instance.currentPosition();
    _continue();
  }

  void _continue() {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const VerifyingScreen()));
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
              StateCard.permission(
                title: 'Allow location access',
                message: 'Rakta Bandhan uses your location to show nearby donors and requests, and to fill in your area automatically. You can change this anytime in your phone settings.',
                actionLabel: _requesting ? 'Requesting…' : 'Allow location access',
                onAction: _allow,
              ),
              TextButton(
                onPressed: _requesting ? null : _continue,
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
