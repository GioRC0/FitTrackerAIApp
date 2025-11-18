import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fitracker_app/services/mediapipe_pose_detector.dart';
import 'package:fitracker_app/config/api_config.dart';
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:fitracker_app/models/training_session.dart';
import 'package:fitracker_app/services/training_session_service.dart';
import 'package:fitracker_app/screens/training/session_report_screen.dart';
import 'pose_painter_mediapipe.dart';

// ============================================================================
// WebSocketClient: Maneja comunicación con API de predicción
// ============================================================================
class WebSocketClient {
  String wsUrl;
  WebSocketChannel? _channel;
  Function(Map<String, double>)? onPrediction;
  bool _isConnected = false;

  WebSocketClient({required this.wsUrl});

  /// Sensibilidad por clase por ejercicio
  static const Map<String, Map<String, double>> _sensitivityByExercise = {
    'plank': {
      'plank_cadera_caida': 0.45,
      'plank_codos_abiertos': 0.45,
      'plank_correcto': 1.75,
      'plank_pelvis_levantada': 1.0,
    },
    'pushup': {}, // Add when available
    'squat': {}, // Add when available
  };

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      print('✅ WebSocket conectado a $wsUrl');

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            
            // Etiquetas de clases (mismo orden que Python)
            const classLabels = [
              'plank_cadera_caida',
              'plank_codos_abiertos',
              'plank_correcto',
              'plank_pelvis_levantada',
            ];

            // --- OBTENER PREDICCIÓN Y PROBABILIDADES (compatible con real_time_feedback.py) ---
            // Intentar diferentes nombres de campo para la predicción
            final pred = data['pred'] ?? 
                        data['prediction'] ?? 
                        data['class'] ?? 
                        data['predicted_class'] ?? 
                        '?';

            // Intentar diferentes nombres de campo para las probabilidades
            dynamic probas = data['proba'] ?? 
                           data['probabilities'] ?? 
                           data['probs'] ?? 
                           {};

            // Si probas es una lista, convertir a Map con class labels
            Map<String, double> rawProbs = {};
            if (probas is List) {
              for (int i = 0; i < classLabels.length && i < probas.length; i++) {
                rawProbs[classLabels[i]] = (probas[i] as num).toDouble();
              }
            } else if (probas is Map) {
              // Si ya es un dict/map, convertir valores a double
              probas.forEach((key, value) {
                rawProbs[key.toString()] = (value as num).toDouble();
              });
            }

            // Si no hay probabilidades, crear un mapa vacío
            if (rawProbs.isEmpty) {
              print('⚠️ No se encontraron probabilidades en la respuesta');
              rawProbs = {};
            }

            // --- APLICAR SENSIBILIDAD POR CLASE (como en Python) ---
            final Map<String, double> adjustedProbs = {};
            double total = 0.0;
            
            // Detectar ejercicio del primer label
            String exerciseType = 'plank';
            if (rawProbs.keys.isNotEmpty) {
              final firstLabel = rawProbs.keys.first;
              if (firstLabel.startsWith('pushup_')) exerciseType = 'pushup';
              else if (firstLabel.startsWith('squat_')) exerciseType = 'squat';
            }
            
            final sensitivity = _sensitivityByExercise[exerciseType] ?? {};
            rawProbs.forEach((label, prob) {
              final factor = sensitivity[label] ?? 1.0;
              final adjusted = prob * factor;
              adjustedProbs[label] = adjusted;
              total += adjusted;
            });

            // Normalizar
            final Map<String, double> finalProbs = total > 0.0
                ? adjustedProbs.map((k, v) => MapEntry(k, v / total))
                : rawProbs; // Si total es 0, devolver probs originales

            print('🎯 Raw: $rawProbs');
            print('⚖️ Adjusted: $finalProbs');
            print('📊 Predicción: $pred');

