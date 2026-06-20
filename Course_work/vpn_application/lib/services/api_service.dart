import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_storage.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 15);

  Future<String> _baseUrl() => AuthStorage.getApiBaseUrl();

  Future<http.Response> _post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final baseUrl = await _baseUrl();
    try {
      return await _client
          .post(Uri.parse('$baseUrl$path'), headers: headers, body: body)
          .timeout(_timeout);
    } on SocketException {
      throw ApiException(0, _connectionError(baseUrl));
    } on HttpException {
      throw ApiException(0, _connectionError(baseUrl));
    } on TimeoutException {
      throw ApiException(0, _connectionError(baseUrl));
    }
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final baseUrl = await _baseUrl();
    try {
      return await _client
          .get(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(_timeout);
    } on SocketException {
      throw ApiException(0, _connectionError(baseUrl));
    } on HttpException {
      throw ApiException(0, _connectionError(baseUrl));
    } on TimeoutException {
      throw ApiException(0, _connectionError(baseUrl));
    }
  }

  String _connectionError(String baseUrl) {
    if (baseUrl.contains('10.0.2.2')) {
      return 'Нет связи с $baseUrl. На реальном телефоне замените на IP компьютера, '
          'например http://192.168.0.104:8000 (тот же Wi‑Fi, бэкенд запущен).';
    }
    return 'Нет связи с $baseUrl. Проверь: бэкенд запущен (uvicorn), телефон и ПК в одном Wi‑Fi, '
        'URL вида http://192.168.x.x:8000, файрвол Windows разрешает порт 8000.';
  }

  Future<String> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await _post(
      '/register',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'username': username,
        'password': password,
      }),
    );
    return _parseToken(response);
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/login',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseToken(response);
  }

  Future<String> fetchSubscriptionUrl(String token) async {
    final response = await _get(
      '/me/subscription',
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 400) {
      throw _parseError(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final subUrl = data['subscription_url'] as String?;
    if (subUrl == null || subUrl.isEmpty) {
      throw ApiException(response.statusCode, 'Subscription URL не получен');
    }
    return subUrl;
  }

  Future<Map<String, dynamic>> fetchProfile(String token) async {
    final response = await _get(
      '/me',
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 400) {
      throw _parseError(response);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _parseToken(http.Response response) {
    if (response.statusCode >= 400) {
      throw _parseError(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException(response.statusCode, 'Токен не получен');
    }
    return token;
  }

  ApiException _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];
        if (detail is String) {
          return ApiException(response.statusCode, detail);
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return ApiException(response.statusCode, first['msg'].toString());
          }
        }
      }
    } catch (_) {}
    return ApiException(
      response.statusCode,
      'Ошибка сервера (${response.statusCode})',
    );
  }
}
