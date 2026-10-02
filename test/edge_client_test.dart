import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakta_bandhan/services/edge.dart';

void main() {
  test('sends a bearer token and raw photo bytes to the configured Worker', () async {
    final edge = EdgeClient(
      baseUrl: 'https://edge.example/',
      tokenProvider: () async => 'id-token',
      client: MockClient((req) async {
        expect(req.url.toString(), 'https://edge.example/media/id_proofs/u1/proof.jpg');
        expect(req.headers['authorization'], 'Bearer id-token');
        expect(req.headers['content-type'], 'image/jpeg');
        expect(req.bodyBytes, [255, 216, 255]);
        return http.Response(jsonEncode({'path': 'id_proofs/u1/proof.jpg'}), 201);
      }),
    );
    expect((await edge.request('PUT', '/media/id_proofs/u1/proof.jpg', bytes: [255, 216, 255])).statusCode, 201);
  });

  test('maps Worker HTTP errors without exposing raw response content', () async {
    for (final status in [400, 413, 415, 401, 403, 404, 429, 500, 503]) {
      final edge = EdgeClient(
        baseUrl: 'https://edge.example',
        tokenProvider: () async => 'token',
        client: MockClient((_) async => http.Response('{"error":"Try again."}', status)),
      );
      await expectLater(
        edge.json('POST', '/ice', body: {'requestId': 'r1'}),
        throwsA(
          isA<FirebaseFunctionsException>()
              .having((e) => e.code, 'code', edgeErrorCode(status))
              .having((e) => e.message, 'message', 'Try again.'),
        ),
      );
    }
  });

  test('timeouts, absent setup, malformed responses and signed-out calls fail clearly', () async {
    final pending = Completer<http.Response>();
    final edge = EdgeClient(baseUrl: 'https://edge.example', tokenProvider: () async => 'token', client: MockClient((_) => pending.future));
    await expectLater(
      edge.json('POST', '/ice', timeout: const Duration(milliseconds: 10)),
      throwsA(isA<FirebaseFunctionsException>().having((e) => e.code, 'code', 'unavailable')),
    );
    pending.complete(http.Response('{}', 200));
    await expectLater(EdgeClient(baseUrl: '').json('POST', '/ice'), throwsA(isA<FirebaseFunctionsException>()));
    await expectLater(EdgeClient(baseUrl: 'http://edge.example').json('POST', '/ice'), throwsA(isA<FirebaseFunctionsException>()));
    final signedOut = EdgeClient(baseUrl: 'https://edge.example', tokenProvider: () async => null);
    await expectLater(
      signedOut.json('POST', '/ice'),
      throwsA(isA<FirebaseFunctionsException>().having((e) => e.code, 'code', 'unauthenticated')),
    );
    final malformed = EdgeClient(
      baseUrl: 'https://edge.example',
      tokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    await expectLater(malformed.json('POST', '/ice'), throwsA(isA<FirebaseFunctionsException>()));
  });

  test('media names are fresh JPEG names accepted by the Worker', () {
    final names = List.generate(100, (_) => newMediaName());
    expect(names.toSet().length, names.length);
    expect(names.every((s) => RegExp(r'^[A-Za-z0-9_-]{4,80}\.jpg$').hasMatch(s)), isTrue);
  });
}
