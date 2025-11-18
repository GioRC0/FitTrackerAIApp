import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fitracker_app/models/user_dtos.dart';
import 'package:fitracker_app/config/api_config.dart'; 


class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class ApiService {
  
  // Endpoint de LOGIN: POST /api/auth/login
  Future<TokenDto> login({
    required String email, 
    required String password,
  }) async {
    final loginDto = LoginDto(email: email, password: password);
    final url = Uri.parse('${ApiConfig.authBaseUrl}/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(loginDto.toJson()),
      );

      // Si el login fue exitoso (código 200 OK)
      if (response.statusCode == 200) {
        // Decodificar el JSON de la respuesta
        final jsonResponse = jsonDecode(response.body);
        return TokenDto.fromJson(jsonResponse);

      } 
      // Si hay un error del lado del cliente (400 Bad Request, 401 Unauthorized, etc.)
      else if (response.statusCode >= 400 && response.statusCode < 500) {
        final errorBody = jsonDecode(response.body);
        // El API de .NET típicamente devuelve un campo 'message' o 'errors'
        final errorMessage = errorBody['message'] ?? 'Credenciales inválidas o error de cliente.';
        throw ApiException(errorMessage, statusCode: response.statusCode);
      } 
      // Si hay un error del servidor (500 Internal Server Error)
      else {
        throw ApiException(
          'Error del servidor al iniciar sesión. Código: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      // Manejar errores de red (ej. servidor apagado, sin conexión)
      if (e is http.ClientException) {
        throw ApiException('No se pudo conectar al servidor. Verifica la URL y la conexión.');
      }
      rethrow; // Relanzar cualquier otra excepción (incluyendo ApiException)
    }
  }

  // Endpoint de REGISTRO: POST /api/auth/register
Future<TokenDto> register({
  required RegisterDto registerDto,
}) async {
  final url = Uri.parse('${ApiConfig.authBaseUrl}/register');

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(registerDto.toJson()),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return TokenDto.fromJson(jsonResponse);
    } 
    else if (response.statusCode == 409) { // Conflicto: User already exists
      throw ApiException('El correo electrónico ya está registrado.', statusCode: 409);
    } 
    else if (response.statusCode >= 400 && response.statusCode < 500) {
      final errorBody = jsonDecode(response.body);
      final errorMessage = errorBody['message'] ?? 'Error al procesar los datos de registro.';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } 
    else {
      throw ApiException(
        'Error del servidor al registrar. Código: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  } catch (e) {
    if (e is http.ClientException) {
      throw ApiException('No se pudo conectar al servidor. Verifica la URL y la conexión.');
    }
    rethrow;
  }
}

// Endpoint para reenviar código de verificación
Future<void> sendVerificationCode({required String email}) async {
  final url = Uri.parse('${ApiConfig.authBaseUrl}/send-verification-code');

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      // El cuerpo es el email como string
      body: jsonEncode(email), 
    );

    if (response.statusCode >= 400) {
      final errorBody = jsonDecode(response.body);
      final errorMessage = errorBody['message'] ?? 'No se pudo reenviar el código.';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    }
  } catch (e) {
    if (e is http.ClientException) {
      throw ApiException('Error de red al intentar reenviar el código.');
    }
    rethrow;
  }
}


// Endpoint para verificar el código
Future<TokenDto> verifyCode({
  required String email, 
  required String code,
}) async {
  final url = Uri.parse('${ApiConfig.authBaseUrl}/verify-code');
  final verifyDto = VerifyCodeDto(email: email, code: code); // Usamos el DTO
  
  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(verifyDto.toJson()),
    );

    if (response.statusCode == 200) {
      // Éxito: El servidor devuelve un objeto con el mensaje y los nuevos Tokens
      final jsonResponse = jsonDecode(response.body);
      
      // El servidor devuelve { "message": "...", "tokens": { ... } }
      return TokenDto.fromJson(jsonResponse['tokens']);

    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      final errorBody = jsonDecode(response.body);
      final errorMessage = errorBody['message'] ?? 'Código inválido o expirado.';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } else {
      throw ApiException(
        'Error del servidor al verificar. Código: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  } catch (e) {
    if (e is http.ClientException) {
      throw ApiException('Error de red al intentar verificar el código.');
    }
    rethrow;
  }
}

  // Endpoint de REFRESH TOKEN: POST /api/auth/refresh
  Future<TokenDto> refreshToken({required String refreshToken}) async {
    final url = Uri.parse('${ApiConfig.authBaseUrl}/refresh');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return TokenDto.fromJson(jsonResponse);
      } 
      else if (response.statusCode == 401) {
        // Token inválido o expirado - forzar re-login
        throw ApiException('Sesión expirada. Por favor inicia sesión nuevamente.', statusCode: 401);
      } 
      else if (response.statusCode >= 400 && response.statusCode < 500) {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['message'] ?? 'Error al refrescar token.';
        throw ApiException(errorMessage, statusCode: response.statusCode);
      } 
      else {
        throw ApiException(
          'Error del servidor al refrescar token. Código: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw ApiException('No se pudo conectar al servidor.');
      }
      rethrow;
    }
  }

  // Otros endpoints irán aquí: logout, getProfile, etc.
}