import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/app_info.dart';

void main() {
  test('the version shown in the app matches pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.split(':')[1].trim().split('+').first, kAppVersion);
  });
}
