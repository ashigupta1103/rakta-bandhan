import 'package:flutter/material.dart';
import '../services/backend.dart';
import 'main_navigation_screen.dart';
import 'registration_screen.dart';
import 'username_screen.dart';

/// Where a signed-in account goes next: registration, then the username
/// choice, then the app. Shared by the launch screen and every sign-in screen.
Future<Widget> signedInDestination() async {
  try {
    final profile = await Backend.instance.myDonorDoc();
    if (!profile.exists) return const RegistrationScreen();
    if (profile.data()?['username'] == null) return const UsernameScreen(requiredChoice: true);
    return const MainNavigationScreen();
  } catch (_) {
    // Offline at launch: Firestore's cache usually answers; if it can't,
    // open the app rather than strand the user on the splash.
    return const MainNavigationScreen();
  }
}
