import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:fitracker_app/models/training_session.dart';
import 'package:fitracker_app/models/exercise_stats.dart';
import 'package:fitracker_app/models/progress_dashboard.dart';
import 'package:fitracker_app/models/home_dashboard.dart';
import 'package:fitracker_app/config/api_config.dart';
import 'package:fitracker_app/data/auth_storage_service.dart';

class TrainingSessionService {
  final AuthStorageService _authStorage = AuthStorageService();

  /// Calcula métricas de rendimiento según el tipo de ejercicio
  PerformanceMetrics calculateMetrics({
    required String exerciseType,
    List<RepData>? repsData,
    List<SecondData>? secondsData,
    required int durationSeconds,
  }) {
    if (exerciseType == 'pushup') {
      return _calculatePushupMetrics(repsData!, durationSeconds);
    } else if (exerciseType == 'squat') {
      return _calculateSquatMetrics(repsData!, durationSeconds);
    } else if (exerciseType == 'plank') {
      return _calculatePlankMetrics(secondsData!, durationSeconds);
    }
    throw Exception('Unknown exercise type: $exerciseType');
  }

  /// Métricas para Push-ups
  PerformanceMetrics _calculatePushupMetrics(
      List<RepData> repsData, int durationSeconds) {
    if (repsData.isEmpty) {
      return PerformanceMetrics(
        techniquePercentage: 0,
        consistencyScore: 0,
        averageConfidence: 0,
        controlScore: 0,
        stabilityScore: 0,
        repsPerMinute: 0,
      );
    }

    // Técnica: % de reps correctas
    final correctReps =
        repsData.where((r) => r.classification == 'pushup_correcto').length;
    final techniquePercentage = (correctReps / repsData.length) * 100;

    // Control: 100 - avg(pushup_codos_abiertos)
    final codosAbiertosAvg = repsData
            .map((r) => r.probabilities['pushup_codos_abiertos'] ?? 0.0)
            .reduce((a, b) => a + b) /
        repsData.length;
    final controlScore = (100 - (codosAbiertosAvg * 100)).clamp(0.0, 100.0);

    // Estabilidad: 100 - avg(pushup_espalda_arqueada)
    final espaldaArqueadaAvg = repsData
            .map((r) => r.probabilities['pushup_espalda_arqueada'] ?? 0.0)
            .reduce((a, b) => a + b) /
        repsData.length;
    final stabilityScore =
        (100 - (espaldaArqueadaAvg * 100)).clamp(0.0, 100.0);

    // Consistencia: basada en desviación estándar de confidences correctas
    final correctConfidences = repsData
        .where((r) => r.classification == 'pushup_correcto')
        .map((r) => r.confidence)
        .toList();

    final consistencyScore = _calculateConsistencyScore(correctConfidences);

    // Confianza promedio
    final averageConfidence =
        repsData.map((r) => r.confidence).reduce((a, b) => a + b) /
            repsData.length;

    // Velocidad
    final repsPerMinute = (repsData.length / durationSeconds) * 60;

    return PerformanceMetrics(
      techniquePercentage: techniquePercentage,
      consistencyScore: consistencyScore,
      averageConfidence: averageConfidence,
      controlScore: controlScore,
      stabilityScore: stabilityScore,
      repsPerMinute: repsPerMinute,
    );
  }

  /// Métricas para Squats
  PerformanceMetrics _calculateSquatMetrics(
      List<RepData> repsData, int durationSeconds) {
    if (repsData.isEmpty) {
      return PerformanceMetrics(
        techniquePercentage: 0,
        consistencyScore: 0,
        averageConfidence: 0,
        depthScore: 0,
        alignmentScore: 0,
        balanceScore: 0,
        repsPerMinute: 0,
      );
    }

    final correctReps =
        repsData.where((r) => r.classification == 'squat_correcto').length;
    final techniquePercentage = (correctReps / repsData.length) * 100;

    // Profundidad: 100 - avg(squat_poca_profundidad)
    final pocaProfundidadAvg = repsData
            .map((r) => r.probabilities['squat_poca_profundidad'] ?? 0.0)
            .reduce((a, b) => a + b) /
        repsData.length;
    final depthScore = (100 - (pocaProfundidadAvg * 100)).clamp(0.0, 100.0);

    // Alineación: 100 - avg(squat_rodillas_valgus)
    final rodillasValgusAvg = repsData
            .map((r) => r.probabilities['squat_rodillas_valgus'] ?? 0.0)
            .reduce((a, b) => a + b) /
        repsData.length;
    final alignmentScore =
        (100 - (rodillasValgusAvg * 100)).clamp(0.0, 100.0);

    // Balance: 100 - avg(squat_peso_adelante)
    final pesoAdelanteAvg = repsData
            .map((r) => r.probabilities['squat_peso_adelante'] ?? 0.0)
            .reduce((a, b) => a + b) /
        repsData.length;
    final balanceScore = (100 - (pesoAdelanteAvg * 100)).clamp(0.0, 100.0);

    final correctConfidences = repsData
        .where((r) => r.classification == 'squat_correcto')
        .map((r) => r.confidence)
        .toList();

    final consistencyScore = _calculateConsistencyScore(correctConfidences);

    final averageConfidence =
        repsData.map((r) => r.confidence).reduce((a, b) => a + b) /
            repsData.length;

    final repsPerMinute = (repsData.length / durationSeconds) * 60;

    return PerformanceMetrics(
      techniquePercentage: techniquePercentage,
      consistencyScore: consistencyScore,
      averageConfidence: averageConfidence,
      depthScore: depthScore,
      alignmentScore: alignmentScore,
      balanceScore: balanceScore,
      repsPerMinute: repsPerMinute,
    );
  }

