import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/services/usernames.dart';

void main() {
  test('username format and reserved words match the rules contract', () {
    for (final name in ['ab', 'Upper', '1abc', '_abc', 'a b', 'a-b', 'admin', 'raktabandhan', 'a' * 21]) {
      expect(validateUsername(name), isNotNull, reason: name);
    }
    for (final name in ['abc', 'a_b', 'donor108', 'a' * 20]) {
      expect(validateUsername(name), isNull, reason: name);
    }
  });
  test('suggestions remain valid for empty, numeric, reserved and long names', () {
    for (final name in ['', '123', 'Admin', 'தமிழ்', 'a' * 100, 'Priya Kumar']) {
      final names = suggestUsernames(name);
      expect(names.length, 3);
      expect(names.toSet().length, 3);
      expect(names.every((n) => validateUsername(n) == null), isTrue, reason: name);
    }
  });
}
