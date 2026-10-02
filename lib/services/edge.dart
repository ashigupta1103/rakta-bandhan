import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Photos and TURN only. Email sign-in stays on Functions after Blaze.
const kEdgeUrl = String.fromEnvironment('EDGE_URL');

String newMediaName() {
  final random = Random.secure();
  const letters = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return '${List.generate(24, (_) => letters[random.nextInt(letters.length)]).join()}.jpg';
}

String edgeErrorCode(int status) => switch (status) {
  400 || 413 || 415 => 'invalid-argument',
  401 => 'unauthenticated',
  403 => 'permission-denied',
  404 => 'not-found',
  429 => 'resource-exhausted',
  _ => 'unavailable',
};

/// Injected HTTP/token readers keep tests independent of Firebase singletons.
class EdgeClient {
  EdgeClient({String baseUrl = kEdgeUrl, http.Client? client, Future<String?> Function()? tokenProvider})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client(),
      _tokenProvider = tokenProvider ?? (() async => FirebaseAuth.instance.currentUser?.getIdToken());

  final String _baseUrl;
  final http.Client _client;
  final Future<String?> Function() _tokenProvider;

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, Object?>? jsonBody,
    List<int>? bytes,
    String? contentType,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final base = Uri.tryParse(_baseUrl);
    if (base == null ||
        base.host.isEmpty ||
        !['https', 'http'].contains(base.scheme) ||
        (base.scheme == 'http' && !['localhost', '127.0.0.1', '10.0.2.2', '::1'].contains(base.host)) ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        !path.startsWith('/') ||
        path.startsWith('//')) {
      throw FirebaseFunctionsException(code: 'unavailable', message: 'Photo storage and call relay are not set up yet.');
    }
    try {
      return await (() async {
        final token = await _tokenProvider();
        if (token == null || token.isEmpty) {
          throw FirebaseFunctionsException(code: 'unauthenticated', message: 'Sign in first.');
        }
        final req = http.Request(method, Uri.parse('$_baseUrl$path'));
        req.headers['authorization'] = 'Bearer $token';
        if (jsonBody != null) {
          req.headers['content-type'] = 'application/json';
          req.body = jsonEncode(jsonBody);
        } else if (bytes != null) {
          req.headers['content-type'] = contentType ?? 'image/jpeg';
          req.bodyBytes = bytes;
        }
        final res = await http.Response.fromStream(await _client.send(req));
        if (res.statusCode >= 200 && res.statusCode < 300) return res;
        String? message;
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['error'] is String) {
            message = body['error'] as String;
          }
        } catch (_) {}
        throw FirebaseFunctionsException(code: edgeErrorCode(res.statusCode), message: message ?? 'Something went wrong. Try again.');
      })().timeout(timeout);
    } on TimeoutException {
      throw FirebaseFunctionsException(code: 'unavailable', message: 'The connection timed out. Try again.');
    } on http.ClientException {
      throw FirebaseFunctionsException(code: 'unavailable', message: 'Check your connection and try again.');
    }
  }

  Future<Map<String, dynamic>> json(
    String method,
    String path, {
    Map<String, Object?>? body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final res = await request(method, path, jsonBody: body, timeout: timeout);
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    throw FirebaseFunctionsException(code: 'unavailable', message: 'The server returned an unreadable response. Try again.');
  }

  Future<void> deleteMedia(String path) async {
    try {
      await request('DELETE', '/media/$path');
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found') rethrow;
    }
  }
}
