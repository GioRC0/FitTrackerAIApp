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

  // Sin ajustes de sensibilidad - el servidor Python maneja eso

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      print('✅ WebSocket conectado a $wsUrl');

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            print('📥 Respuesta WebSocket: $data');
            
            // Obtener predicción y probabilidades (formato del servidor Python)
            final prediction = data['prediction'] ?? data['pred'] ?? '';
            final confidence = (data['confidence'] ?? 0.0) as num;
            
            // Probabilidades vienen como Map
            final Map<String, double> probabilities = {};
            if (data['probabilities'] != null) {
              final probs = data['probabilities'] as Map;
              probs.forEach((key, value) {
                probabilities[key.toString()] = (value as num).toDouble();
              });
            }

            print('📊 Predicción: $prediction (${(confidence * 100).toStringAsFixed(0)}%)');
            
            // Notificar callback
            if (onPrediction != null) {
              onPrediction!(probabilities);
            }
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

  void sendFeatures(dynamic data) {
    if (_isConnected && _channel != null) {
      try {
        final message = jsonEncode(data);
        _channel!.sink.add(message);
        
        // LOG COMPLETO del JSON enviado
        print('📤 ==================== ENVIANDO AL API ====================');
        print('📤 Número de frames: ${data is Map && data.containsKey("frames") ? (data["frames"] as List).length : "N/A"}');
        
        if (data is Map && data.containsKey("frames")) {
          final frames = data["frames"] as List;
          if (frames.isNotEmpty) {
            print('📤 Primer frame completo:');
            print(jsonEncode(frames.first));
            if (frames.length > 1) {
              print('📤 Último frame completo:');
              print(jsonEncode(frames.last));
            }
          }
        }
        
        print('📤 JSON completo (primeros 500 chars):');
        print(message.length > 500 ? message.substring(0, 500) + '...' : message);
        print('📤 =========================================================');
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
  int _inferredLandmarksCount = 0; // Contador de landmarks inferidos en el último frame

  // PUSHUP: Detección por picos
  final Queue<double> _pushupSignalBuffer = Queue();
  final Queue<Map<String, double>> _pushupFeaturesBuffer = Queue();
  final List<int> _pushupDetectedPeaks = [];
  int _pushupLastPeakFrame = -50;
  int _pushupFrameCount = 0;
  
  // Frame counter general para debug
  int _frameCount = 0;
  
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

  // 🔥 CACHE TEMPORAL ROBUSTO: Inferencia de landmarks faltantes
  final Map<int, MediaPipeLandmark> _lastValidLandmarks = {};
  final Map<int, int> _landmarkMissingFrames = {}; // Cuántos frames lleva perdido cada landmark
  static const int _maxMissingFrames = 30; // 🔥 1 segundo a 30fps - MUY PERMISIVO
  int _consecutiveLostFrames = 0; // Contador de frames sin detección de MediaPipe

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
    // Servidor en Google Cloud con CORS habilitado
    const apiBaseUrl = 'ws://34.176.129.163:8080';
    return '$apiBaseUrl/ws/$exerciseType';
  }

  Future<void> _initializeMediaPipe() async {
    try {
      print('🔄 Inicializando MediaPipe...');
      await _poseDetector.initialize(
        minDetectionConfidence: 0.5,  // Reducido de 0.7 a 0.5 para mejor detección
        minTrackingConfidence: 0.5,   // Reducido de 0.7 a 0.5
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

  /// 🔥 INFERENCIA ROBUSTA: Rellena landmarks faltantes con últimos valores válidos
  /// Permite continuidad en la repetición incluso si algunos puntos se pierden momentáneamente
  Map<int, MediaPipeLandmark> _inferMissingLandmarks(Map<int, MediaPipeLandmark> detectedLandmarks) {
    final Map<int, MediaPipeLandmark> complete = Map.from(detectedLandmarks);
    int inferredCount = 0;
    
    // Landmarks críticos que DEBEN estar presentes para inferencia
    final criticalPoints = [
      MediaPipePoseLandmark.leftShoulder,
      MediaPipePoseLandmark.rightShoulder,
      MediaPipePoseLandmark.leftHip,
      MediaPipePoseLandmark.rightHip,
      MediaPipePoseLandmark.leftKnee,
      MediaPipePoseLandmark.rightKnee,
      MediaPipePoseLandmark.leftAnkle,
      MediaPipePoseLandmark.rightAnkle,
      MediaPipePoseLandmark.leftElbow,
      MediaPipePoseLandmark.rightElbow,
      MediaPipePoseLandmark.leftWrist,
      MediaPipePoseLandmark.rightWrist,
    ];

    // 1. Actualizar cache con landmarks detectados (buenos)
    detectedLandmarks.forEach((index, landmark) {
      if (landmark.likelihood >= 0.3) { // 🔥 Umbral MUY bajo
        _lastValidLandmarks[index] = landmark;
        _landmarkMissingFrames[index] = 0; // Resetear contador
      }
    });

    // 2. Rellenar landmarks faltantes o débiles
    for (final pointIndex in criticalPoints) {
      final detected = detectedLandmarks[pointIndex];
      
      // Si no fue detectado O tiene baja confianza
      if (detected == null || detected.likelihood < 0.3) { // 🔥 Umbral 0.3
        _landmarkMissingFrames[pointIndex] = (_landmarkMissingFrames[pointIndex] ?? 0) + 1;
        
        // Solo inferir si no ha estado perdido por demasiado tiempo
        if (_landmarkMissingFrames[pointIndex]! <= _maxMissingFrames && 
            _lastValidLandmarks.containsKey(pointIndex)) {
          
          // Usar último landmark válido con confianza reducida gradualmente
          final framesLost = _landmarkMissingFrames[pointIndex]!;
          final lastValid = _lastValidLandmarks[pointIndex]!;
          final decayFactor = 1.0 - (framesLost / _maxMissingFrames) * 0.5; // Decay 0-50%
          
          complete[pointIndex] = MediaPipeLandmark(
            x: lastValid.x,
            y: lastValid.y,
            z: lastValid.z,
            likelihood: lastValid.likelihood * decayFactor, // Decay gradual
          );
          
          inferredCount++;
          
          // Debug cada 60 frames
          if (_frameCount % 60 == 1) {
            print('🔄 Inferido: ${_getLandmarkName(pointIndex)} (perdido ${_landmarkMissingFrames[pointIndex]} frames)');
          }
        } else {
          // Ha estado perdido demasiado tiempo, eliminar del cache
          _lastValidLandmarks.remove(pointIndex);
          _landmarkMissingFrames.remove(pointIndex);
        }
      }
    }

    // Actualizar contador para UI (opcional)
    _inferredLandmarksCount = inferredCount;

    return complete;
  }

  String _getLandmarkName(int index) {
    final names = {
      MediaPipePoseLandmark.leftShoulder: 'L_Shoulder',
      MediaPipePoseLandmark.rightShoulder: 'R_Shoulder',
      MediaPipePoseLandmark.leftElbow: 'L_Elbow',
      MediaPipePoseLandmark.rightElbow: 'R_Elbow',
      MediaPipePoseLandmark.leftWrist: 'L_Wrist',
      MediaPipePoseLandmark.rightWrist: 'R_Wrist',
      MediaPipePoseLandmark.leftHip: 'L_Hip',
      MediaPipePoseLandmark.rightHip: 'R_Hip',
      MediaPipePoseLandmark.leftKnee: 'L_Knee',
      MediaPipePoseLandmark.rightKnee: 'R_Knee',
      MediaPipePoseLandmark.leftAnkle: 'L_Ankle',
      MediaPipePoseLandmark.rightAnkle: 'R_Ankle',
    };
    return names[index] ?? 'Unknown_$index';
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

      // Debug: imprimir cada 60 frames
      if (_frameCount % 60 == 0) {
        print('📷 Frame $_frameCount: result=${result != null}, poses=${result?.poses.length ?? 0}');
      }
      _frameCount++;

      if (mounted && result != null && result.poses.isNotEmpty) {
        _consecutiveLostFrames = 0; // Resetear contador
        final pose = result.poses.first;

        // 1. Aplicar suavizado EMA
        final smoothedLandmarks = _smoothPose(pose.landmarks);
        
        // 2. 🔥 INFERIR landmarks faltantes usando cache temporal
        final completeLandmarks = _inferMissingLandmarks(smoothedLandmarks);
        
        final completePose = MediaPipePose(landmarks: completeLandmarks);

        setState(() {
          _poses = [completePose];
        });

        try {
          // Debug: imprimir cada 60 frames
          if (_frameCount % 60 == 1) {
            print('🎯 Procesando frame para $_exerciseType con ${completeLandmarks.length} landmarks (${completeLandmarks.length - smoothedLandmarks.length} inferidos)');
          }
          
          // Procesar según tipo de ejercicio
          if (_exerciseType == 'pushup') {
            _processPushupFrame(completeLandmarks);
          } else if (_exerciseType == 'squat') {
            _processSquatFrame(completeLandmarks);
          } else if (_exerciseType == 'plank') {
            _processPlankFrame(completeLandmarks);
          }
        } catch (e) {
          print('❌ Error al procesar frame ($_exerciseType): $e');
          print('Stack trace: $e');
        }
      } else if (result == null || result.poses.isEmpty) {
        // 🔥 NO LIMPIAR CACHE - Usar inferencia total
        _consecutiveLostFrames++;
        
        // Si tenemos cache válido, CONTINUAR procesando con landmarks inferidos
        if (_lastValidLandmarks.isNotEmpty && _consecutiveLostFrames <= _maxMissingFrames) {
          // Crear landmarks completamente inferidos del cache
          final inferredLandmarks = _inferMissingLandmarks({});
          
          if (inferredLandmarks.isNotEmpty) {
            final inferredPose = MediaPipePose(landmarks: inferredLandmarks);
            setState(() {
              _poses = [inferredPose];
            });
            
            // Debug cada 15 frames
            if (_frameCount % 15 == 0) {
              print('⚡ MediaPipe perdió detección (${_consecutiveLostFrames}/${_maxMissingFrames}), usando 100% inferencia con ${inferredLandmarks.length} landmarks');
            }
            
            // Procesar frame con datos inferidos
            try {
              if (_exerciseType == 'pushup') {
                _processPushupFrame(inferredLandmarks);
              } else if (_exerciseType == 'squat') {
                _processSquatFrame(inferredLandmarks);
              } else if (_exerciseType == 'plank') {
                _processPlankFrame(inferredLandmarks);
              }
            } catch (e) {
              print('❌ Error procesando frame inferido: $e');
            }
          }
        } else {
          // Solo mostrar "No se detecta cuerpo" después de 30+ frames perdidos
          if (_consecutiveLostFrames > _maxMissingFrames) {
            _clearExerciseBuffers();
            _clearInferenceCache();
            
            if (_currentStatus != "No se detecta cuerpo") {
              setState(() {
                _currentStatus = "No se detecta cuerpo";
                _currentPrediction = "";
                _currentConfidence = 0.0;
                _allProbabilities = {};
              });
            }
          }
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

  void _clearInferenceCache() {
    _lastValidLandmarks.clear();
    _landmarkMissingFrames.clear();
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
    // Permitimos margen del 30% fuera de pantalla (-0.3 a 1.3)
    // 🔥 Confianza ULTRA BAJA 0.25 para aceptar landmarks muy inferidos
    return lm != null && 
           lm.likelihood > 0.25 && 
           lm.x >= -0.3 && lm.x <= 1.3 && 
           lm.y >= -0.3 && lm.y <= 1.3;
  }

  /// Normaliza y ROTA las coordenadas para que coincidan con la visión humana (Vertical)
  Map<int, MediaPipeLandmark> _normalizeLandmarks(Map<int, MediaPipeLandmark> landmarks) {
    final width = _absoluteImageSize.width;
    final height = _absoluteImageSize.height;

    // Detectar si necesitamos rotar (Caso común: Android Portrait)
    // Si el ancho del buffer es mayor que el alto, pero usamos el cel en vertical,
    // la imagen viene "acostada".
    bool needRotation = Platform.isAndroid && width > height;

    return landmarks.map((key, lm) {
      double x, y;

      if (needRotation) {
        // 🔄 INTERCAMBIO DE EJES (Rotación 90/270 grados)
        // El eje Y del sensor se convierte en el X de la pantalla
        // El eje X del sensor se convierte en el Y de la pantalla
        
        // Para cámara frontal (Selfie), normalizar e invertir X para corregir espejo
        x = 1 - (lm.y / height); 
        y = lm.x / width;  
        
        // Debug cada 60 frames
        if (_frameCount % 60 == 1 && key == MediaPipePoseLandmark.leftHip) {
          print('🔄 ROTACIÓN aplicada:');
          print('  Original: (${lm.x.toStringAsFixed(1)}, ${lm.y.toStringAsFixed(1)})');
          print('  Rotado: (${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})');
          print('  Buffer size: ${width.toInt()}x${height.toInt()}');
        }
      } else {
        // Comportamiento normal (iOS suele manejar esto mejor o Web)
        x = lm.x / width;
        y = lm.y / height;
      }

      return MapEntry(
        key,
        MediaPipeLandmark(
          x: x,
          y: y,
          z: lm.z,
          likelihood: lm.likelihood,
        ),
      );
    });
  }

  // ========== PUSHUP FEATURE EXTRACTION (MEJORADO CON DETECCIÓN DE LADO) ==========
  Map<String, double>? _extractPushupFeatures(Map<int, MediaPipeLandmark> landmarks) {
    // 1. Obtener landmarks de AMBOS lados
    final leftPoints = [
      landmarks[MediaPipePoseLandmark.leftShoulder],
      landmarks[MediaPipePoseLandmark.leftHip],
      landmarks[MediaPipePoseLandmark.leftAnkle],
      landmarks[MediaPipePoseLandmark.leftElbow],
      landmarks[MediaPipePoseLandmark.leftWrist]
    ];

    final rightPoints = [
      landmarks[MediaPipePoseLandmark.rightShoulder],
      landmarks[MediaPipePoseLandmark.rightHip],
      landmarks[MediaPipePoseLandmark.rightAnkle],
      landmarks[MediaPipePoseLandmark.rightElbow],
      landmarks[MediaPipePoseLandmark.rightWrist]
    ];

    // 2. Calcular visibilidad promedio de cada lado
    double leftScore = 0;
    double rightScore = 0;
    int leftCount = 0;
    int rightCount = 0;

    for (var lm in leftPoints) {
      if (lm != null) { leftScore += lm.likelihood; leftCount++; }
    }
    for (var lm in rightPoints) {
      if (lm != null) { rightScore += lm.likelihood; rightCount++; }
    }

    // Decidir qué lado usar
    final useLeft = leftScore >= rightScore;
    final activePoints = useLeft ? leftPoints : rightPoints;
    
    // Debug cada 60 frames
    if (_pushupFrameCount % 60 == 0) {
      print('🔍 PUSHUP Smart Detection:');
      print('  Left score: ${leftScore.toStringAsFixed(2)} ($leftCount pts)');
      print('  Right score: ${rightScore.toStringAsFixed(2)} ($rightCount pts)');
      print('  Using: ${useLeft ? "LEFT" : "RIGHT"} side');
    }

    // 3. 🔥 VALIDACIÓN PERMISIVA: Solo necesitamos los puntos ESENCIALES
    //    Shoulder, Hip y Elbow son OBLIGATORIOS. Wrist y Ankle opcionales.
    if (!_validLandmark(activePoints[0]) || // Shoulder
        !_validLandmark(activePoints[1]) || // Hip
        !_validLandmark(activePoints[3])) {  // Elbow
      if (_pushupFrameCount % 60 == 0) {
        print('  ❌ Faltan puntos esenciales (shoulder/hip/elbow)');
      }
      return null;
    }

    // 4. Extraer coordenadas del lado ganador (con fallback si falta tobillo/muñeca)
    final shoulder = [activePoints[0]!.x, activePoints[0]!.y];
    final hip = [activePoints[1]!.x, activePoints[1]!.y];
    final elbow = [activePoints[3]!.x, activePoints[3]!.y];
    
    // Ankle y Wrist son opcionales - usar estimación si faltan
    final ankle = _validLandmark(activePoints[2])
        ? [activePoints[2]!.x, activePoints[2]!.y]
        : [hip[0], hip[1] + 0.5]; // Estimación: 50% más abajo de la cadera
    
    final wrist = _validLandmark(activePoints[4])
        ? [activePoints[4]!.x, activePoints[4]!.y]
        : [elbow[0], elbow[1] + 0.15]; // Estimación: 15% más abajo del codo

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

    // Debug temporal
    if (_frameCount % 60 == 1) {
      print('🔍 SQUAT landmarks (normalizados):');
      print('  shoulderL=${_validLandmark(shoulderL)} (${shoulderL?.x.toStringAsFixed(3)}, ${shoulderL?.y.toStringAsFixed(3)})');
      print('  shoulderR=${_validLandmark(shoulderR)} (${shoulderR?.x.toStringAsFixed(3)}, ${shoulderR?.y.toStringAsFixed(3)})');
      print('  hipL=${_validLandmark(hipL)} (${hipL?.x.toStringAsFixed(3)}, ${hipL?.y.toStringAsFixed(3)})');
      print('  kneeL=${_validLandmark(kneeL)} (${kneeL?.x.toStringAsFixed(3)}, ${kneeL?.y.toStringAsFixed(3)})');
    }

    if (!_validLandmark(shoulderL) || !_validLandmark(shoulderR) ||
        !_validLandmark(hipL) || !_validLandmark(hipR) ||
        !_validLandmark(kneeL) || !_validLandmark(kneeR) ||
        !_validLandmark(ankleL) || !_validLandmark(ankleR)) {
      if (_frameCount % 60 == 1) {
        print('  ❌ Validación falló');
      }
      return null;
    }
    
    if (_frameCount % 60 == 1) {
      print('  ✅ Todos los landmarks válidos, calculando features...');
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

  // ========== PLANK FEATURE EXTRACTION (MEJORADO CON DETECCIÓN DE LADO) ==========
  Map<String, double>? _extractPlankFeatures(Map<int, MediaPipeLandmark> landmarks) {
    // 1. Obtener landmarks de AMBOS lados
    final leftPoints = [
      landmarks[MediaPipePoseLandmark.leftShoulder],
      landmarks[MediaPipePoseLandmark.leftElbow],
      landmarks[MediaPipePoseLandmark.leftHip],
      landmarks[MediaPipePoseLandmark.leftAnkle],
      landmarks[MediaPipePoseLandmark.leftWrist]
    ];

    final rightPoints = [
      landmarks[MediaPipePoseLandmark.rightShoulder],
      landmarks[MediaPipePoseLandmark.rightElbow],
      landmarks[MediaPipePoseLandmark.rightHip],
      landmarks[MediaPipePoseLandmark.rightAnkle],
      landmarks[MediaPipePoseLandmark.rightWrist]
    ];

    // 2. Calcular visibilidad promedio de cada lado
    double leftScore = 0;
    double rightScore = 0;

    for (var lm in leftPoints) {
      if (lm != null) leftScore += lm.likelihood;
    }
    for (var lm in rightPoints) {
      if (lm != null) rightScore += lm.likelihood;
    }

    // Decidir qué lado usar
    final useLeft = leftScore >= rightScore;
    final activePoints = useLeft ? leftPoints : rightPoints;

    // 3. Validar SOLO puntos esenciales (shoulder, hip, elbow)
    // Ankle y wrist pueden ser estimados si están ocultos
    if (!_validLandmark(activePoints[0]) || // Shoulder
        !_validLandmark(activePoints[2]) || // Hip
        !_validLandmark(activePoints[1])) {  // Elbow
      return null;
    }

    // 4. Extraer coordenadas del lado ganador
    final shoulder = [activePoints[0]!.x, activePoints[0]!.y];
    final elbow = [activePoints[1]!.x, activePoints[1]!.y];
    final hip = [activePoints[2]!.x, activePoints[2]!.y];
    
    // Estimar ankle si no es válido (hip + 0.5 hacia abajo)
    final ankle = _validLandmark(activePoints[3])
        ? [activePoints[3]!.x, activePoints[3]!.y]
        : [hip[0], hip[1] + 0.5];
    
    // Estimar wrist si no es válido (elbow + 0.15 hacia abajo)
    final wrist = _validLandmark(activePoints[4])
        ? [activePoints[4]!.x, activePoints[4]!.y]
        : [elbow[0], elbow[1] + 0.15];

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
    // Debug cada 60 frames
    if (_pushupFrameCount % 60 == 0) {
      print('💪 _processPushupFrame llamado (frame $_pushupFrameCount) con ${landmarks.length} landmarks');
    }
    
    final normalizedLandmarks = _normalizeLandmarks(landmarks);
    final features = _extractPushupFeatures(normalizedLandmarks);
    if (features == null) {
      if (mounted && _currentStatus != 'Posición no detectada') {
        setState(() {
          _currentStatus = 'Posición no detectada';
        });
      }
      return;
    }

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

      if (signalRange > _pushupMinRange) {
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
                  
                  // Enviar frames usando el método sendFeatures
                  _wsClient.sendFeatures({'frames': windowFeatures});
                  
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

    // Actualizar estado si aún está iniciando o sin detección
    if (mounted && (_currentStatus == "Iniciando..." || _currentStatus == "Posición no detectada" || _currentStatus == "WebSocket conectado")) {
      setState(() {
        _currentStatus = 'Listo - Haz flexiones';
      });
    }
  }

  void _processSquatFrame(Map<int, MediaPipeLandmark> landmarks) {
    // Debug cada 60 frames
    if (_frameCount % 60 == 1) {
      print('🦾 _processSquatFrame llamado con ${landmarks.length} landmarks');
    }
    
    final normalizedLandmarks = _normalizeLandmarks(landmarks);
    final features = _extractSquatFeatures(normalizedLandmarks);
    if (features == null) {
      if (mounted && _currentStatus != 'Posición no detectada') {
        setState(() {
          _currentStatus = 'Posición no detectada';
        });
      }
      return;
    }

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
        
        // Debug: imprimir primer frame para verificar formato
        if (_squatCurrentRepData.isNotEmpty) {
          final firstFrame = _squatCurrentRepData.first;
          print('📊 Primer frame de datos:');
          print('  - left_knee_angle: ${firstFrame['left_knee_angle']?.toStringAsFixed(2)}');
          print('  - avg_knee_angle: ${firstFrame['avg_knee_angle']?.toStringAsFixed(2)}');
          print('  - knee_distance: ${firstFrame['knee_distance']?.toStringAsFixed(4)}');
        }
        
        // Enviar frames usando el método sendFeatures
        _wsClient.sendFeatures({'frames': _squatCurrentRepData});
        
        setState(() {
          _currentStatus = 'Rep $_repCounter completada! Clasificando...';
        });
      }
    }

    // Actualizar estado si aún está iniciando o sin detección
    if (mounted && (_currentStatus == "Iniciando..." || _currentStatus == "Posición no detectada" || _currentStatus == "WebSocket conectado")) {
      setState(() {
        _currentStatus = _squatState == 'up' ? 'Listo para bajar' : 'Bajando...';
      });
    }
  }

  void _processPlankFrame(Map<int, MediaPipeLandmark> landmarks) {
    final normalizedLandmarks = _normalizeLandmarks(landmarks);
    final features = _extractPlankFeatures(normalizedLandmarks);
    if (features == null) {
      if (mounted && _currentStatus != 'Posición no detectada') {
        setState(() {
          _currentStatus = 'Posición no detectada';
        });
      }
      return;
    }

    _plankFeatureBuffer.add(features);

    final bufferSize = _plankBufferSizeSeconds * _plankFpsEstimado;

    if (_plankFeatureBuffer.length >= bufferSize) {
      print('🔍 PLANK Buffer completo, enviando ${_plankFeatureBuffer.length} frames');
      
      // Enviar en el mismo formato que Python: {"frames": [lista de dicts]}
      _wsClient.sendFeatures({'frames': _plankFeatureBuffer});
      
      _plankFeatureBuffer.clear();
      
      if (mounted) {
        setState(() {
          _currentStatus = "Clasificando postura...";
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _currentStatus = 'Analizando... (${_plankFeatureBuffer.length}/$bufferSize)';
        });
      }
    }
  }

  // Configuración de sensibilidad para SQUAT
  static const Map<String, double> _squatSensitivities = {
    'squat_correcto': 1.0,
    'squat_espalda_arqueada': 1.3,
    'squat_poca_profundidad': 3.0,
    'squat_valgo_rodilla': 4.0
  };

  void _handlePrediction(Map<String, double> probabilities) {
    if (!mounted) return;

    // 1. Aplicar multiplicadores si es Squat
    Map<String, double> adjustedProbabilities = Map.from(probabilities);
    
    if (_exerciseType == 'squat') {
      adjustedProbabilities.updateAll((key, value) {
        // Buscar multiplicador (default 1.0 si no existe)
        final multiplier = _squatSensitivities[key] ?? 1.0;
        return value * multiplier;
      });
    }

    // 2. Ordenar basado en probabilidades AJUSTADAS
    final sortedEntries = adjustedProbabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedEntries.isEmpty) return;

    final best = sortedEntries.first;

    // 3. Recuperar la probabilidad REAL (original) para mostrar en pantalla
    double displayConfidence = probabilities[best.key] ?? 0.0;
    
    // 🛡️ ASEGURAR que NUNCA supere 100% (máximo 1.0)
    displayConfidence = displayConfidence.clamp(0.0, 1.0);

    setState(() {
      _currentPrediction = best.key;
      _currentConfidence = displayConfidence; // Usar original limitado para UI
      _allProbabilities = Map.fromEntries(sortedEntries); // Ordenado por sensibilidad
      
      // Format status based on exercise
      String status = best.key
          .replaceAll('${_exerciseType}_', '')
          .replaceAll('_', ' ');
      
      if (_exerciseType == 'plank') {
        _currentStatus = '$status (${(displayConfidence * 100).toStringAsFixed(0)}%)';
      } else {
        _currentStatus = 'Rep $_repCounter: $status (${(displayConfidence * 100).toStringAsFixed(0)}%)';
      }
    });

    // Capturar datos para el reporte (usando probabilidades originales)
    _captureTrainingData(best.key, displayConfidence, probabilities);
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
              // 🛡️ Limitar a máximo 100%
              final clampedValue = entry.value.clamp(0.0, 1.0);
              final percentage = (clampedValue * 100).toStringAsFixed(0);
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
