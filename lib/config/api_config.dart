/// Configuración centralizada de URLs para la API
class ApiConfig {
  // ============================================================================
  // CONFIGURACIÓN DE API LOCAL
  // ============================================================================
  
  /// URL base de tu API .NET local
  /// 
  /// **Para DISPOSITIVO FÍSICO**: Usa tu IP local (ejemplo: 192.168.18.203)
  /// - Obtén tu IP con: `ipconfig` en Windows o `ifconfig` en Mac/Linux
  /// - Tu PC y dispositivo deben estar en la MISMA red WiFi
  /// 
  /// **Para EMULADOR ANDROID**: Usa 10.0.2.2
  /// - 10.0.2.2 es la IP especial que el emulador usa para acceder a localhost
  static const String apiHost = 'http://192.168.18.174:5180';
  
  // Emulador (descomenta esta línea para usar emulador)
  // static const String apiHost = 'http://10.0.2.2:5180';
  
  /// Endpoints de la API
  static const String authBaseUrl = '$apiHost/api/auth';
  static const String apiBaseUrl = '$apiHost/api';
  
  // ============================================================================
  // CONFIGURACIÓN DE SERVICIOS EN LA NUBE
  // ============================================================================
  
  /// URL del WebSocket para predicciones de ejercicios (servicio en Fly.dev)
  static const String webSocketUrl = 'wss://plank-repo.fly.dev/ws/predict';
  
  // ============================================================================
  // MÉTODOS AUXILIARES
  // ============================================================================
  
  /// Verifica si se está usando un emulador
  static bool get isEmulator => apiHost.contains('10.0.2.2');
  
  /// Verifica si se está usando un dispositivo físico
  static bool get isPhysicalDevice => !isEmulator;
}
