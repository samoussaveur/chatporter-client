import 'package:flutter/material.dart';

Future<bool> confirmRequestDeletion(
  BuildContext context, {
  required String reference,
  required Future<String> Function() prepare,
  required Future<void> Function(String) commit,
  bool Function()? stillCurrent,
}) async {
  final first = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Supprimer cette demande ?'),
      content: Text(
        '$reference\n\nLa demande et ses échanges seront supprimés définitivement. Une seconde confirmation vous sera demandée.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Continuer'),
        ),
      ],
    ),
  );
  if (first != true || !context.mounted || stillCurrent?.call() == false) {
    return false;
  }
  final challenge = await prepare();
  if (!context.mounted || stillCurrent?.call() == false) return false;
  final second = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirmation définitive'),
      content: Text(
        'Confirmez-vous la suppression définitive de $reference et de tous ses échanges ?\n\nCette action ne peut pas être annulée dans l’application.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Supprimer définitivement'),
        ),
      ],
    ),
  );
  if (second != true || !context.mounted || stillCurrent?.call() == false) {
    return false;
  }
  await commit(challenge);
  return true;
}
