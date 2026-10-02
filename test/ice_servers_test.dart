import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/services/call_service.dart';

void main() {
  test('TURN entries lead, malformed entries are dropped, built-in STUN is retained', () {
    expect(mergeIceServers(null), callIceServers);
    final result = mergeIceServers([
      {
        'urls': ['turn:relay.example:3478', 'https://bad'],
        'username': 'u',
        'credential': 'p',
      },
      {'urls': 'turns:relay.example:5349', 'username': 'u', 'credential': 'p'},
      {'urls': 'turn:missing-credentials'},
      {'urls': 'stun:another.example'},
      'bad',
      null,
    ]);
    expect(result.length, 3);
    expect(result.first['urls'], ['turn:relay.example:3478']);
    expect(result.last, callIceServers.single);
  });
}