            onPrediction?.call(finalProbs);
          } catch (e) {
            print('❌ Error al procesar mensaje WebSocket: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _isConnected = false;
        },
        onDone: () {
          print('⚠️ WebSocket cerrado');
          _isConnected = false;
        },
      );
    } catch (e) {
      print('❌ Error al conectar WebSocket: $e');
      _isConnected = false;
    }
  }

  void sendFeatures(List<double> features) {
    if (_isConnected && _channel != null) {
      try {
        final message = jsonEncode({'features': features});
        _channel!.sink.add(message);
      } catch (e) {
        print('❌ Error al enviar features: $e');
      }
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    print('✅ WebSocket desconectado');
  }
}

// ============================================================================
// CameraTrainingScreen: Pantalla principal con detección en tiempo real
// ============================================================================
class CameraTrainingScreen extends StatefulWidget {
  final ExerciseDto exercise;
  
  const CameraTrainingScreen({super.key, required this.exercise});

  @override
  State<CameraTrainingScreen> createState() => _CameraTrainingScreenState();
}

class _CameraTrainingScreenState extends State<CameraTrainingScreen> {
  late final MediaPipePoseDetector _poseDetector;
  late final WebSocketClient _wsClient;
  CameraController? _cameraController;
  List<MediaPipePose> _poses = [];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  int _cameraIndex = 1; // 0=trasera, 1=frontal (cámara de selfie)
  Size _absoluteImageSize = Size.zero;

  // Tipo de ejercicio actual
  late String _exerciseType; // 'pushup', 'squat', 'plank'
  
  // Estado de predicción
  // ignore: unused_field
  String _currentPrediction = "";
  double _currentConfidence = 0.0;
  Map<String, double> _allProbabilities = {};
  String _currentStatus = "Iniciando...";
  int _repCounter = 0;

  // PUSHUP: Detección por picos
  final Queue<double> _pushupSignalBuffer = Queue();
  final Queue<Map<String, double>> _pushupFeaturesBuffer = Queue();
  final List<int> _pushupDetectedPeaks = [];
  int _pushupLastPeakFrame = -50;
  int _pushupFrameCount = 0;
  
  static const int _pushupBufferSize = 150;
  static const int _pushupPeakMinDistance = 25;
  static const int _pushupMarginBefore = 20;
  static const int _pushupMarginAfter = 20;
  static const double _pushupMinProminence = 0.03;
  static const double _pushupMinRange = 0.05;

  // SQUAT: State Machine
  String _squatState = 'up';
  final List<Map<String, double>> _squatCurrentRepData = [];
  static const double _squatAngleDown = 160.0;
  static const double _squatAngleUp = 170.0;
  
  // PLANK: Buffer temporal
  final List<Map<String, double>> _plankFeatureBuffer = [];
  static const int _plankBufferSizeSeconds = 1;
  static const int _plankFpsEstimado = 30;

  // Control de tiempo
  DateTime _lastProcessedTime = DateTime.now();
  static const _processingInterval = Duration(milliseconds: 33); // 30 FPS

  // Cache para suavizado EMA de landmarks
  final Map<int, List<double>> _smoothCache = {};
  static const double _emaAlpha = 0.6; // 60% nuevo, 40% anterior

  // Captura de datos de entrenamiento
  final TrainingSessionService _sessionService = TrainingSessionService();
  DateTime? _trainingStartTime;
  final List<RepData> _capturedReps = [];
  final List<SecondData> _capturedSeconds = [];
  bool _isFinishingSession = false;

  @override
  void initState() {
    super.initState();
    
    // Mapear nombre del ejercicio a tipo
    _exerciseType = _mapExerciseNameToType(widget.exercise.name);
    print('🏋️ Ejercicio seleccionado: ${widget.exercise.name} -> $_exerciseType');
    
    // Iniciar tiempo de entrenamiento
    _trainingStartTime = DateTime.now();
    
    _poseDetector = MediaPipePoseDetector();
    
    // Configurar WebSocket según ejercicio
    final wsUrl = _getWebSocketUrl(_exerciseType);
    _wsClient = WebSocketClient(wsUrl: wsUrl);
    _wsClient.onPrediction = _handlePrediction;
    
    _initializeMediaPipe();
    _initializeWebSocket();
    _initializeCamera();
  }
  
