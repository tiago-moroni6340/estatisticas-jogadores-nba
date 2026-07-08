import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Exceção customizada para erros vindos da API.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Cliente HTTP central. Todas as chamadas à API passam por aqui, que:
/// - Monta a URL base
/// - Injeta o header `Authorization: Bearer <token>` automaticamente
/// - Trata erros (422, 401, etc.) de forma padronizada
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  // AJUSTE AQUI: coloque a URL base real do seu backend (sem barra no final).
  static const String baseUrl = 'http://localhost:8000';

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'nba_app_access_token';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final q = query?.map((k, v) => MapEntry(k, v.toString()));
    return Uri.parse('$baseUrl$cleanPath').replace(queryParameters: q);
  }

  dynamic _handle(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    String message = resp.body;
    try {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(resp.statusCode, message);
  }

  Future<dynamic> get(String path,
      {Map<String, dynamic>? query, bool auth = true}) async {
    final resp =
        await http.get(_uri(path, query), headers: await _headers(auth: auth));
    return _handle(resp);
  }

  Future<dynamic> post(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final resp = await http.post(
      _uri(path),
      headers: await _headers(auth: auth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(resp);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final resp = await http.delete(_uri(path), headers: await _headers(auth: auth));
    return _handle(resp);
  }
}
