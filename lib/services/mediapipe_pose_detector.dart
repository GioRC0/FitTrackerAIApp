import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Wrapper para MediaPipe Pose Landmarker nativo
class MediaPipePoseDetector {
  static const MethodChannel _channel = MethodChannel('mediapipe_pose_channel');
  
  bool _isInitialized = false;

  /// Inicializa el detector de pose con configuración personalizada
  Future<void> initialize({
    double minDetectionConfidence = 0.5,
    double minTrackingConfidence = 0.5,
  }) async {
    try {
      final result = await _channel.invokeMethod('initialize', {
        'minDetectionConfidence': minDetectionConfidence,
        'minTrackingConfidence': minTrackingConfidence,
      });
      _isInitialized = result == true;
      print('✅ MediaPipe Pose Landmarker inicializado: $_isInitialized');
    } catch (e) {
      print('❌ Error al inicializar MediaPipe: $e');
      rethrow;
    }
  }

  /// Procesa una imagen y detecta poses
  Future<MediaPipePoseResult?> processImage({
    required Uint8List imageData,
    required int width,
    required int height,
    int rotation = 0,
  }) async {
    if (!_isInitialized) {
      throw Exception('MediaPipe no está inicializado. Llama a initialize() primero.');
    }

    try {
      final result = await _channel.invokeMethod('processImage', {
        'imageData': imageData,
        'width': width,
        'height': height,
        'rotation': rotation,
      });

      if (result == null) return null;
      
      return MediaPipePoseResult.fromMap(result as Map<dynamic, dynamic>);
    } catch (e) {
      print('❌ Error al procesar imagen: $e');
      return null;
    }
  }

  /// Libera recursos del detector
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
      _isInitialized = false;
      print('✅ MediaPipe Pose Landmarker liberado');
    } catch (e) {
      print('❌ Error al liberar MediaPipe: $e');
    }
  }

  bool get isInitialized => _isInitialized;
}

/// Resultado de la detección de pose
class MediaPipePoseResult {
  final List<MediaPipePose> poses;

  MediaPipePoseResult({required this.poses});

  factory MediaPipePoseResult.fromMap(Map<dynamic, dynamic> map) {
    final posesData = map['poses'] as List<dynamic>;
    final poses = posesData
        .map((poseData) => MediaPipePose.fromMap(poseData as Map<dynamic, dynamic>))
        .toList();
    
    return MediaPipePoseResult(poses: poses);
  }
}

/// Representa una pose detectada
class MediaPipePose {
  final Map<int, MediaPipeLandmark> landmarks;

  MediaPipePose({required this.landmarks});

  factory MediaPipePose.fromMap(Map<dynamic, dynamic> map) {
    final landmarksData = map['landmarks'] as Map<dynamic, dynamic>;
    final landmarks = <int, MediaPipeLandmark>{};
    
    landmarksData.forEach((key, value) {
      final index = int.parse(key.toString());
      landmarks[index] = MediaPipeLandmark.fromMap(value as Map<dynamic, dynamic>);
    });
    
    return MediaPipePose(landmarks: landmarks);
  }

  /// Obtiene un landmark por su índice (MediaPipe Pose tiene 33 landmarks)
  MediaPipeLandmark? getLandmark(int index) => landmarks[index];
}

/// Representa un landmark (punto clave) de la pose
class MediaPipeLandmark {
  final double x;
  final double y;
  final double z;
  final double likelihood;

  MediaPipeLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  factory MediaPipeLandmark.fromMap(Map<dynamic, dynamic> map) {
    return MediaPipeLandmark(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num).toDouble(),
      likelihood: (map['likelihood'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'Landmark(x: $x, y: $y, z: $z, confidence: $likelihood)';
}

/// Índices de landmarks de MediaPipe Pose (33 puntos clave)
class MediaPipePoseLandmark {
  static const int nose = 0;
  static const int leftEyeInner = 1;
  static const int leftEye = 2;
  static const int leftEyeOuter = 3;
  static const int rightEyeInner = 4;
  static const int rightEye = 5;
  static const int rightEyeOuter = 6;
  static const int leftEar = 7;
  static const int rightEar = 8;
  static const int mouthLeft = 9;
  static const int mouthRight = 10;
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftPinky = 17;
  static const int rightPinky = 18;
  static const int leftIndex = 19;
  static const int rightIndex = 20;
  static const int leftThumb = 21;
  static const int rightThumb = 22;
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
  static const int leftHeel = 29;
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;
  static const int rightFootIndex = 32;
}
