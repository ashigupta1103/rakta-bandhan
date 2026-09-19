import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rakta Bandhan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // The final artifact's shell is a fixed ~430px mobile composition,
      // centred on wide viewports rather than stretched full-width. This
      // must live in MaterialApp.builder (wrapping the Navigator's output),
      // not inside a single screen — a screen-local wrap only covers that
      // screen's own route; every screen reached via Navigator.push renders
      // as its own top-level route and would bypass a wrap placed anywhere
      // lower in the tree.
      builder: (context, child) {
        if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();
        return ColoredBox(
          color: AppColors.warmPageBackground,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: child,
            ),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
