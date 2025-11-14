import 'package:fitracker_app/api/api_service.dart';
import 'package:fitracker_app/data/auth_storage_service.dart';
import 'package:fitracker_app/models/user_dtos.dart';

// ====================
// MODELOS AUXILIARES (Definidos primero)
// ====================

/// Resultado de login/registro
class LoginResult {
  final bool success;
  final bool? isVerified;
  final String? email;
  final String? error;

  LoginResult({
    required this.success,
    this.isVerified,
    this.email,
    this.error,
  });
}

/// Estado de la sesión al iniciar la app
enum SessionStatus {
  noSession,     // No hay tokens guardados - ir a login
  notVerified,   // Hay tokens pero usuario no verificado - ir a verificación
  expired,       // Tokens expirados y refresh falló - ir a login
  valid,         // Sesión válida - ir a main screen
}

/// Servicio de autenticación que maneja login, registro, refresh automático y sesión
class AuthService {
  final ApiService _apiService = ApiService();
  final AuthStorageService _storageService = AuthStorageService();

  // ====================
  // 1. LOGIN
  // ====================
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      // Hacer login en el API
      final tokens = await _apiService.login(email: email, password: password);
      
      // Guardar tokens y email en almacenamiento seguro
      await _storageService.saveTokens(tokens);
      await _storageService.saveUserEmail(email);
      
      return LoginResult(
        success: true,
        isVerified: tokens.isVerified,
        email: email,
      );
    } on ApiException catch (e) {
      return LoginResult(
        success: false,
        error: e.message,
      );
    }
  }

  // ====================
  // 2. REGISTRO
  // ====================
  Future<LoginResult> register({required RegisterDto registerDto}) async {
    try {
      // Hacer registro en el API
      final tokens = await _apiService.register(registerDto: registerDto);
      
      // Guardar tokens y email en almacenamiento seguro
      await _storageService.saveTokens(tokens);
      await _storageService.saveUserEmail(registerDto.email);
      
      return LoginResult(
        success: true,
        isVerified: tokens.isVerified,
        email: registerDto.email,
      );
    } on ApiException catch (e) {
      return LoginResult(
        success: false,
        error: e.message,
      );
    }
  }

  // ====================
  // 3. VERIFICACIÓN DE CÓDIGO
  // ====================
  Future<bool> verifyCode({
    required String email,
    required String code,
  }) async {
    try {
      final tokens = await _apiService.verifyCode(email: email, code: code);
      await _storageService.saveTokens(tokens);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ====================
  // 4. REENVIAR CÓDIGO DE VERIFICACIÓN
  // ====================
  Future<bool> sendVerificationCode({required String email}) async {
    try {
      await _apiService.sendVerificationCode(email: email);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ====================
  // 5. REFRESH TOKEN AUTOMÁTICO
  // ====================
  /// Intenta refrescar el access token si está expirado
  /// Retorna true si el refresh fue exitoso, false si requiere re-login
  Future<bool> refreshTokenIfNeeded() async {
    try {
      // Verificar si el access token está expirado
      final isExpired = await _storageService.isAccessTokenExpired();
      
      if (!isExpired) {
        return true; // Token aún válido, no hacer nada
      }

      // Obtener refresh token
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null) {
        return false; // No hay refresh token, requiere login
      }

      // Intentar refrescar
      final newTokens = await _apiService.refreshToken(refreshToken: refreshToken);
      
      // Guardar nuevos tokens
      await _storageService.saveTokens(newTokens);
      
      return true;
    } on ApiException catch (e) {
      // Si el refresh falla (token expirado/inválido), limpiar sesión
      if (e.statusCode == 401) {
        await logout();
        return false;
      }
      return false;
    }
  }

  // ====================
  // 6. CHEQUEO DE SESIÓN AL INICIAR APP
  // ====================
  /// Verifica si hay una sesión válida guardada
  /// Retorna SessionStatus indicando el estado de la sesión
  Future<SessionStatus> checkSession() async {
    // Verificar si hay tokens guardados
    final hasSession = await _storageService.hasValidSession();
    
    if (!hasSession) {
      return SessionStatus.noSession;
    }

    // Verificar si el usuario está verificado
    final isVerified = await _storageService.isUserVerified();
    
    if (!isVerified) {
      return SessionStatus.notVerified;
    }

    // Intentar refrescar el token si está expirado
    final refreshSuccess = await refreshTokenIfNeeded();
    
    if (!refreshSuccess) {
      return SessionStatus.expired;
    }

    return SessionStatus.valid;
  }

  // ====================
  // 7. LOGOUT
  // ====================
  Future<void> logout() async {
    await _storageService.clearSession();
  }

  // ====================
  // 8. OBTENER ACCESS TOKEN (Para hacer requests autenticados)
  // ====================
  Future<String?> getAccessToken() async {
    // Refrescar si es necesario antes de retornar el token
    await refreshTokenIfNeeded();
    return await _storageService.getAccessToken();
  }
  
  // ====================
  // 9. OBTENER EMAIL DEL USUARIO
  // ====================
  Future<String?> getUserEmail() async {
    return await _storageService.getUserEmail();
  }
}
