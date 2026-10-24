import 'package:flutter_test/flutter_test.dart';
import 'package:twake_chat/data/network/contact/address_book_api.dart';

void main() {
  test(
    'ToM remains authoritative when configured, even with recipe fallback enabled',
    () {
      expect(
        AddressBookApi.resolvePath(tomConfigured: true, recipeEnabled: true),
        '/_twake/addressbook',
      );
    },
  );
  test('recipe uses its real contacts API only when explicitly enabled', () {
    expect(
      AddressBookApi.resolvePath(tomConfigured: false, recipeEnabled: true),
      endsWith('/api/contacts'),
    );
    expect(
      AddressBookApi.resolvePath(tomConfigured: false, recipeEnabled: false),
      '/_twake/addressbook',
    );
  });
}
