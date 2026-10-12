import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twake_chat/modules/brancardage/brancardage_api.dart';
import 'package:twake_chat/modules/brancardage/create_transport_request.dart';

void main() {
  testWidgets(
    'La chambre proposée peut être sélectionnée avec les sémantiques actives',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final api = BrancardageApi('fictitious-test-token');
      await tester.pumpWidget(
        MaterialApp(home: CreateTransportRequest(api: api)),
      );
      final origin = find.widgetWithText(TextField, 'Lieu de départ *');
      await tester.ensureVisible(origin);
      await tester.tap(origin);
      await tester.pumpAndSettle();
      await tester.enterText(origin, 'Demo service A');
      await tester.pumpAndSettle();
      final chamber = find.text('Demo service A · Demo room').hitTestable();
      expect(chamber, findsOneWidget);
      await tester.tap(chamber);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(origin).controller!.text,
        contains('Demo room'),
      );
      expect(chamber, findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.close();
      semantics.dispose();
    },
  );

  testWidgets('Les champs obligatoires hors écran bloquent le récapitulatif', (
    tester,
  ) async {
    final api = BrancardageApi('fictitious-test-token');
    await tester.pumpWidget(
      MaterialApp(home: CreateTransportRequest(api: api)),
    );
    final verify = find.text('Vérifier avant de valider');
    await tester.ensureVisible(verify);
    await tester.tap(verify);
    await tester.pumpAndSettle();
    expect(find.text('Vérifier la demande'), findsNothing);
    expect(find.text('Champ obligatoire'), findsWidgets);
    expect(find.text('Choix obligatoire'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
  testWidgets('Le rendez-vous conserve sa saisie lorsqu’il est masqué', (
    tester,
  ) async {
    final api = BrancardageApi('fictitious-test-token');
    await tester.pumpWidget(
      MaterialApp(home: CreateTransportRequest(api: api)),
    );
    final timing = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Type de demande *',
    );
    await tester.ensureVisible(timing);
    await tester.tap(timing);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rendez-vous programmé').last);
    await tester.pumpAndSettle();
    final date = find.widgetWithText(
      TextFormField,
      'Date du rendez-vous * — AAAA-MM-JJ',
    );
    await tester.ensureVisible(date);
    await tester.enterText(date, '2026-10-13');
    await tester.ensureVisible(timing);
    await tester.tap(timing);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport immédiat').last);
    await tester.pumpAndSettle();
    expect(date, findsNothing);
    await tester.tap(timing);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rendez-vous programmé').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(date).controller!.text, '2026-10-13');
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
