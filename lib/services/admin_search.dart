/// The same query choices used by the web console. Prefixes are indexed,
/// never a scan of the first page. Phone and email lookups are exact.
({String field, String value, bool prefix}) adminDonorSearch(String input) {
  final value = input.trim().toLowerCase();
  if (value.startsWith('@')) return (field: 'username', value: value.substring(1), prefix: true);
  if (value.contains('@')) return (field: 'email', value: value, prefix: false);
  final digits = value.replaceAll(RegExp(r'[\s+()-]'), '');
  if (RegExp(r'^(91)?[6-9]\d{9}$').hasMatch(digits)) {
    return (field: 'phone', value: digits.length == 12 ? digits.substring(2) : digits, prefix: false);
  }
  return (field: 'name_lower', value: value, prefix: true);
}
