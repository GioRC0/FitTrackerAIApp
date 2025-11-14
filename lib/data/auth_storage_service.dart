import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitracker_app/models/user_dtos.dart';

class AuthStorageService {
  // Almacenamiento SEGURO para tokens sensibles
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Claves de almacenamiento
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _accessTokenExpirationKey = 'access_token_expiration';
  static const String _isVerifiedKey = 'is_verified';
  static const String _userEmailKey = 'user_email';
  
  // ====================
  // 1. Guardar Tokens y Estado
  // ====================
  Future<void> saveTokens(TokenDto tokens) async {
    // A. Guardar tokens en almacenamiento SEGURO
    await _secureStorage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: tokens.refreshToken);
    
    // B. Guardar expiración del access token
    await _secureStorage.write(
      key: _accessTokenExpirationKey, 
      value: tokens.accessTokenExpiration.toIso8601String(),
    );
    
    // C. Guardar estado de verificación en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isVerifiedKey, tokens.isVerified);
  }

  // ====================
  // 2. Obtener Tokens (Para chequeo offline y Refresh)
  // ====================
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }
  
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  // ====================
  // 3. Chequeo de Sesión y Validación de Tokens
  // ====================
  Future<bool> hasValidSession() async {
    final refreshToken = await getRefreshToken();
    final accessToken = await getAccessToken();
    
    // Una sesión es válida offline si tenemos tokens guardados.
    // La validez real (expiración) se chequea al intentar la conexión.
    return refreshToken != null && accessToken != null;
  }
  
  /// Verifica si el access token ha expirado
  Future<bool> isAccessTokenExpired() async {
    final expirationStr = await _secureStorage.read(key: _accessTokenExpirationKey);
    if (expirationStr == null) return true;
    
    try {
      final expiration = DateTime.parse(expirationStr);
      // Considerar expirado si falta menos de 5 minutos (buffer de seguridad)
      return DateTime.now().isAfter(expiration.subtract(const Duration(minutes: 5)));
    } catch (e) {
      return true; // Si hay error parseando, considerar expirado
    }
  }
  
  /// Obtiene el estado de verificación del usuario
  Future<bool> isUserVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isVerifiedKey) ?? false;
  }
  
  /// Guarda el email del usuario
  Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
  }
  
  /// Obtiene el email del usuario guardado
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }
  
  // ====================
  // 4. Limpiar Sesión (Logout)
  // ====================
  Future<void> clearSession() async {
    // A. Eliminar tokens del almacenamiento seguro
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _accessTokenExpirationKey);
    
    // B. Limpiar SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isVerifiedKey);
    await prefs.remove(_userEmailKey);
    
    // TODO: Implementar limpieza de la DB local de ejercicios (SQLite)
  }
}