  /// Métricas para Plank
  PerformanceMetrics _calculatePlankMetrics(
      List<SecondData> secondsData, int durationSeconds) {
    if (secondsData.isEmpty) {
      return PerformanceMetrics(
        techniquePercentage: 0,
        consistencyScore: 0,
        averageConfidence: 0,
        hipScore: 0,
        coreScore: 0,
        armPositionScore: 0,
        resistanceScore: 0,
      );
    }

    // Técnica: % de tiempo en plank_correcto
    final correctSeconds =
        secondsData.where((s) => s.classification == 'plank_correcto').length;
    final techniquePercentage = (correctSeconds / secondsData.length) * 100;

    // Cadera: 100 - avg(plank_cadera_caida)
    final caderaCaidaAvg = secondsData
            .map((s) => s.probabilities['plank_cadera_caida'] ?? 0.0)
            .reduce((a, b) => a + b) /
        secondsData.length;
    final hipScore = (100 - (caderaCaidaAvg * 100)).clamp(0.0, 100.0);

    // Core: 100 - avg(plank_pelvis_levantada)
    final pelvisLevantadaAvg = secondsData
            .map((s) => s.probabilities['plank_pelvis_levantada'] ?? 0.0)
            .reduce((a, b) => a + b) /
        secondsData.length;
    final coreScore = (100 - (pelvisLevantadaAvg * 100)).clamp(0.0, 100.0);

    // Brazos: 100 - avg(plank_codos_abiertos)
    final codosAbiertosAvg = secondsData
            .map((s) => s.probabilities['plank_codos_abiertos'] ?? 0.0)
            .reduce((a, b) => a + b) /
        secondsData.length;
    final armPositionScore =
        (100 - (codosAbiertosAvg * 100)).clamp(0.0, 100.0);

    // Resistencia: tiempo sostenido / tiempo objetivo (asumimos 60 segundos como objetivo)
    final targetTime = 60;
    final resistanceScore =
        ((durationSeconds / targetTime) * 100).clamp(0.0, 100.0);

    final correctConfidences = secondsData
        .where((s) => s.classification == 'plank_correcto')
        .map((s) => s.confidence)
        .toList();

    final consistencyScore = _calculateConsistencyScore(correctConfidences);

    final averageConfidence =
        secondsData.map((s) => s.confidence).reduce((a, b) => a + b) /
            secondsData.length;

    return PerformanceMetrics(
      techniquePercentage: techniquePercentage,
      consistencyScore: consistencyScore,
      averageConfidence: averageConfidence,
      hipScore: hipScore,
      coreScore: coreScore,
      armPositionScore: armPositionScore,
      resistanceScore: resistanceScore,
    );
  }

  /// Calcula score de consistencia basado en desviación estándar
  double _calculateConsistencyScore(List<double> confidences) {
    if (confidences.isEmpty) return 0.0;

    final mean =
        confidences.reduce((a, b) => a + b) / confidences.length;
    final variance = confidences
            .map((c) => pow(c - mean, 2))
            .reduce((a, b) => a + b) /
        confidences.length;
    final stdDev = sqrt(variance);

    // Normalizar: stdDev típico 0.0 - 0.3
    // Menor desviación = mayor consistencia
    final normalizedStdDev = (stdDev / 0.3).clamp(0.0, 1.0);
    return (100 - (normalizedStdDev * 100)).clamp(0.0, 100.0);
  }

