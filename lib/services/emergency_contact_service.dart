import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class EmergencyContact {
  final String name;
  final String relationship;
  final String phone;

  const EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
  });

  bool get isEmpty => name.trim().isEmpty && phone.trim().isEmpty;
}

/// Emergency contact storage.
///
/// MISSING BACKEND BOUNDARY — the donor schema written by
/// `Backend.registerDonor` has no emergency-contact field, and no
/// update-profile method exists. The backend developer should add an
/// `emergency_contact` map to `donors/{uid}` plus:
///
///   Future<EmergencyContact?> getEmergencyContact();
///   Future<void> setEmergencyContact(EmergencyContact contact);
///
/// then swap the implementation below. Stored device-locally until then —
/// the screen states this to the user rather than implying it is synced.
abstract class EmergencyContactService {
  Future<EmergencyContact?> load();
  Future<void> save(EmergencyContact contact);
  Future<void> clear();
}

class MockEmergencyContactService implements EmergencyContactService {
  static const _kName = 'rb_ec_name';
  static const _kRelationship = 'rb_ec_relationship';
  static const _kPhone = 'rb_ec_phone';

  @override
  Future<EmergencyContact?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName);
    final phone = prefs.getString(_kPhone);
    if (name == null || phone == null) return null;
    return EmergencyContact(
      name: name,
      relationship: prefs.getString(_kRelationship) ?? '',
      phone: phone,
    );
  }

  @override
  Future<void> save(EmergencyContact contact) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, contact.name);
    await prefs.setString(_kRelationship, contact.relationship);
    await prefs.setString(_kPhone, contact.phone);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kName);
    await prefs.remove(_kRelationship);
    await prefs.remove(_kPhone);
  }
}
