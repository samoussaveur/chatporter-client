import 'package:twake_chat/modules/brancardage/delete_confirmation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:twake_chat/widgets/matrix.dart';
import 'package:uuid/uuid.dart';
import 'brancardage_api.dart';
import 'create_transport_request.dart';

const _states = {
  'waiting': 'En attente d’affectation',
  'in_progress': 'En cours de traitement',
  'instruction': 'En attente d’instruction',
  'archived': 'Archivé',
};
const _colors = {
  'waiting': Colors.blue,
  'in_progress': Colors.green,
  'instruction': Colors.orange,
  'archived': Colors.grey,
};
const _actions = {
  'assign': 'S’affecter',
  'resume': 'Reprendre le traitement',
  'unassign': 'Se désaffecter',
  'instruction': 'Attendre une instruction',
  'close': 'Clôturer',
  'reopen': 'Désarchiver',
};
const _reasons = {
  'accompli': 'Transport accompli',
  'annulation': 'Annulation',
  'doublon': 'Doublon',
  'impossibilite': 'Impossibilité',
};

class BrancardagePage extends StatefulWidget {
  const BrancardagePage({super.key, required this.onReturnToMessaging});
  final VoidCallback onReturnToMessaging;
  @override
  State<BrancardagePage> createState() => _BrancardagePageState();
}