  /// Envía la sesión de entrenamiento al backend
  /// 
  /// Retorna TrainingSessionResponse si se guarda exitosamente, null si falla
  Future<TrainingSessionResponse?> saveTrainingSession(TrainingSessionData sessionData) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('❌ No hay sesión activa');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/trainingSessions';
      print('📤 Enviando sesión a: $url');
      print('📦 Datos: ${jsonEncode(sessionData.toJson())}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(sessionData.toJson()),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        
        // La API devuelve: { "message": "...", "data": { TrainingSessionResponse } }
        if (jsonResponse.containsKey('data')) {
          final sessionResponse = TrainingSessionResponse.fromJson(
            jsonResponse['data'] as Map<String, dynamic>
          );
          print('✅ Sesión guardada exitosamente con ID: ${sessionResponse.id}');
          return sessionResponse;
        }
        
        print('⚠️ Respuesta sin campo "data"');
        return null;
      } else {
        print('❌ Error al guardar sesión: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Excepción al guardar sesión: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Obtiene una sesión de entrenamiento por ID
  Future<TrainingSessionResponse?> getSessionById(String sessionId) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('❌ No hay sesión activa');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/trainingSessions/$sessionId';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonResponse.containsKey('data')) {
          return TrainingSessionResponse.fromJson(
            jsonResponse['data'] as Map<String, dynamic>
          );
        }
        return null;
      } else {
        print('❌ Error al obtener sesión: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al obtener sesión: $e');
      return null;
    }
  }

  /// Obtiene las sesiones del usuario con paginación
  Future<List<TrainingSessionResponse>> getUserSessions({
    int page = 1,
    int pageSize = 10,
    String? exerciseId,
  }) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('❌ No hay sesión activa');
        return [];
      }

      var url = '${ApiConfig.apiBaseUrl}/trainingSessions?page=$page&pageSize=$pageSize';
      if (exerciseId != null) {
        url += '&exerciseId=$exerciseId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonResponse.containsKey('data')) {
          final sessionsList = jsonResponse['data'] as List;
          return sessionsList
              .map((s) => TrainingSessionResponse.fromJson(s as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        print('❌ Error al obtener sesiones: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Excepción al obtener sesiones: $e');
      return [];
    }
  }

  /// Obtiene el progreso semanal de un ejercicio
  Future<WeeklyProgress?> getWeeklyProgress(String exerciseId) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('❌ No hay sesión activa');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/trainingSessions/weekly-progress/$exerciseId';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonResponse.containsKey('data')) {
          return WeeklyProgress.fromJson(
            jsonResponse['data'] as Map<String, dynamic>
          );
        }
        return null;
      } else {
        print('❌ Error al obtener progreso semanal: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al obtener progreso semanal: $e');
      return null;
    }
  }

  /// Obtiene las estadísticas completas de un ejercicio (resumen semanal + sesiones recientes)
  Future<ExerciseStats?> getExerciseStats(String exerciseId, {int recentLimit = 5}) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('❌ No hay sesión activa');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/trainingSessions/exercise/$exerciseId/stats?recentLimit=$recentLimit';
      print('📊 Obteniendo estadísticas: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonResponse.containsKey('data')) {
          return ExerciseStats.fromJson(
            jsonResponse['data'] as Map<String, dynamic>
          );
        }
        return null;
      } else {
        print('❌ Error al obtener estadísticas: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Excepción al obtener estadísticas: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Obtiene los datos de progreso por período (semana o mes)
  Future<ProgressData?> getProgressData(String exerciseId, {String range = 'week'}) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('❌ No hay sesión activa');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/trainingSessions/exercise/$exerciseId/progress?range=$range';
      print('📊 Obteniendo progreso: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonResponse.containsKey('data')) {
          return ProgressData.fromJson(
            jsonResponse['data'] as Map<String, dynamic>
          );
        }
        return null;
      } else {
        print('❌ Error al obtener progreso: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Excepción al obtener progreso: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Obtiene el análisis de técnica detallado
  Future<FormAnalysis?> getFormAnalysis(String exerciseId, {String range = 'week'}) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('❌ No hay sesión activa');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/trainingSessions/exercise/$exerciseId/form-analysis?range=$range';
      print('📊 Obteniendo análisis de técnica: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonResponse.containsKey('data')) {
          return FormAnalysis.fromJson(
            jsonResponse['data'] as Map<String, dynamic>
          );
        }
        return null;
      } else {
        print('❌ Error al obtener análisis de técnica: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Excepción al obtener análisis de técnica: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Obtiene los objetivos y metas del usuario para un ejercicio
  Future<Goals?> getGoals(String exerciseId) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('❌ No hay sesión activa');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/trainingSessions/exercise/$exerciseId/goals';
      print('📊 Obteniendo objetivos: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonResponse.containsKey('data')) {
          return Goals.fromJson(
            jsonResponse['data'] as Map<String, dynamic>
          );
        }
        return null;
      } else {
        print('❌ Error al obtener objetivos: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Excepción al obtener objetivos: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Obtiene el resumen del dashboard de inicio
  Future<HomeDashboard?> getHomeDashboard() async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('❌ No hay sesión activa');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/mainDashboard/home';
      print('🏠 Obteniendo dashboard de inicio: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonResponse.containsKey('data')) {
          return HomeDashboard.fromJson(
            jsonResponse['data'] as Map<String, dynamic>
          );
        }
        return null;
      } else {
        print('❌ Error al obtener dashboard: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Excepción al obtener dashboard: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}
