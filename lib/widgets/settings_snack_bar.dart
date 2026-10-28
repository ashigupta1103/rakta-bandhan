import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// A message with an "Open settings" button. Used when a permission is still
/// off after asking: once a person has refused, the phone stops showing its
/// own dialog, so the app's settings page is the only way to turn it on.
SnackBar openSettingsSnackBar(String message) => SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(label: 'Open settings', onPressed: () => Geolocator.openAppSettings()),
    );
