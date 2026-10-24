import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twake_chat/data/model/addressbook/address_book.dart';
import 'package:twake_chat/data/model/addressbook/address_book_request.dart';
import 'package:twake_chat/data/network/contact/address_book_api.dart';
import 'package:twake_chat/data/network/dio_client.dart';
import 'package:twake_chat/data/network/interceptor/dynamic_url_interceptor.dart';
import 'package:twake_chat/di/global/get_it_initializer.dart';
import 'package:twake_chat/di/global/network_di.dart';

class FixtureAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'id': '@owner:test',
        'owner': '@owner:test',
        'contacts': [
          {
            'id': '@luke:test',
            'mxid': '@luke:test',
            'display_name': 'Luke Bordeaux',
            'active': true,
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FixtureAdapter adapter;
  late DynamicUrlInterceptors interceptor;
  setUp(() async {
    await getIt.reset();
    interceptor = DynamicUrlInterceptors();
    adapter = FixtureAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(interceptor);
    getIt.registerSingleton(
      interceptor,
      instanceName: NetworkDI.tomServerUrlInterceptorName,
    );
    getIt.registerSingleton(
      DioClient(dio),
      instanceName: NetworkDI.tomDioClientName,
    );
  });
  tearDown(() => getIt.reset());
  test(
    'without ToM, enabled recipe posts and reads the real fallback path',
    () async {
      expect(
        AddressBookApi.chatPorterContactsEnabled,
        true,
        reason: 'Run with CHATPORTER_CONTACTS_ENABLED=true',
      );
      final api = AddressBookApi();
      final response = await api.updateAddressBook(
        request: AddressBookRequest(
          addressBooks: [
            AddressBook(mxid: '@luke:test', displayName: 'Luke Bordeaux'),
          ],
        ),
      );
      expect(response.addressBooks!.single.displayName, 'Luke Bordeaux');
      expect(adapter.requests.single.uri.path, '/api/contacts');
      expect(adapter.requests.single.method, 'POST');
      final read = await api.getAddressBook();
      expect(adapter.requests.last.uri.path, '/api/contacts');
      expect(adapter.requests.last.method, 'GET');
      expect(read.owner, '@owner:test');
    },
  );
  test('configured ToM retains its actual URL and response contract', () async {
    interceptor.changeBaseUrl('https://tom.example.test');
    await AddressBookApi().getAddressBook();
    expect(
      adapter.requests.single.uri.toString(),
      'https://tom.example.test/_twake/addressbook',
    );
  });
}
