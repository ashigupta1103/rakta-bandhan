// Guards the recipient → donor compatibility table in backend.dart. Every
// matching decision (who sees a request, who gets an urgent alert) reads
// it, so a typo here silently sends requests to the wrong donors.
import 'package:flutter_test/flutter_test.dart';

import 'package:rakta_bandhan/services/backend.dart';

const _allGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

void main() {
  test('table covers exactly the eight ABO/Rh groups, with valid donor groups only', () {
    expect(bloodCompatibility.keys.toSet(), _allGroups.toSet());
    for (final donors in bloodCompatibility.values) {
      expect(_allGroups.toSet().containsAll(donors), isTrue, reason: 'unknown donor group in $donors');
      expect(donors.toSet().length, donors.length, reason: 'duplicate donor group in $donors');
    }
  });

  test('everyone can receive their own group and O-', () {
    for (final recipient in _allGroups) {
      expect(bloodCompatibility[recipient], contains(recipient));
      expect(bloodCompatibility[recipient], contains('O-'));
    }
  });

  test('universal donor and universal recipient', () {
    expect(bloodCompatibility['O-'], ['O-']);
    expect(bloodCompatibility['AB+']!.toSet(), _allGroups.toSet());
  });

  test('Rh-negative recipients never receive Rh-positive blood', () {
    for (final recipient in _allGroups.where((g) => g.endsWith('-'))) {
      expect(bloodCompatibility[recipient]!.where((d) => d.endsWith('+')), isEmpty, reason: recipient);
    }
  });
}