  String _mapExerciseNameToType(String exerciseName) {
    final normalized = exerciseName.toLowerCase();
    if (normalized.contains('push') || normalized.contains('flexion')) {
      return 'pushup';
    } else if (normalized.contains('sentadilla') || normalized.contains('squat')) {
      return 'squat';
    } else if (normalized.contains('plancha') || normalized.contains('plank')) {
      return 'plank';
    }
    return 'plank'; // Default
  }
  
  String _getWebSocketUrl(String exerciseType) {
    // Usar API base de configuración y agregar endpoint específico
    final baseUrl = ApiConfig.webSocketUrl.split('/ws')[0];
    return '$baseUrl/ws/$exerciseType';
  }

  Future<void> _initializeMediaPipe() async {
    try {
      print('🔄 Inicializando MediaPipe...');
      await _poseDetector.initialize(
        minDetectionConfidence: 0.7,
        minTrackingConfidence: 0.7,
      );
      print('✅ MediaPipe inicializado correctamente');
    } catch (e) {
      print('❌ Error al inicializar MediaPipe: $e');
    }
  }

  Future<void> _initializeWebSocket() async {
    await _wsClient.connect();
    if (mounted) {
      setState(() => _currentStatus = "WebSocket conectado");
    }
  }

  Future<void> _initializeCamera() async {
    if (await Permission.camera.request().isGranted) {
      final cameras = await availableCameras();
      print('📷 Cámaras disponibles: ${cameras.length}');
      for (var i = 0; i < cameras.length; i++) {
        print('  Cámara $i: ${cameras[i].lensDirection} (${cameras[i].name})');
      }
      if (cameras.isEmpty) {
        print("❌ No se encontraron cámaras.");
        return;
      }

      _cameraIndex = _cameraIndex < cameras.length ? _cameraIndex : 0;

      _cameraController = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _currentStatus = "Listo para entrenar";
        });
      }
    } else {
      print("❌ Permiso de cámara denegado.");
    }
  }

  // MediaPipe no necesita conversión de InputImage, procesa directamente CameraImage

  /// Aplica suavizado EMA (Exponential Moving Average) a los landmarks
  /// Formula: smoothed = alpha * current + (1 - alpha) * previous
  Map<int, MediaPipeLandmark> _smoothPose(Map<int, MediaPipeLandmark> currentLandmarks) {
    final Map<int, MediaPipeLandmark> smoothed = {};

    currentLandmarks.forEach((index, landmark) {
      final x = landmark.x;
      final y = landmark.y;

      if (_smoothCache.containsKey(index)) {
        final prev = _smoothCache[index]!;
        final smoothedX = _emaAlpha * x + (1 - _emaAlpha) * prev[0];
        final smoothedY = _emaAlpha * y + (1 - _emaAlpha) * prev[1];
        _smoothCache[index] = [smoothedX, smoothedY];

        smoothed[index] = MediaPipeLandmark(
          x: smoothedX,
          y: smoothedY,
          z: landmark.z,
          likelihood: landmark.likelihood,
        );
      } else {
        _smoothCache[index] = [x, y];
        smoothed[index] = landmark;
      }
    });

    return smoothed;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;

    final now = DateTime.now();
    if (now.difference(_lastProcessedTime) < _processingInterval) {
      return;
    }
    _lastProcessedTime = now;

    _isProcessing = true;

    // Guardar tamaño original de la imagen de cámara (landscape en Android)
    _absoluteImageSize = Size(image.width.toDouble(), image.height.toDouble());

    try {
      final result = await _poseDetector.processImage(
        imageData: image.planes[0].bytes,
        width: image.width,
        height: image.height,
      );

      if (mounted && result != null && result.poses.isNotEmpty) {
        final pose = result.poses.first;

        // Aplicar suavizado EMA
        final smoothedLandmarks = _smoothPose(pose.landmarks);
        final smoothedPose = MediaPipePose(landmarks: smoothedLandmarks);

        setState(() {
          _poses = [smoothedPose];
        });

        try {
          // Procesar según tipo de ejercicio
          if (_exerciseType == 'pushup') {
            _processPushupFrame(smoothedLandmarks);
          } else if (_exerciseType == 'squat') {
            _processSquatFrame(smoothedLandmarks);
          } else if (_exerciseType == 'plank') {
            _processPlankFrame(smoothedLandmarks);
          }
        } catch (e) {
          print('❌ Error al procesar frame: $e');
        }
      } else if (result == null || result.poses.isEmpty) {
        _clearExerciseBuffers();
        if (_currentStatus != "No se detecta cuerpo") {
          setState(() {
            _currentStatus = "No se detecta cuerpo";
            _currentPrediction = "";
            _currentConfidence = 0.0;
            _allProbabilities = {};
          });
        }
      }
    } catch (e) {
      print("❌ Error al procesar imagen: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _clearExerciseBuffers() {
    if (_exerciseType == 'pushup') {
      _pushupSignalBuffer.clear();
      _pushupFeaturesBuffer.clear();
    } else if (_exerciseType == 'squat') {
      _squatCurrentRepData.clear();
    } else if (_exerciseType == 'plank') {
      _plankFeatureBuffer.clear();
    }
  }

  /// Calcula el ángulo entre tres puntos (en grados)
  double _calculateAngle(List<double> a, List<double> b, List<double> c) {
    final radians = atan2(c[1] - b[1], c[0] - b[0]) - 
                   atan2(a[1] - b[1], a[0] - b[0]);
    var angle = radians.abs() * 180.0 / pi;
    if (angle > 180.0) {
      angle = 360 - angle;
    }
    return angle;
  }
  
  bool _validLandmark(MediaPipeLandmark? lm) {
    return lm != null && lm.x >= 0 && lm.x <= 1 && lm.y >= 0 && lm.y <= 1;
  }

  // ========== PUSHUP FEATURE EXTRACTION ==========
  Map<String, double>? _extractPushupFeatures(Map<int, MediaPipeLandmark> landmarks) {
    final shoulderL = landmarks[MediaPipePoseLandmark.leftShoulder];
    final hipL = landmarks[MediaPipePoseLandmark.leftHip];
    final ankleL = landmarks[MediaPipePoseLandmark.leftAnkle];
    final elbowL = landmarks[MediaPipePoseLandmark.leftElbow];
    final wristL = landmarks[MediaPipePoseLandmark.leftWrist];

    if (!_validLandmark(shoulderL) || !_validLandmark(hipL) || 
        !_validLandmark(ankleL) || !_validLandmark(elbowL) || !_validLandmark(wristL)) {
      return null;
    }

    final shoulder = [shoulderL!.x, shoulderL.y];
    final hip = [hipL!.x, hipL.y];
    final ankle = [ankleL!.x, ankleL.y];
    final elbow = [elbowL!.x, elbowL.y];
    final wrist = [wristL!.x, wristL.y];

    return {
      'body_angle': _calculateAngle(shoulder, hip, ankle),
      'hip_shoulder_vertical_diff': hip[1] - shoulder[1],
      'hip_ankle_vertical_diff': hip[1] - ankle[1],
      'shoulder_elbow_angle': _calculateAngle(hip, shoulder, elbow),
      'wrist_shoulder_hip_angle': _calculateAngle(wrist, shoulder, hip),
      'shoulder_wrist_vertical_diff': shoulder[1] - wrist[1],
    };
  }

  // ========== SQUAT FEATURE EXTRACTION ==========
  Map<String, double>? _extractSquatFeatures(Map<int, MediaPipeLandmark> landmarks) {
    final shoulderL = landmarks[MediaPipePoseLandmark.leftShoulder];
    final shoulderR = landmarks[MediaPipePoseLandmark.rightShoulder];
    final hipL = landmarks[MediaPipePoseLandmark.leftHip];
    final hipR = landmarks[MediaPipePoseLandmark.rightHip];
    final kneeL = landmarks[MediaPipePoseLandmark.leftKnee];
    final kneeR = landmarks[MediaPipePoseLandmark.rightKnee];
    final ankleL = landmarks[MediaPipePoseLandmark.leftAnkle];
    final ankleR = landmarks[MediaPipePoseLandmark.rightAnkle];

    if (!_validLandmark(shoulderL) || !_validLandmark(shoulderR) ||
        !_validLandmark(hipL) || !_validLandmark(hipR) ||
        !_validLandmark(kneeL) || !_validLandmark(kneeR) ||
        !_validLandmark(ankleL) || !_validLandmark(ankleR)) {
      return null;
    }

    final shoulder_l = [shoulderL!.x, shoulderL.y];
    final shoulder_r = [shoulderR!.x, shoulderR.y];
    final hip_l = [hipL!.x, hipL.y];
    final hip_r = [hipR!.x, hipR.y];
    final knee_l = [kneeL!.x, kneeL.y];
    final knee_r = [kneeR!.x, kneeR.y];
    final ankle_l = [ankleL!.x, ankleL.y];
    final ankle_r = [ankleR!.x, ankleR.y];

    final leftKneeAngle = _calculateAngle(hip_l, knee_l, ankle_l);
    final rightKneeAngle = _calculateAngle(hip_r, knee_r, ankle_r);
    final leftHipAngle = _calculateAngle(shoulder_l, hip_l, knee_l);
    final rightHipAngle = _calculateAngle(shoulder_r, hip_r, knee_r);

    return {
      'left_knee_angle': leftKneeAngle,
      'right_knee_angle': rightKneeAngle,
      'left_hip_angle': leftHipAngle,
      'right_hip_angle': rightHipAngle,
      'knee_distance': (knee_l[0] - knee_r[0]).abs(),
      'hip_shoulder_distance': (hip_l[0] - shoulder_l[0]).abs(),
      'avg_knee_angle': (leftKneeAngle + rightKneeAngle) / 2,
      'avg_hip_angle': (leftHipAngle + rightHipAngle) / 2,
    };
  }

  // ========== PLANK FEATURE EXTRACTION ==========
  Map<String, double>? _extractPlankFeatures(Map<int, MediaPipeLandmark> landmarks) {
    final shoulderL = landmarks[MediaPipePoseLandmark.leftShoulder];
    final elbowL = landmarks[MediaPipePoseLandmark.leftElbow];
    final hipL = landmarks[MediaPipePoseLandmark.leftHip];
    final ankleL = landmarks[MediaPipePoseLandmark.leftAnkle];
    final wristL = landmarks[MediaPipePoseLandmark.leftWrist];

    if (!_validLandmark(shoulderL) || !_validLandmark(elbowL) ||
        !_validLandmark(hipL) || !_validLandmark(ankleL) || !_validLandmark(wristL)) {
      return null;
    }

    final shoulder = [shoulderL!.x, shoulderL.y];
    final elbow = [elbowL!.x, elbowL.y];
    final hip = [hipL!.x, hipL.y];
    final ankle = [ankleL!.x, ankleL.y];
    final wrist = [wristL!.x, wristL.y];

    return {
      'body_angle': _calculateAngle(shoulder, hip, ankle),
      'hip_shoulder_vertical_diff': hip[1] - shoulder[1],
      'hip_ankle_vertical_diff': hip[1] - ankle[1],
      'shoulder_elbow_angle': _calculateAngle(hip, shoulder, elbow),
      'wrist_shoulder_hip_angle': _calculateAngle(wrist, shoulder, hip),
    };
  }

  // ========== EXERCISE-SPECIFIC PROCESSING ==========
  
  void _processPushupFrame(Map<int, MediaPipeLandmark> landmarks) {
    final features = _extractPushupFeatures(landmarks);
    if (features == null) return;

    final shoulderWristVerticalDiff = features['shoulder_wrist_vertical_diff']!;
    
    _pushupSignalBuffer.add(shoulderWristVerticalDiff);
    _pushupFeaturesBuffer.add(features);
    _pushupFrameCount++;

    if (_pushupSignalBuffer.length > _pushupBufferSize) {
      _pushupSignalBuffer.removeFirst();
      _pushupFeaturesBuffer.removeFirst();
    }

    // Detección de picos (simplified peak detection - full savgol_filter would need external package)
    if (_pushupSignalBuffer.length >= 50) {
      final signal = _pushupSignalBuffer.toList();
      final signalRange = signal.reduce(max) - signal.reduce(min);
      final signalMin = signal.reduce(min);

      if (signalRange > 0.05) {
        final heightThreshold = signalMin + (signalRange * 0.40);
        
        // Simple peak detection: find local maxima above threshold
        for (int i = _pushupPeakMinDistance; i < signal.length - _pushupMarginAfter; i++) {
          if (signal[i] > heightThreshold &&
              signal[i] > signal[i - 1] &&
              signal[i] > signal[i + 1]) {
            
            final globalPeakIdx = _pushupFrameCount - _pushupSignalBuffer.length + i;
            
            if (!_pushupDetectedPeaks.contains(globalPeakIdx) &&
                (globalPeakIdx - _pushupLastPeakFrame) >= _pushupPeakMinDistance) {
              
              final startIdx = max(0, i - _pushupMarginBefore);
              final endIdx = min(_pushupFeaturesBuffer.length, i + _pushupMarginAfter);
              
              final windowFeatures = _pushupFeaturesBuffer.toList().sublist(startIdx, endIdx);
              
              if (windowFeatures.length >= 30) {
                final swValues = windowFeatures.map((f) => f['shoulder_wrist_vertical_diff']!).toList();
                final swRange = swValues.reduce(max) - swValues.reduce(min);
                
                if (swRange >= _pushupMinRange) {
                  _repCounter++;
                  _pushupDetectedPeaks.add(globalPeakIdx);
                  _pushupLastPeakFrame = globalPeakIdx;
                  
                  print('🔍 PUSHUP Rep $_repCounter detectada, enviando ${windowFeatures.length} frames');
                  
                  // Enviar frames como lista de diccionarios
                  final message = jsonEncode({'frames': windowFeatures});
                  _wsClient._channel?.sink.add(message);
                  
                  setState(() {
                    _currentStatus = 'Rep $_repCounter detectada! Clasificando...';
                  });
                  
                  break;
                }
              }
            }
          }
        }
      }
    }

    if (mounted && _currentStatus == "Iniciando...") {
      setState(() {
        _currentStatus = 'Listo - Haz flexiones';
      });
    }
  }

  void _processSquatFrame(Map<int, MediaPipeLandmark> landmarks) {
    final features = _extractSquatFeatures(landmarks);
    if (features == null) return;

    final avgKneeAngle = features['avg_knee_angle']!;

    // State machine
    if (avgKneeAngle < _squatAngleDown && _squatState == 'up') {
      _squatState = 'down';
      _squatCurrentRepData.clear();
    }

    if (_squatState == 'down') {
      _squatCurrentRepData.add(features);
    }

    if (avgKneeAngle > _squatAngleUp && _squatState == 'down') {
      _squatState = 'up';
      _repCounter++;

      if (_squatCurrentRepData.isNotEmpty) {
        print('🔍 SQUAT Rep $_repCounter completada, enviando ${_squatCurrentRepData.length} frames');
        
        final message = jsonEncode({'frames': _squatCurrentRepData});
        _wsClient._channel?.sink.add(message);
        
        setState(() {
          _currentStatus = 'Rep $_repCounter completada! Clasificando...';
        });
      }
    }

    if (mounted && _currentStatus == "Iniciando...") {
      setState(() {
        _currentStatus = _squatState == 'up' ? 'Listo para bajar' : 'Bajando...';
      });
    }
  }

  void _processPlankFrame(Map<int, MediaPipeLandmark> landmarks) {
    final features = _extractPlankFeatures(landmarks);
    if (features == null) return;

    _plankFeatureBuffer.add(features);

    final bufferSize = _plankBufferSizeSeconds * _plankFpsEstimado;

    if (_plankFeatureBuffer.length >= bufferSize) {
      print('🔍 PLANK Buffer completo, enviando ${_plankFeatureBuffer.length} frames');
      
      final message = jsonEncode({'frames': _plankFeatureBuffer});
      _wsClient._channel?.sink.add(message);
      
      _plankFeatureBuffer.clear();
      
      setState(() {
        _currentStatus = "Clasificando postura...";
      });
    } else {
      if (mounted) {
        setState(() {
          _currentStatus = 'Analizando... (${_plankFeatureBuffer.length}/$bufferSize)';
        });
      }
    }
  }

  void _handlePrediction(Map<String, double> probabilities) {
    if (!mounted) return;

    final sortedEntries = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final best = sortedEntries.first;

    setState(() {
      _currentPrediction = best.key;
      _currentConfidence = best.value;
      _allProbabilities = Map.fromEntries(sortedEntries);
      
      // Format status based on exercise
      String status = best.key
          .replaceAll('${_exerciseType}_', '')
          .replaceAll('_', ' ');
      
      if (_exerciseType == 'plank') {
        _currentStatus = '$status (${(best.value * 100).toStringAsFixed(0)}%)';
      } else {
        _currentStatus = 'Rep $_repCounter: $status (${(best.value * 100).toStringAsFixed(0)}%)';
      }
    });

    // Capturar datos para el reporte
    _captureTrainingData(best.key, best.value, probabilities);
  }

  void _captureTrainingData(
    String classification,
    double confidence,
    Map<String, double> probabilities,
  ) {
    if (_exerciseType == 'pushup' || _exerciseType == 'squat') {
      // Solo capturar cuando se completa una repetición
      if (_repCounter > _capturedReps.length) {
        _capturedReps.add(RepData(
          repNumber: _repCounter,
          classification: classification,
          confidence: confidence,
          probabilities: probabilities,
          timestamp: DateTime.now(),
        ));
        print('📊 Capturada rep $_repCounter: $classification (${(confidence * 100).toStringAsFixed(0)}%)');
      }
    } else if (_exerciseType == 'plank') {
      // Capturar cada segundo
      _capturedSeconds.add(SecondData(
        secondNumber: _capturedSeconds.length + 1,
        classification: classification,
        confidence: confidence,
        probabilities: probabilities,
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _finishTraining() async {
    if (_isFinishingSession) return;

    setState(() {
      _isFinishingSession = true;
    });

    try {
      // Detener cámara y streams
      await _cameraController?.stopImageStream();
      _wsClient.disconnect();

      if (_trainingStartTime == null) {
        print('⚠️ No hay tiempo de inicio de entrenamiento');
        return;
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(_trainingStartTime!);

      print('📊 Finalizando entrenamiento:');
      print('   - Ejercicio: $_exerciseType');
      print('   - Duración: ${duration.inSeconds}s');
      print('   - Reps capturadas: ${_capturedReps.length}');
      print('   - Segundos capturados: ${_capturedSeconds.length}');

      // Calcular métricas
      final metrics = _sessionService.calculateMetrics(
        exerciseType: _exerciseType,
        repsData: _exerciseType != 'plank' ? _capturedReps : null,
        secondsData: _exerciseType == 'plank' ? _capturedSeconds : null,
        durationSeconds: duration.inSeconds,
      );

      // Crear sesión de entrenamiento
      final sessionData = TrainingSessionData(
        exerciseId: widget.exercise.id,
        exerciseType: _exerciseType,
        exerciseName: widget.exercise.name,
        startTime: _trainingStartTime!,
        endTime: endTime,
        durationSeconds: duration.inSeconds,
        totalReps: _exerciseType != 'plank' ? _repCounter : null,
        repsData: _exerciseType != 'plank' ? _capturedReps : null,
        totalSeconds: _exerciseType == 'plank' ? _capturedSeconds.length : null,
        secondsData: _exerciseType == 'plank' ? _capturedSeconds : null,
        metrics: metrics,
      );

      // Enviar al backend
      print('📤 Enviando sesión al backend...');
      final response = await _sessionService.saveTrainingSession(sessionData);

      if (response != null) {
        print('✅ Sesión guardada exitosamente con ID: ${response.id}');
      } else {
        print('⚠️ No se pudo guardar la sesión en el backend');
      }

      // Navegar a la pantalla de reporte
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SessionReportScreen(
              sessionData: sessionData,
              exercise: widget.exercise,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error al finalizar entrenamiento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isFinishingSession = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector.dispose();
    _wsClient.disconnect();
    super.dispose();
  }

  Future<void> _switchCamera() async {
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    _clearExerciseBuffers();
    setState(() {
      _isCameraInitialized = false;
      _cameraIndex = _cameraIndex == 0 ? 1 : 0;
      _currentStatus = "Cambiando cámara...";
    });
    await _initializeCamera();
  }

  Widget _buildFeedbackPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.exercise.name.toUpperCase()} - ${_exerciseType.toUpperCase()}',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'ESTADO:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentStatus.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(_currentStatus),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'CONFIANZA:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _currentConfidence > 0.0
                    ? '${(_currentConfidence * 100).toStringAsFixed(0)}%'
                    : '--',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_exerciseType != 'pushup' && _exerciseType != 'squat') ...[  
            LinearProgressIndicator(
              value: _exerciseType == 'plank'
                  ? _plankFeatureBuffer.length / (_plankBufferSizeSeconds * _plankFpsEstimado)
                  : 0.0,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buffer: ${_plankFeatureBuffer.length}/${_plankBufferSizeSeconds * _plankFpsEstimado}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (_exerciseType == 'pushup' || _exerciseType == 'squat') ...[  
            Text(
              'Repeticiones: $_repCounter',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (_allProbabilities.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'DETALLE:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._allProbabilities.entries.take(4).map((entry) {
              final displayName =
                  entry.key.replaceAll('plank_', '').replaceAll('_', ' ');
              final percentage = (entry.value * 100).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '- $displayName: $percentage%',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('correcto')) {
      return Colors.greenAccent;
    } else if (status.contains('No se detecta')) {
      return Colors.orangeAccent;
    } else if (status.contains('Error') || status.contains('Iniciando')) {
      return Colors.grey;
    } else {
      return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamiento en Vivo'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _switchCamera,
            tooltip: 'Cambiar cámara',
          ),
          if (!_isFinishingSession)
            TextButton.icon(
              onPressed: _finishTraining,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text(
                'Finalizar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_isFinishingSession)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cámara ocupando toda la pantalla
          CameraPreview(_cameraController!),
          
          // Overlay de poses detectadas
          if (_poses.isNotEmpty)
            CustomPaint(
              painter: PosePainterMediaPipe(
                poses: _poses,
                absoluteImageSize: _absoluteImageSize,
                cameraLensDirection:
                    _cameraController!.description.lensDirection,
              ),
            ),
          
          // Panel de feedback sobre la cámara
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _buildFeedbackPanel(),
          ),
        ],
      ),
    );
  }
}
