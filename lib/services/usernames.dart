const reservedUsernames = {
  'admin',
  'administrator',
  'support',
  'help',
  'rakta',
  'bandhan',
  'raktabandhan',
  'rotary',
  'official',
  'team',
  'moderator',
  'system',
  'root',
  'null',
  'undefined',
};

String? validateUsername(String name) {
  if (!RegExp(r'^[a-z][a-z0-9_]{2,19}$').hasMatch(name)) {
    return 'Use 3–20 lowercase letters, numbers or _. Start with a letter.';
  }
  if (reservedUsernames.contains(name)) return 'That username is reserved. Choose another.';
  return null;
}

List<String> suggestUsernames(String name) {
  var base = name.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '');
  if (base.isEmpty || !RegExp('^[a-z]').hasMatch(base)) base = 'donor$base';
  if (base.length > 16) base = base.substring(0, 16);
  if (base.length < 3 || reservedUsernames.contains(base)) base = '${base}donor';
  return [
    for (final suffix in ['21', '42', '108']) '$base$suffix',
  ];
}

DateTime? usernameChangeAllowedAt(DateTime? changedAt) => changedAt?.add(const Duration(days: 30));
