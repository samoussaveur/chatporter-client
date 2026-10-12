import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:twake_chat/modules/brancardage/brancardage_api.dart';

void main() {
  test('French patient locations and names retain UTF-8 characters', () async {
    final api = BrancardageApi(
      'fixture',
      client: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'origin': 'Démonstration — exemple fictif',
              'author': 'Brancardier · Recette',
            }),
          ),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(api.close);
    final response = await api.call('requests/fixture');
    expect(response['origin'], 'Démonstration — exemple fictif');
    expect(response['author'], 'Brancardier · Recette');
  });
  test(
    'the server refusal is preserved without reporting a successful assignment',
    () async {
      final api = BrancardageApi(
        'fixture-token',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer fixture-token');
          expect(jsonDecode(request.body)['expected_version'], 1);
          return http.Response.bytes(
            utf8.encode(jsonEncode({'error': 'Déjà affectée'})),
            409,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.call('requests/fixture/actions', body: {'expected_version': 1}),
        throwsA(
          isA<BrancardageFailure>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message, 'message', 'Déjà affectée'),
        ),
      );
    },
  );
  test('each API instance uses only its own Matrix identity', () async {
    final identities = <String?>[];
    http.Client client() => MockClient((request) async {
      identities.add(request.headers['Authorization']);
      return http.Response('{"items":[]}', 200);
    });
    final first = BrancardageApi('first-fixture', client: client());
    final second = BrancardageApi('second-fixture', client: client());
    addTearDown(first.close);
    addTearDown(second.close);
    await first.call('requests');
    await second.call('requests');
    expect(identities, ['Bearer first-fixture', 'Bearer second-fixture']);
  });
  test(
    'a lost response can be retried with the same operation identity',
    () async {
      final operations = <String>[];
      var count = 0;
      final api = BrancardageApi(
        'fixture',
        client: MockClient((request) async {
          operations.add(jsonDecode(request.body)['operation_id'] as String);
          if (count++ == 0) throw http.ClientException('Offline');
          return http.Response('{"id":"same-request"}', 200);
        }),
      );
      addTearDown(api.close);
      final body = {
        'operation_id': 'retained-operation',
        'text': 'Fictitious message',
      };
      await expectLater(
        api.call('requests/fixture/messages', body: body),
        throwsA(isA<http.ClientException>()),
      );
      expect(
        (await api.call('requests/fixture/messages', body: body))['id'],
        'same-request',
      );
      expect(operations, ['retained-operation', 'retained-operation']);
    },
  );
}
