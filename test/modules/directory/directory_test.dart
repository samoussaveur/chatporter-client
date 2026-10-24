import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:twake_chat/modules/brancardage/brancardage_api.dart';
import 'package:twake_chat/modules/directory/staff_directory.dart';

void main() {
  test('authenticated UTF8 search and limit are sent to the service', () async {
    final api = BrancardageApi(
      'fixture',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer fixture');
        expect(request.url.queryParameters['q'], 'Élodie');
        expect(request.url.queryParameters['limit'], '20');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'results': [
                {
                  'user_id': '@elodie:clinic.test',
                  'display_name': 'Élodie Martin',
                },
              ],
              'limited': true,
            }),
          ),
          200,
        );
      }),
    );
    final directory = StaffDirectory(api, delay: Duration.zero);
    directory.search('Élodie');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(directory.users.single.displayName, 'Élodie Martin');
    expect(directory.limited, true);
    directory.dispose();
  });
  test(
    'late results cannot overwrite a newer search or cleared search',
    () async {
      final first = Completer<http.Response>();
      final api = BrancardageApi(
        'fixture',
        client: MockClient((request) async {
          if (request.url.queryParameters['q'] == 'ancien') return first.future;
          return http.Response(
            '{"results":[{"user_id":"@new:clinic.test","display_name":"New"}],"limited":false}',
            200,
          );
        }),
      );
      final directory = StaffDirectory(api, delay: Duration.zero);
      directory.search('ancien');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      directory.search('nouveau');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      directory.search('');
      first.complete(
        http.Response(
          '{"results":[{"user_id":"@old:clinic.test"}],"limited":false}',
          200,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(directory.users, isEmpty);
      expect(directory.loading, false);
      directory.dispose();
    },
  );
  test(
    'service failure is visible and does not masquerade as no matches',
    () async {
      final api = BrancardageApi(
        'fixture',
        client: MockClient(
          (_) async => http.Response('{"error":"Annuaire indisponible"}', 503),
        ),
      );
      final directory = StaffDirectory(api, delay: Duration.zero);
      directory.search('Martin');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(directory.error, 'Annuaire indisponible');
      expect(directory.loading, false);
      directory.dispose();
    },
  );
}
