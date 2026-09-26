import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Authenticated API Client for backend server calls
/// Mirrors the web app's `UEM.apiFetch` helper with automatic JWT injection.
class ApiClient {
  ApiClient._();

  static Future<Map<String, String>> _getHeaders() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _getUri(String endpoint) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('${AppConfig.apiBaseUrl}$cleanEndpoint');
  }

  static Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(_getUri(endpoint), headers: headers);
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network connection failed. Please check your internet connection.');
    }
  }

  static Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        _getUri(endpoint),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network connection failed. Please check your internet connection.');
    }
  }

  static Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        _getUri(endpoint),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network connection failed. Please check your internet connection.');
    }
  }

  static dynamic _handleResponse(http.Response response) {
    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(response.body);
    } catch (_) {
      jsonBody = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (jsonBody is Map<String, dynamic> && jsonBody.containsKey('data')) {
        return jsonBody['data'];
      }
      return jsonBody;
    }

    final errorMessage = jsonBody is Map<String, dynamic>
        ? (jsonBody['message'] ?? 'Request failed with status ${response.statusCode}')
        : 'Request failed with status ${response.statusCode}';

    throw ApiException(errorMessage.toString(), response.statusCode);
  }
}
