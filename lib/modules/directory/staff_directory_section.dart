import 'package:flutter/material.dart';
import 'package:twake_chat/modules/directory/staff_directory.dart';
import 'package:twake_chat/widgets/avatar/avatar.dart';
import 'package:twake_chat/widgets/twake_components/twake_loading/center_loading_indicator.dart';

class StaffDirectorySection extends StatelessWidget {
  const StaffDirectorySection({
    super.key,
    required this.directory,
    required this.onTap,
  });
  final StaffDirectory directory;
  final ValueChanged<StaffMember> onTap;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: directory,
    builder: (context, _) {
      if (directory.query.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
            child: Text(
              'Personnel de l’établissement',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (directory.loading)
            const CenterLoadingIndicator()
          else if (directory.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(directory.error!, semanticsLabel: directory.error),
                  TextButton(
                    onPressed: directory.retry,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          else ...[
            if (directory.users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun collègue trouvé pour cette recherche.'),
              ),
            for (final person in directory.users)
              ListTile(
                key: ValueKey('staff_${person.id}'),
                leading: Avatar(name: person.displayName, size: 40),
                title: Text(
                  person.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  person.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onTap(person),
              ),
            if (directory.limited && directory.limit < 200)
              TextButton(
                onPressed: directory.showMore,
                child: const Text('Afficher plus de personnes'),
              ),
            if (directory.limited && directory.limit >= 200)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Précisez le nom ou l’identifiant pour affiner les résultats.',
                ),
              ),
          ],
        ],
      );
    },
  );
}
