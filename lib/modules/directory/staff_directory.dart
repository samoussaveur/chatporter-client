import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:twake_chat/modules/brancardage/brancardage_api.dart';

class StaffMember {
  const StaffMember(this.id, this.displayName);
  final String id;
  final String displayName;
}

/// Directory requests use the signed-in user's session, never an admin token.
class StaffDirectory extends ChangeNotifier {
  StaffDirectory(this.api, {this.delay = const Duration(milliseconds: 300)});
  final BrancardageApi api;
  final Duration delay;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  String query = '';
  int limit = 20;
  List<StaffMember> users = [];
  bool loading = false;
  bool limited = false;
  String? error;

  void search(String value, {int requestedLimit = 20}) {
    _timer?.cancel();
    final generation = ++_generation;
    query = value.trim();
    limit = requestedLimit;
    users = [];
    error = null;
    limited = false;
    loading = query.isNotEmpty;
    notifyListeners();
    if (!loading) return;
    final term = query;
    _timer = Timer(delay, () => _fetch(term, generation));
  }

  Future<void> _fetch(String term, int generation) async {
    try {
      final params = Uri(queryParameters: {'q': term, 'limit': '$limit'}).query;
      final response = await api.call('directory?$params');
      if (_disposed || generation != _generation) return;
      users = (response['results'] as List).map((value) {
        final data = value as Map<String, dynamic>;
        final id = data['user_id'] as String;
        final name = data['display_name'] as String?;
        return StaffMember(id, name?.trim().isNotEmpty == true ? name! : id);
      }).toList();
      limited = response['limited'] == true;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure is BrancardageFailure
          ? failure.message
          : 'Impossible de consulter l’annuaire. Réessayez.';
    }
    if (_disposed || generation != _generation) return;
    loading = false;
    notifyListeners();
  }

  void retry() => search(query, requestedLimit: limit);
  void showMore() => search(query, requestedLimit: (limit * 2).clamp(20, 200));

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    api.close();
    super.dispose();
  }
}
