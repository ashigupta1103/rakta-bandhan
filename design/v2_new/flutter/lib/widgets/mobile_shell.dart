import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Constrains the app to a phone-sized frame on large viewports.
///
/// Purpose is the Flutter Web demo build: teammates open a URL on a desktop
/// browser and should see the MOBILE app, not a stretched desktop layout.
/// Every screen therefore renders at exactly the dimensions it was designed
/// for, with touch-sized controls intact.
///
/// On a real phone (or any viewport <= [breakpoint]) this is a pass-through
/// and costs nothing but a LayoutBuilder.
///
/// MediaQuery is overridden inside the frame so screens that measure the
/// viewport see the phone size rather than the browser window.
class MobileShell extends StatelessWidget {
  static const double phoneWidth = 390;
  static const double phoneHeight = 844;

  /// Below this width the browser window is already phone-shaped, so the
  /// app fills it exactly as it would on device.
  static const double breakpoint = 480;

  final Widget child;

  const MobileShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= breakpoint) return child;

        final frameHeight = math.min(phoneHeight, math.max(480.0, constraints.maxHeight - 48));

        return ColoredBox(
          color: AppColors.gradientMatchingEnd,
          child: Center(
            child: Container(
              width: phoneWidth,
              height: frameHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.45), blurRadius: 48, offset: Offset(0, 18)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(phoneWidth, frameHeight),
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                  viewInsets: EdgeInsets.zero,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
