import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Utilidades para cálculos de pose y ángulos
class PoseUtils {
  /// Calcula el ángulo entre tres puntos (a, b, c)
  /// donde b es el vértice del ángulo
  /// Replica exactamente la función calculate_angle de Python
  static double calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    // Convertir a vectores
    final aX = a.x;
    final aY = a.y;
    final bX = b.x;
    final bY = b.y;
    final cX = c.x;
    final cY = c.y;

    // Calcular el ángulo usando atan2
    final radians = atan2(cY - bY, cX - bX) - atan2(aY - bY, aX - bX);
    var angle = radians.abs() * 180.0 / pi;
    
    // Normalizar el ángulo
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    
    return angle;
  }

  /// Extrae las 5 features básicas de un frame de pose
  /// Retorna: [body_angle, hip_shoulder_vertical_diff, hip_ankle_vertical_diff, 
  ///          shoulder_elbow_angle, wrist_shoulder_hip_angle]
  /// Google ML Kit ya devuelve coordenadas normalizadas [0, 1] igual que MediaPipe Python
  static List<double>? extractPlankFeatures(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    try {
      // Obtener landmarks necesarios
      final shoulderL = landmarks[PoseLandmarkType.leftShoulder];
      final hipL = landmarks[PoseLandmarkType.leftHip];
      final ankleL = landmarks[PoseLandmarkType.leftAnkle];
      final elbowL = landmarks[PoseLandmarkType.leftElbow];
      final wristL = landmarks[PoseLandmarkType.leftWrist];

      // Verificar que todos los landmarks existen
      if (shoulderL == null || hipL == null || ankleL == null || 
          elbowL == null || wristL == null) {
        return null;
      }

      // Google ML Kit ya devuelve coordenadas normalizadas [0, 1] como MediaPipe
      // NO necesitamos normalizar manualmente
      // Las coordenadas x, y ya están en el rango [0, 1]

      // Calcular features directamente (coordenadas ya normalizadas)
      final bodyAngle = calculateAngle(shoulderL, hipL, ankleL);
      final hipShoulderVerticalDiff = hipL.y - shoulderL.y;
      final hipAnkleVerticalDiff = hipL.y - ankleL.y;
      final shoulderElbowAngle = calculateAngle(hipL, shoulderL, elbowL);
      final wristShoulderHipAngle = calculateAngle(wristL, shoulderL, hipL);

      return [
        bodyAngle,
        hipShoulderVerticalDiff,
        hipAnkleVerticalDiff,
        shoulderElbowAngle,
        wristShoulderHipAngle,
      ];
    } catch (e) {
      return null;
    }
  }

  /// Calcula estadísticas agregadas de un buffer de features
  /// Retorna: [mean, std, min, max, range] para cada feature
  static List<double> calculateAggregatedFeatures(List<List<double>> featureBuffer) {
    if (featureBuffer.isEmpty) return [];

    final numFeatures = featureBuffer[0].length;
    final List<double> aggregated = [];

    for (int i = 0; i < numFeatures; i++) {
      // Extraer todos los valores de esta feature
      final values = featureBuffer.map((frame) => frame[i]).toList();

      // Calcular estadísticas
      final mean = _calculateMean(values);
      final std = _calculateStd(values, mean);
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);
      final range = max - min;

      aggregated.addAll([mean, std, min, max, range]);
    }

    return aggregated;
  }

  static double _calculateMean(List<double> values) {
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _calculateStd(List<double> values, double mean) {
    if (values.length < 2) return 0.0;
    final variance = values
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }
}
