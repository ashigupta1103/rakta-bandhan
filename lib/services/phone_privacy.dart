/// The only way a phone number is ever rendered in the app: everything but
/// the last three digits is masked ("•••••• •940"). There is deliberately
/// no unmasked variant and no "show" action anywhere — calls and messages
/// go through the app instead.
String maskPhone(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length < 3) return '••••••';
  return '•••••• •${digits.substring(digits.length - 3)}';
}
