import 'package:flutter_test/flutter_test.dart';
import 'package:twake_chat/modules/brancardage/create_transport_request.dart';
import 'package:twake_chat/modules/brancardage/transport_locations.dart';

void main() {
  test('Dates calendaires : bissextile, impossible, future et format', () {
    expect(validateBirthDate('29/02/2024'), isNull);
    expect(validateBirthDate('29/02/2023'), isNotNull);
    expect(validateBirthDate('31/04/1975'), isNotNull);
    expect(validateBirthDate('01/01/2999'), isNotNull);
    expect(validateBirthDate('1975-03-24'), isNotNull);
    expect(validCalendarDate('2026-10-12', iso: true), isTrue);
  });
  test(
    'Référentiel fourni : sous-zones rattachées et recherche sans accents',
    () {
      expect(transportLocations.length, 3);
      final ids = transportLocations.map((p) => p['id']).toSet();
      expect(ids.length, 3);
      for (final place in transportLocations.where(
        (p) => p.containsKey('parent_id'),
      )) {
        expect(ids.contains(place['parent_id']), isTrue);
      }
      expect(normalizeLocation('Démonstration'), 'demonstration');
      expect(
        transportLocations.any((p) => p['full_name']!.contains('Demo room')),
        isTrue,
      );
      expect(
        transportLocations.any(
          (p) => p['full_name']!.contains('Demo service B'),
        ),
        isTrue,
      );
    },
  );
}
