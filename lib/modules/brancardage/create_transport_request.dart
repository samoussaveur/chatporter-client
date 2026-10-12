import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'brancardage_api.dart';
import 'transport_locations.dart';

class CreateTransportRequest extends StatefulWidget {
  const CreateTransportRequest({super.key, required this.api});
  final BrancardageApi api;
  @override
  State<CreateTransportRequest> createState() => CreateTransportRequestState();
}

class CreateTransportRequestState extends State<CreateTransportRequest> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final key in [
      'last_name',
      'first_name',
      'origin',
      'destination',
      'oxygen_setting',
      'equipment',
      'notes',
      'birth_date',
      'used_name',
      'ipp',
      'ins',
      'appointment_date',
      'appointment_time',
      'protocol',
      'practitioner',
    ])
      key: TextEditingController(),
  };
  String? _sex, _mode, _timing;
  Map<String, String>? _originLocation, _destinationLocation;
  bool? _oxygen, _perfused;
  bool _recap = false, _busy = false;
  String? _error;
  String _operation = const Uuid().v4();
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _data => {
    for (final e in _fields.entries) e.key: e.value.text.trim(),
    'form_version': 2,
    'timing': _timing,
    'appointment_date': _timing == 'scheduled'
        ? _fields['appointment_date']!.text.trim()
        : '',
    'appointment_time': _timing == 'scheduled'
        ? _fields['appointment_time']!.text.trim()
        : '',
    'oxygen_setting': _oxygen == true
        ? _fields['oxygen_setting']!.text.trim()
        : '',
    'origin_location':
        _originLocation?['full_name'] == _fields['origin']!.text.trim()
        ? _originLocation
        : null,
    'destination_location':
        _destinationLocation?['full_name'] ==
            _fields['destination']!.text.trim()
        ? _destinationLocation
        : null,
    'sex': _sex,
    'mode': _mode,
    'oxygen': _oxygen,
    'perfused': _perfused,
  };
  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final result = await widget.api.call(
        'requests',
        body: {'operation_id': _operation, 'data': _data},
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is BrancardageFailure
              ? e.message
              : 'En attente d’envoi : confirmation indisponible. Vos informations sont conservées. Réessayez sans fermer la fiche.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _fields[key],
      maxLines: lines,
      maxLength: lines > 1 ? 4000 : 250,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (text) {
        if (required && (text == null || text.trim().isEmpty)) {
          return 'Champ obligatoire';
        }
        if (key == 'birth_date') return validateBirthDate(text ?? '');
        if (key == 'appointment_date' &&
            !validCalendarDate(text ?? '', iso: true)) {
          return 'Utilisez AAAA-MM-JJ : date valide requise';
        }
        if (key == 'appointment_time' &&
            !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(text ?? '')) {
          return 'Utilisez HH:MM, par exemple 14:30';
        }
        return null;
      },
    ),
  );
  Widget _choice<T>(
    String label,
    T? value,
    Map<T, String> choices,
    void Function(T?) change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: choices.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: change,
      validator: (value) => value == null ? 'Choix obligatoire' : null,
    ),
  );
  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 20),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  final _locationValidation = {
    'origin': GlobalKey<FormFieldState<String>>(),
    'destination': GlobalKey<FormFieldState<String>>(),
  };
  @override
  void initState() {
    super.initState();
    for (final key in ['origin', 'destination']) {
      _fields[key]!.addListener(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final state = _locationValidation[key]!.currentState;
          if (state != null && state.value != _fields[key]!.text) {
            state.didChange(_fields[key]!.text);
          }
        });
      });
    }
  }

  late final _placeEntries = transportLocations
      .map(
        (place) => DropdownMenuEntry<Map<String, String>>(
          value: place,
          label: place['full_name']!,
          labelWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${place['name']}${place['room']!.isEmpty ? '' : ' · ${place['room']}'}',
              ),
              Text('${place['building']} · ${place['floor']}'),
            ],
          ),
        ),
      )
      .toList();

  Widget _location(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: FormField<String>(
      key: _locationValidation[key],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) =>
          _fields[key]!.text.trim().isEmpty ? 'Champ obligatoire' : null,
      builder: (field) => LayoutBuilder(
        builder: (context, constraints) => DropdownMenu<Map<String, String>>(
          key: ValueKey('location-$key'),
          controller: _fields[key],
          width: constraints.maxWidth,
          menuHeight: 240,
          inputFormatters: [LengthLimitingTextInputFormatter(250)],
          label: Text(label),
          helperText: 'Rechercher un service, une chambre ou une salle',
          errorText: field.errorText,
          requestFocusOnTap: true,
          enableFilter: true,
          filterCallback: (entries, query) {
            final normalized = normalizeLocation(query.trim());
            if (normalized.isEmpty) {
              return const <DropdownMenuEntry<Map<String, String>>>[];
            }
            return entries
                .where(
                  (entry) =>
                      normalizeLocation(entry.label).contains(normalized),
                )
                .take(12)
                .toList();
          },
          onSelected: (place) => setState(() {
            if (key == 'origin') {
              _originLocation = place;
            } else {
              _destinationLocation = place;
            }
            field.didChange(_fields[key]!.text);
          }),
          dropdownMenuEntries: _placeEntries,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_recap ? 'Vérifier la demande' : 'Nouvelle demande'),
      leading: BackButton(
        onPressed: _busy
            ? null
            : () {
                if (_recap) {
                  setState(() {
                    _recap = false;
                    _operation = const Uuid().v4();
                  });
                } else {
                  Navigator.pop(context);
                }
              },
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_recap) ...[
                  Text(
                    '${_data['last_name']} ${_data['first_name']}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nom d’usage : ${_data['used_name']}\nNaissance : ${_data['birth_date']}\nIPP : ${_data['ipp']}\nINS : ${_data['ins']}\nSexe : $_sex\nHoraire : ${_timing == 'scheduled' ? '${_data['appointment_date']} à ${_data['appointment_time']} (à destination)' : 'Transport immédiat'}\nDépart : ${_data['origin']}\nDestination : ${_data['destination'].toString().isEmpty ? 'À préciser' : _data['destination']}\nMode : $_mode\nOxygène : ${_oxygen == true ? 'Oui — ${_data['oxygen_setting']}' : 'Non'}\nPerfusé : ${_perfused == true ? 'Oui' : 'Non'}\nÉquipement : ${_data['equipment']}\nProtocole : ${_data['protocol']}\nInformations : ${_data['notes']}\nPraticien responsable : ${_data['practitioner']}',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy ? 'Envoi en cours…' : 'Valider la demande',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _recap = false;
                            _operation = const Uuid().v4();
                          }),
                    child: const Text('Corriger avant envoi'),
                  ),
                ] else ...[
                  const Text(
                    'Recette : utilisez uniquement des patients fictifs.',
                  ),
                  const SizedBox(height: 24),
                  _section('1 · Patient'),
                  _field('last_name', 'Nom de naissance *', required: true),
                  _field('first_name', 'Prénom *', required: true),
                  _field('used_name', 'Nom d’usage (facultatif)'),
                  _field(
                    'birth_date',
                    'Date de naissance * — JJ/MM/AAAA',
                    required: true,
                  ),
                  _choice('Sexe *', _sex, {
                    'F': 'Féminin',
                    'M': 'Masculin',
                    'autre': 'Autre / non précisé',
                  }, (v) => setState(() => _sex = v)),
                  _field('ipp', 'IPP (facultatif)'),
                  _field('ins', 'INS (facultatif)'),
                  const Text(
                    'INS issue du dossier patient ; aucune qualification effectuée ici.',
                  ),
                  _section('2 · Trajet et horaire'),
                  _choice('Type de demande *', _timing, {
                    'immediate': 'Transport immédiat',
                    'scheduled': 'Rendez-vous programmé',
                  }, (v) => setState(() => _timing = v)),
                  if (_timing == 'scheduled') ...[
                    _field(
                      'appointment_date',
                      'Date du rendez-vous * — AAAA-MM-JJ',
                      required: true,
                    ),
                    _field(
                      'appointment_time',
                      'Heure du rendez-vous * — HH:MM',
                      required: true,
                    ),
                    const Text('Heure attendue à destination, pas de départ.'),
                    const SizedBox(height: 16),
                  ],
                  _location('origin', 'Lieu de départ *'),
                  _location('destination', 'Destination *'),
                  _choice('Mode de transport *', _mode, {
                    'marche': 'Marche',
                    'fauteuil': 'Fauteuil',
                    'brancard': 'Brancard',
                    'lit': 'Lit',
                  }, (v) => setState(() => _mode = v)),
                  _section('3 · Conditions de transport'),
                  _choice(
                    'Oxygène *',
                    _oxygen,
                    {true: 'Oui', false: 'Non'},
                    (v) => setState(() {
                      _oxygen = v;
                    }),
                  ),
                  if (_oxygen == true)
                    _field(
                      'oxygen_setting',
                      'Réglage prescrit avec son unité *',
                      required: true,
                    ),
                  _choice(
                    'Patient perfusé *',
                    _perfused,
                    {true: 'Oui', false: 'Non'},
                    (v) => setState(() => _perfused = v),
                  ),
                  _field(
                    'protocol',
                    'Protocole particulier (facultatif)',
                    lines: 2,
                  ),
                  _field('equipment', 'Équipement à prévoir', lines: 2),
                  _field('notes', 'Informations utiles au transport', lines: 3),
                  _section('4 · Praticien responsable'),
                  _field(
                    'practitioner',
                    'Médecin ou praticien responsable (facultatif)',
                  ),
                  FilledButton(
                    onPressed: () {
                      if (_form.currentState!.validate()) {
                        setState(() => _recap = true);
                      }
                    },
                    child: const Text('Vérifier avant de valider'),
                  ),
                ],
                if (_busy) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

bool validCalendarDate(String input, {bool iso = false}) {
  final match =
      (iso
              ? RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
              : RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'))
          .firstMatch(input);
  if (match == null) return false;
  final year = int.parse(match[iso ? 1 : 3]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[iso ? 3 : 1]!);
  final date = DateTime(year, month, day);
  return year > 0 &&
      date.year == year &&
      date.month == month &&
      date.day == day;
}

String? validateBirthDate(String input) {
  if (!validCalendarDate(input)) return 'Date invalide : utilisez JJ/MM/AAAA';
  final parts = input.split('/').map(int.parse).toList();
  final date = DateTime(parts[2], parts[1], parts[0]);
  final now = DateTime.now();
  return date.isAfter(DateTime(now.year, now.month, now.day))
      ? 'La date de naissance ne peut pas être future'
      : null;
}