class _BrancardagePageState extends State<BrancardagePage> {
  BrancardageApi? _api;
  String? _account;
  Map<String, dynamic>? _me, _detail;
  List<dynamic> _items = [];
  Map<String, dynamic> _counts = {};
  String _status = 'waiting';
  String? _selected, _error;
  bool _busy = false, _loading = true, _more = false;
  int _generation = 0, _offset = 0;
  int _refreshSequence = 0;
  Timer? _poll, _debounce;
  final _search = TextEditingController();
  final _message = TextEditingController();
  String? _messageOperation;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = Matrix.of(context).client;
    final key = '${client.homeserver}|${client.userID}';
    if (_account == key) return;
    _generation++;
    _account = key;
    _api?.close();
    _api = BrancardageApi(client.accessToken ?? '');
    _me = _detail = null;
    _items = [];
    _selected = null;
    _message.clear();
    _messageOperation = null;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_busy) _refresh(silent: true);
    });
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _debounce?.cancel();
    _api?.close();
    _search.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    final generation = _generation;
    final sequence = ++_refreshSequence;
    final selected = _selected;
    final status = _status;
    try {
      final me = await _api!.call('me');
      final list = await _api!.call(
        'requests?status=$status&q=${Uri.encodeQueryComponent(_search.text)}&offset=$_offset',
      );
      final detail = selected == null
          ? null
          : await _api!.call('requests/$selected');
      if (!mounted ||
          generation != _generation ||
          sequence != _refreshSequence ||
          status != _status ||
          selected != _selected) {
        return;
      }
      setState(() {
        _me = me;
        _items = list['items'] as List;
        _counts = list['counts'] as Map<String, dynamic>;
        _more = list['more'] == true;
        _detail = detail;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted ||
          generation != _generation ||
          sequence != _refreshSequence) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e is BrancardageFailure
            ? e.message
            : 'Connexion au brancardage indisponible. Vos saisies sont conservées ; réessayez.';
      });
    }
  }

  Future<void> _select(String id) async {
    if (_busy) return;
    if (_message.text.isNotEmpty && id != _selected) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Message non envoyé'),
          content: const Text(
            'Abandonner ce brouillon pour ouvrir une autre demande ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Conserver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abandonner'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() {
      _selected = id;
      _detail = null;
      _message.clear();
      _messageOperation = null;
    });
    await _refresh();
  }

  Future<void> _mutate(Map<String, dynamic> action) async {
    final id = _selected;
    final version = _detail?['version'];
    if (_busy || id == null || version == null) return;
    setState(() => _busy = true);
    try {
      final result = await _api!.call(
        'requests/$id/actions',
        body: {
          'operation_id': const Uuid().v4(),
          'expected_version': version,
          'action': action,
        },
      );
      if (!mounted) return;
      setState(() {
        _detail = result;
        _error = null;
      });
      await _refresh();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is BrancardageFailure
              ? e.message
              : 'Envoi non confirmé. Actualisez la demande avant de réessayer.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _instruction() async {
    final text = await _ask(
      'Attente d’instruction',
      'Précisez l’instruction attendue (message obligatoire).',
    );
    if (text != null && text.trim().isNotEmpty) {
      await _mutate({'type': 'instruction', 'message': text.trim()});
    }
  }

  Future<String?> _ask(String title, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 4000,
            decoration: InputDecoration(labelText: label),
            onChanged: (_) => update(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, controller.text),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
    // Dialog widgets finish their exit animation before controllers are disposed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    return result;
  }

  Future<void> _close() async {
    String? reason;
    final explanation = TextEditingController();
    final required = _detail!['assignment']['assignee'] == null;
    final action = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Clôturer la demande'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Motif obligatoire',
                  ),
                  items: _reasons.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => update(() => reason = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: explanation,
                  maxLines: 3,
                  maxLength: 4000,
                  decoration: InputDecoration(
                    labelText: required
                        ? 'Explication obligatoire'
                        : 'Explication',
                  ),
                  onChanged: (_) => update(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed:
                  reason == null || required && explanation.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, {
                      'type': 'close',
                      'reason': reason,
                      'explanation': explanation.text.trim(),
                    }),
              child: const Text('Clôturer'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    explanation.dispose();
    if (action != null) await _mutate(action);
  }

  Future<void> _send() async {
    if (_busy || _message.text.trim().isEmpty || _selected == null) return;
    _messageOperation ??= const Uuid().v4();
    final text = _message.text.trim();
    setState(() => _busy = true);
    try {
      final result = await _api!.call(
        'requests/$_selected/messages',
        body: {'operation_id': _messageOperation, 'text': text},
      );
      if (mounted) {
        setState(() {
          _detail = result;
          _message.clear();
          _messageOperation = null;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is BrancardageFailure
              ? e.message
              : 'Message non confirmé. Réessayez : le même envoi ne sera pas dupliqué.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => CreateTransportRequest(api: _api!)),
    );
    if (result != null && mounted) {
      setState(() {
        _status = 'waiting';
        _offset = 0;
        _selected = result['id'] as String;
        _detail = result;
      });
      await _refresh();
    }
  }

  Widget _badge(String status) => Chip(
    avatar: Icon(Icons.circle, color: _colors[status], size: 14),
    label: Text(_states[status] ?? status),
  );
  Widget _list() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Rechercher un patient, un lieu ou une demande',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () {
              _offset = 0;
              _refresh();
            });
          },
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? const Center(child: Text('Aucune demande dans cet état.'))
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final r = _items[index] as Map<String, dynamic>;
                  final d = r['data'];
                  return ListTile(
                    selected: r['id'] == _selected,
                    leading: Icon(
                      Icons.local_shipping_outlined,
                      color: _colors[r['assignment']['status']],
                    ),
                    title: Text(
                      '${r['reference'] ?? r['id']} · ${d['last_name']} ${d['first_name']}',
                    ),
                    subtitle: Text(
                      '${d['origin']} → ${d['destination'].toString().isEmpty ? 'Destination à préciser' : d['destination']}\n${r['assignee_name'] ?? 'Sans affectation'}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _select(r['id'] as String),
                  );
                },
              ),
      ),
      if (_more || _offset > 0)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _offset == 0
                  ? null
                  : () {
                      _offset -= 100;
                      _refresh();
                    },
              child: const Text('Précédentes'),
            ),
            TextButton(
              onPressed: !_more
                  ? null
                  : () {
                      _offset += 100;
                      _refresh();
                    },
              child: const Text('Suivantes'),
            ),
          ],
        ),
    ],
  );
  Future<void> _deleteRequest() async {
    final id = _selected;
    final request = _detail;
    if (_busy || id == null || request == null || _me?['role'] != 'admin') {
      return;
    }
    final generation = _generation;
    final api = _api!;
    setState(() => _busy = true);
    try {
      final deleted = await confirmRequestDeletion(
        context,
        reference: request['reference'].toString(),
        stillCurrent: () =>
            mounted && generation == _generation && _selected == id,
        prepare: () async {
          final result = await api.call(
            'requests/$id/delete-prepare',
            body: {},
          );
          return result['challenge'] as String;
        },
        commit: (challenge) async {
          await api.call(
            'requests/$id/delete-confirm',
            body: {'challenge': challenge, 'confirmed': true},
          );
        },
      );
      if (!mounted || generation != _generation) return;
      if (deleted) {
        setState(() {
          _selected = null;
          _detail = null;
        });
        await _refresh();
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Widget _request() {
    final r = _detail;
    if (r == null) {
      return Center(
        child: _selected == null
            ? const Text(
                'Sélectionnez une demande pour consulter sa fiche et ses échanges.',
              )
            : const CircularProgressIndicator(),
      );
    }
    final d = r['data'] as Map<String, dynamic>;
    final a = r['assignment'];
    final status = a['status'] as String;
    final own = a['assignee'] == _me?['id'];
    final manage = _me?['manage'] == true;
    final regulate = _me?['regulate'] == true;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          r['reference']?.toString() ?? r['id'].toString(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${d['last_name']} ${d['first_name']}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _badge(status),
            Text(
              r['assignee_name'] == null
                  ? 'Sans affectation'
                  : 'Affecté à ${r['assignee_name']}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Départ : ${d['origin']}\nDestination : ${d['destination'].toString().isEmpty ? 'À préciser' : d['destination']}\nSexe : ${d['sex']} • Mode : ${d['mode']}\nOxygène : ${d['oxygen'] == true ? 'Oui — ${d['oxygen_setting']}' : 'Non'}\nPerfusé : ${d['perfused'] == true ? 'Oui' : 'Non'}',
        ),
        for (final entry in {
          'birth_date': 'Naissance',
          'used_name': 'Nom d’usage',
          'ipp': 'IPP',
          'ins': 'INS',
          'protocol': 'Protocole',
          'practitioner': 'Praticien responsable',
        }.entries)
          if (d[entry.key] != null && d[entry.key].toString().isNotEmpty)
            Text('${entry.value} : ${d[entry.key]}'),
        if (d['timing'] == 'immediate') const Text('Transport immédiat'),
        if (d['timing'] == 'scheduled')
          Text(
            'Rendez-vous : ${d['appointment_date']} à ${d['appointment_time']} (à destination)',
          ),
        if (d['equipment'].toString().isNotEmpty)
          Text('Équipement : ${d['equipment']}'),
        if (d['notes'].toString().isNotEmpty)
          Text('Informations : ${d['notes']}'),
        if (a['reason'] != null)
          Text('Motif de clôture : ${_reasons[a['reason']] ?? a['reason']}'),
        const SizedBox(height: 16),
        if (manage)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'waiting')
                FilledButton(
                  onPressed: _busy ? null : () => _mutate({'type': 'assign'}),
                  child: const Text('S’affecter'),
                ),
              if (status == 'instruction' && own)
                FilledButton(
                  onPressed: _busy ? null : () => _mutate({'type': 'resume'}),
                  child: const Text('Reprendre le traitement'),
                ),
              if (status == 'in_progress')
                OutlinedButton(
                  onPressed: _busy ? null : _instruction,
                  child: const Text('Attendre une instruction'),
                ),
              if (a['assignee'] != null &&
                  status != 'archived' &&
                  (own || regulate))
                OutlinedButton(
                  onPressed: _busy ? null : () => _mutate({'type': 'unassign'}),
                  child: Text(own ? 'Se désaffecter' : 'Désaffecter'),
                ),
              if (status != 'archived' && (own || a['assignee'] == null))
                OutlinedButton(
                  onPressed: _busy ? null : _close,
                  child: const Text('Clôturer'),
                ),
              if (status == 'archived')
                FilledButton(
                  onPressed: _busy ? null : () => _mutate({'type': 'reopen'}),
                  child: const Text('Désarchiver'),
                ),
            ],
          ),
        if (_me?['role'] == 'admin')
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _deleteRequest,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Supprimer définitivement'),
            ),
          ),
        const Divider(height: 40),
        Text(
          'Échanges et historique',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...((r['events'] as List).map((event) {
          final c = event['content'];
          final kind = event['kind'];
          final timestamp = DateTime.tryParse(
            event['created_at'].toString(),
          )?.toLocal();
          final text = kind == 'message'
              ? c['text']
              : kind == 'created'
              ? 'Demande enregistrée'
              : '${_actions[c['action']['type']] ?? c['action']['type']} — ${_states[c['after']['status']]}${c['action']['message'] == null ? '' : '\n${c['action']['message']}'}${c['action']['explanation'] == null || c['action']['explanation'] == '' ? '' : '\n${c['action']['explanation']}'}';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${event['actor_name']} • ${timestamp ?? ''}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(text.toString()),
                ],
              ),
            ),
          );
        })),
        if (status == 'archived')
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Archive en lecture seule. Désarchivez pour reprendre le traitement.',
            ),
          )
        else ...[
          const SizedBox(height: 16),
          TextField(
            controller: _message,
            maxLines: 3,
            maxLength: 8000,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Écrire dans les échanges',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_messageOperation != null) _messageOperation = null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Envoyer'),
            ),
          ),
        ],
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Brancardage'),
          leading: BackButton(
            onPressed: () {
              if (!wide && _selected != null) {
                setState(() {
                  _selected = null;
                  _detail = null;
                });
              } else {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  widget.onReturnToMessaging();
                }
              }
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Actualiser',
              onPressed: _busy ? null : () => _refresh(),
              icon: const Icon(Icons.refresh),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: constraints.maxWidth < 600
                  ? IconButton.filled(
                      tooltip: 'Nouvelle demande',
                      onPressed: _busy || _me == null ? null : _create,
                      icon: const Icon(Icons.add),
                    )
                  : FilledButton.icon(
                      onPressed: _busy || _me == null ? null : _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Nouvelle demande'),
                    ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_error != null)
                MaterialBanner(
                  content: Text(_error!),
                  actions: [
                    TextButton(
                      onPressed: () => _refresh(),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: _states.entries
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${e.value} (${_counts[e.key] ?? 0})'),
                            selected: _status == e.key,
                            avatar: Icon(
                              Icons.circle,
                              size: 12,
                              color: _colors[e.key],
                            ),
                            onSelected: _busy
                                ? null
                                : (_) {
                                    setState(() {
                                      _status = e.key;
                                      _offset = 0;
                                    });
                                    _refresh();
                                  },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          SizedBox(width: 380, child: _list()),
                          const VerticalDivider(width: 1),
                          Expanded(child: _request()),
                        ],
                      )
                    : _selected == null
                    ? _list()
                    : _request(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
