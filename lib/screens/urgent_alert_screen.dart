import 'dart:async';

import 'package:flutter/material.dart';

import '../services/alert_sound.dart';
import '../services/urgent_alert_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/pulsing_dot.dart';
import 'request_detail_screen.dart';

/// The opt-in urgent-request takeover — a ride-request style ping: full
/// screen, chiming and buzzing, one obvious action, gone by itself in
/// [_window] if nobody picks the phone up. The thin bar at the bottom is
/// the only constant motion (linear — it's a clock, not a flourish).
class UrgentAlertScreen extends StatefulWidget {
  final UrgentAlert alert;

  const UrgentAlertScreen({super.key, required this.alert});

  @override
  State<UrgentAlertScreen> createState() => _UrgentAlertScreenState();
}

class _UrgentAlertScreenState extends State<UrgentAlertScreen> with SingleTickerProviderStateMixin {
  static const _window = Duration(seconds: 45);
  late final AnimationController _countdown = AnimationController(vsync: this, duration: _window);
  bool _leaving = false;

  UrgentAlert get alert => widget.alert;

  @override
  void initState() {
    super.initState();
    AlertSound.urgentRequest.start();
    _countdown.forward().whenComplete(() => _leave());
  }

  @override
  void dispose() {
    AlertSound.urgentRequest.stop();
    _countdown.dispose();
    super.dispose();
  }

  void _leave({bool open = false}) {
    if (_leaving || !mounted) return;
    _leaving = true;
    AlertSound.urgentRequest.stop();
    if (open) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: alert.requestId)));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final critical = alert.urgency == 'critical';
    final km = alert.distanceKm < 1 ? '< 1 km' : '${alert.distanceKm.toStringAsFixed(1)} km';
    final place = alert.locationLabel.split(',').take(2).join(',').trim();

    return Scaffold(
      backgroundColor: AppColors.gradientEmberEnd,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.25, -1),
            end: Alignment(0.25, 1),
            colors: [AppColors.gradientEmberStart, AppColors.gradientEmberMid, AppColors.gradientEmberEnd],
            stops: [0, 0.6, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PulsingDot(color: AppColors.onEmberAccent, size: 8),
                  const SizedBox(width: 9),
                  Text(
                    critical ? 'Critical request nearby' : 'Urgent request nearby',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onEmberEyebrow),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BloodGroupDroplet(label: alert.bloodGroup, size: 96, filled: true, color: AppColors.brandRed, textColor: AppColors.onEmber, fontSize: 30, serif: true),
                      const SizedBox(height: 26),
                      Text(
                        '${alert.bloodGroup} needed,\n$km away',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.display(fontSize: 32, color: AppColors.onEmberStrong, height: 1.15),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${alert.units} unit${alert.units == 1 ? '' : 's'}${place.isEmpty ? '' : ' · $place'}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: AppColors.onEmberMuted, height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your blood group can help. First donor to accept is matched.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: AppColors.onEmberFaint, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warmPageBackground,
                        foregroundColor: AppColors.gradientEmberMid,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _leave(open: true),
                      child: const Text('View request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => _leave(),
                      child: const Text('Not now', style: TextStyle(fontSize: 14, color: AppColors.onEmberMuted)),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: AnimatedBuilder(
                        animation: _countdown,
                        builder: (context, _) => LinearProgressIndicator(
                          value: 1 - _countdown.value,
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(AppColors.onEmber.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You get these because urgent alerts are on. Turn them off anytime in My Page.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4), height: 1.4),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
