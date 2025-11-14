import 'package:http/http.dart' as http;
import 'package:fitracker_app/services/auth_service.dart';
import 'package:fitracker_app/api/api_service.dart';

/// Cliente HTTP que automáticamente refresca tokens cuando expiran
class AuthenticatedHttpClient {
  final AuthService _authService = AuthService();

  /// Hace un GET request con manejo automático de refresh token
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return await _makeAuthenticatedRequest(
      () => http.get(url, headers: headers),
      () => http.get(url, headers: headers),
    );
  }

  /// Hace un POST request con manejo automático de refresh token
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return await _makeAuthenticatedRequest(
      () => http.post(url, headers: headers, body: body),
      () => http.post(url, headers: headers, body: body),
    );
  }

  /// Hace un PUT request con manejo automático de refresh token
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return await _makeAuthenticatedRequest(
      () => http.put(url, headers: headers, body: body),
      () => http.put(url, headers: headers, body: body),
    );
  }

  /// Hace un DELETE request con manejo automático de refresh token
  Future<http.Response> delete(Uri url, {Map<String, String>? headers}) async {
    return await _makeAuthenticatedRequest(
      () => http.delete(url, headers: headers),
      () => http.delete(url, headers: headers),
    );
  }

  /// Lógica central de manejo de requests autenticados
  Future<http.Response> _makeAuthenticatedRequest(
    Future<http.Response> Function() request,
    Future<http.Response> Function() retryRequest,
  ) async {
    // Intentar hacer el request
    http.Response response = await request();

    // Si el token expiró (401), intentar refrescar
    if (response.statusCode == 401) {
      final refreshSuccess = await _authService.refreshTokenIfNeeded();

      if (!refreshSuccess) {
        // Refresh falló, requiere re-login
        throw ApiException(
          'Sesión expirada. Por favor inicia sesión nuevamente.',
          statusCode: 401,
        );
      }

      // Retry el request con el nuevo token
      response = await retryRequest();
    }

    return response;
  }

  /// Helper para agregar headers de autorización
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
