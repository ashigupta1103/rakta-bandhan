import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/screens/community_screen.dart';
import 'package:rakta_bandhan/services/maps_link.dart';
import 'package:rakta_bandhan/services/phone_privacy.dart';

void main() {
  group('maskPhone', () {
    test('shows only the last three digits', () {
      expect(maskPhone('9876543940'), '•••••• •940');
      expect(maskPhone('+91 98765 43940'), '•••••• •940');
    });

    test('never leaks more than three digits', () {
      final masked = maskPhone('+919876543940');
      expect(RegExp(r'\d').allMatches(masked).length, 3);
    });

    test('short or missing numbers show no digits', () {
      expect(maskPhone(null), '••••••');
      expect(maskPhone(''), '••••••');
      expect(maskPhone('12'), '••••••');
    });
  });

  test('mapsUri opens the stored point in Google Maps', () {
    final uri = mapsUri(13.0827, 80.2707);
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], '13.0827,80.2707');
  });

  test('no user-facing screen dials or reveals a phone number', () {
    // Admin screens are excluded: they are not reachable from the app shell.
    final files = [
      ...Directory('lib/screens').listSync(),
      ...Directory('lib/widgets').listSync(),
    ].whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.contains('admin_'));
    final banned = [
      RegExp(r"scheme:\s*'tel'"),
      RegExp(r"'tel:"),
      RegExp(r'Their phone'),
      RegExp(r'call their phone', caseSensitive: false),
      RegExp(r'peerPhone'),
    ];
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final re in banned) {
        expect(re.hasMatch(src), isFalse, reason: '${f.path} matches ${re.pattern}');
      }
    }
  });

  group('communityLoadErrorMessage', () {
    test('permission errors do not blame the connection', () {
      final msg = communityLoadErrorMessage(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      expect(msg, contains('Sign out'));
    });

    test('network errors ask to check the connection', () {
      final msg = communityLoadErrorMessage(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
      expect(msg, contains('connection'));
    });

    test('unknown errors get a generic message', () {
      expect(communityLoadErrorMessage(StateError('x')), contains('Something went wrong'));
    });
  });
}
