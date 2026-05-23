import 'dart:async';
import 'dart:convert';

import 'package:art_assistant/core/api/backend_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('BackendApiClient', () {
    test('sendText returns backend reply', () async {
      final client = BackendApiClient(
        baseUrl: 'http://backend.test',
        client: _FakeClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/chat');
          final body = jsonDecode((request as http.Request).body);
          expect(body['message'], '你好');

          return http.Response(
            jsonEncode({'ok': true, 'reply': '收到'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final reply = await client.sendText('你好');

      expect(reply, '收到');
    });

    test('sendText throws when backend returns ok=false', () async {
      final client = BackendApiClient(
        baseUrl: 'http://backend.test',
        client: _FakeClient((request) async {
          return http.Response(
            jsonEncode({'ok': false, 'error': 'message is required'}),
            200,
          );
        }),
      );

      await expectLater(client.sendText(''), throwsA(isA<StateError>()));
    });

    test('sendText throws when JSON root is not an object', () async {
      final client = BackendApiClient(
        baseUrl: 'http://backend.test',
        client: _FakeClient((request) async {
          return http.Response(jsonEncode(['bad']), 200);
        }),
      );

      await expectLater(
        client.sendText('hello'),
        throwsA(isA<FormatException>()),
      );
    });

    test('upsertUser sends identity and returns membership tier', () async {
      final client = BackendApiClient(
        baseUrl: 'http://backend.test',
        client: _FakeClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/users/upsert');
          final body = jsonDecode((request as http.Request).body);
          expect(body['userId'], 'local_anon_1');
          expect(body['studentName'], '我');

          return http.Response(
            jsonEncode({
              'ok': true,
              'user': {'id': 'local_anon_1', 'membershipTier': 'pro'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final user = await client.upsertUser(
        userId: 'local_anon_1',
        studentName: '我',
      );

      expect(user.id, 'local_anon_1');
      expect(user.membershipTier, 'pro');
    });

    test(
      'fetchUserProfile returns current identity and membership summary',
      () async {
        final client = BackendApiClient(
          baseUrl: 'http://backend.test',
          client: _FakeClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/users/local_anon_1/profile');

            return http.Response(
              jsonEncode({
                'ok': true,
                'profile': {
                  'user': {'id': 'local_anon_1', 'membershipTier': 'free'},
                  'stats': {'artworkCount': 3},
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final profile = await client.fetchUserProfile(userId: 'local_anon_1');

        expect(profile.userId, 'local_anon_1');
        expect(profile.membershipTier, 'free');
        expect(profile.artworkCount, 3);
      },
    );
  });
}

class _FakeClient extends http.BaseClient {
  final FutureOr<http.Response> Function(http.BaseRequest request) handler;

  _FakeClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      request: request,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
