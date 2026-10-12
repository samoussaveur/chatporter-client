import 'dart:convert';
import 'package:http/http.dart' as http;

class BrancardageApi {
  BrancardageApi(this.token, {http.Client? client})
    : _client = client ?? http.Client();
  final String token;
  final http.Client _client;
  static const base = String.fromEnvironment(
    'CHATPORTER_API_URL',
    defaultValue: 'http://127.0.0.1:8092',
  );
  Future<Map<String, dynamic>> call(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$base/api/$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response =
        await (body == null
                ? _client.get(uri, headers: headers)
                : _client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 15));
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw BrancardageFailure(
        response.statusCode,
        data['error'] as String? ?? 'Opération refusée.',
      );
    }
    return data;
  }

  void close() => _client.close();
}

class BrancardageFailure implements Exception {
  BrancardageFailure(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}
