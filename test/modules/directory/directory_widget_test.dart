import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:twake_chat/modules/brancardage/brancardage_api.dart';
import 'package:twake_chat/modules/directory/staff_directory.dart';
import 'package:twake_chat/modules/directory/staff_directory_section.dart';

void main() {
  testWidgets(
    'person name and identifier open the same contact on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = StaffDirectory(
        BrancardageApi(
          'fixture',
          client: MockClient(
            (_) async => http.Response('{"results":[],"limited":false}', 200),
          ),
        ),
      );
      addTearDown(directory.dispose);
      directory.query = 'Camille';
      directory.users = [
        const StaffMember('@camille:example.test', 'Camille Exemple'),
      ];
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffDirectorySection(
              directory: directory,
              onTap: (person) => selected = person.id,
            ),
          ),
        ),
      );
      expect(find.text('Personnel de l’établissement'), findsOneWidget);
      expect(find.text('Camille Exemple'), findsOneWidget);
      expect(find.text('@camille:example.test'), findsOneWidget);
      await tester.tap(find.text('Camille Exemple'));
      expect(selected, '@camille:example.test');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty query hides the directory and a failure offers retry', (
    tester,
  ) async {
    final directory = StaffDirectory(
      BrancardageApi(
        'fixture',
        client: MockClient(
          (_) async => http.Response('{"results":[],"limited":false}', 200),
        ),
      ),
    );
    addTearDown(directory.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffDirectorySection(directory: directory, onTap: (_) {}),
        ),
      ),
    );
    expect(find.text('Personnel de l’établissement'), findsNothing);
    directory.query = 'Martin';
    directory.error = 'Annuaire indisponible';
    directory.notifyListeners();
    await tester.pump();
    expect(find.text('Annuaire indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(
      find.text('Aucun collègue trouvé pour cette recherche.'),
      findsNothing,
    );
  });
}
