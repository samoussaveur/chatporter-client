import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twake_chat/modules/brancardage/delete_confirmation.dart';

void main() {
  testWidgets(
    'first confirmation can be cancelled without preparing deletion',
    (tester) async {
      var prepared = 0, deleted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmRequestDeletion(
                context,
                reference: 'BR-HpC-001-13-10-2026',
                prepare: () async {
                  prepared++;
                  return 'challenge';
                },
                commit: (_) async {
                  deleted++;
                },
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(prepared, 0);
      expect(deleted, 0);
    },
  );
  testWidgets(
    'second confirmation can be cancelled; two explicit approvals required',
    (tester) async {
      var prepared = 0, deleted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmRequestDeletion(
                context,
                reference: 'BR-HpC-001-13-10-2026',
                prepare: () async {
                  prepared++;
                  return 'challenge';
                },
                commit: (_) async {
                  deleted++;
                },
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(prepared, 1);
      expect(deleted, 0);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(deleted, 0);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();
      expect(deleted, 1);
    },
  );
}
