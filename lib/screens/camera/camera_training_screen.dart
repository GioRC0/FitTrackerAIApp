import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fitracker_app/services/mediapipe_pose_detector.dart';
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:fitracker_app/models/training_session.dart';
import 'package:fitracker_app/services/training_session_service.dart';
import 'package:fitracker_app/screens/training/session_report_screen.dart';
import 'pose_painter_mediapipe.dart';

// ============================================================================
// AudioFeedbackManager: Maneja reproducción de audios de feedback
// ============================================================================
class AudioFeedbackManager {
  // 🔥 Dos players separados para evitar que se corten entre sí
  final AudioPlayer _repetitionPlayer = AudioPlayer();
  final AudioPlayer _feedbackPlayer = AudioPlayer();
  final Random _random = Random();
  
  // 🔥 Variable para tipo de voz (configurable a futuro)
  String voiceType = 'voice1'; // 'voice1' o 'voice2'
  
  // Constructor para configurar los players
  AudioFeedbackManager() {
    _configurePlayer();
  }
  
  void _configurePlayer() async {
    // Configurar ambos players con baja latencia
    await _repetitionPlayer.setReleaseMode(ReleaseMode.stop);
    await _repetitionPlayer.setVolume(1.0);
    await _repetitionPlayer.setPlayerMode(PlayerMode.lowLatency);
    
    await _feedbackPlayer.setReleaseMode(ReleaseMode.stop);
    await _feedbackPlayer.setVolume(1.0);
    await _feedbackPlayer.setPlayerMode(PlayerMode.lowLatency);
    
    print('🔧 AudioPlayers configurados (2 instancias): Volume=1.0, Mode=lowLatency');
  }
  
  // Mapeo de errores a carpetas
  static const Map<String, String> _pushupPlankErrors = {
    'cadera_caida': 'cadera_caida',
    'codos_abiertos': 'codos_abiertos',
    'pelvis_levantada': 'pelvis_levantada',
  };
  
  static const Map<String, String> _squatErrors = {
    'espalda_arqueada': 'espalda_arqueada',
    'poca_profundidad': 'poca_profundidad',
    'valgo_rodilla': 'valgo_rodilla',
  };
  
  // Cantidad de audios por carpeta (ajustar según tus archivos)
  static const int _correctoAudioCount = 8;
  static const int _terminarAudioCount = 8;
  static const int _errorAudioCount = 6; // pushup/plank/squat errores
  
  Future<void> playRepetition() async {
    try {
      // 🔥 Usar player dedicado para repeticiones
      await _repetitionPlayer.stop();
      await _repetitionPlayer.play(AssetSource('sounds/repetition.mp3'));
      print('🔊 Audio: Repetición reproducida');
    } catch (e) {
      print('❌ Error reproduciendo repetition: $e');
    }
  }
  
  Future<void> playCorrecto() async {
    try {
      final audioNum = _random.nextInt(_correctoAudioCount) + 1;
      await _feedbackPlayer.stop();
      await _feedbackPlayer.play(AssetSource('sounds/correcto/$voiceType/$audioNum.mp3'));
      print('🔊 Audio: Correcto ($voiceType/$audioNum)');
    } catch (e) {
      print('❌ Error reproduciendo correcto: $e');
    }
  }
  
  Future<void> playTerminarEjercicio() async {
    try {
      final audioNum = _random.nextInt(_terminarAudioCount) + 1;
      await _feedbackPlayer.stop();
      await _feedbackPlayer.play(AssetSource('sounds/terminar_ejercicio/$voiceType/$audioNum.mp3'));
      print('🔊 Audio: Terminar ejercicio ($voiceType/$audioNum)');
    } catch (e) {
      print('❌ Error reproduciendo terminar: $e');
    }
  }
  
  Future<void> playPushupPlankError(String errorType) async {
    try {
      final folder = _pushupPlankErrors[errorType];
      if (folder == null) {
        print('⚠️ Error desconocido para pushup/plank: $errorType');
        return;
      }
      
      final audioNum = _random.nextInt(_errorAudioCount) + 1;
      await _feedbackPlayer.stop();
      await _feedbackPlayer.play(AssetSource('sounds/pushup y plank/$folder/$voiceType/$audioNum.mp3'));
      print('🔊 Audio: Pushup/Plank error $errorType ($voiceType/$audioNum)');
    } catch (e) {
      print('❌ Error reproduciendo pushup/plank error: $e');
    }
  }
  
  Future<void> playSquatError(String errorType) async {
    try {
      final folder = _squatErrors[errorType];
      if (folder == null) {
        print('⚠️ Error desconocido para squat: $errorType');
        return;
      }
      
      final audioNum = _random.nextInt(_errorAudioCount) + 1;
      await _feedbackPlayer.stop();
      await _feedbackPlayer.play(AssetSource('sounds/squat/$folder/$voiceType/$audioNum.mp3'));
      print('🔊 Audio: Squat error $errorType ($voiceType/$audioNum)');
    } catch (e) {
      print('❌ Error reproduciendo squat error: $e');
    }
  }
  
  void dispose() {
    _repetitionPlayer.dispose();
    _feedbackPlayer.dispose();
  }
}

// ============================================================================
// WebSocketClient: Maneja comunicación con API de predicción
// ============================================================================
class WebSocketClient {
  String wsUrl;
  WebSocketChannel? _channel;
  Function(Map<String, double>)? onPrediction;
  bool _isConnected = false;
  
  // 🔥 RTT (Round Trip Time) tracking
  DateTime? _lastSendTime;
  final List<int> _rttHistory = [];
  static const int _maxRttHistory = 10;

  WebSocketClient({required this.wsUrl});

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      print('✅ WebSocket conectado a $wsUrl');

      _channel!.stream.listen(
        (message) {
          try {
            // 🔥 Calcular RTT (Round Trip Time)
            if (_lastSendTime != null) {
              final rtt = DateTime.now().difference(_lastSendTime!).inMilliseconds;
              _rttHistory.add(rtt);
              
              // Mantener solo los últimos N valores
              if (_rttHistory.length > _maxRttHistory) {
                _rttHistory.removeAt(0);
              }
              
              // Calcular RTT promedio
              final avgRtt = _rttHistory.reduce((a, b) => a + b) / _rttHistory.length;
              
              print('⏱️ RTT: ${rtt}ms | Promedio: ${avgRtt.toStringAsFixed(1)}ms | Min: ${_rttHistory.reduce((a, b) => a < b ? a : b)}ms | Max: ${_rttHistory.reduce((a, b) => a > b ? a : b)}ms');
              
              _lastSendTime = null;
            }
            
            final data = jsonDecode(message);
            
            // Obtener predicción y probabilidades
            final prediction = data['prediction'] ?? data['pred'] ?? '';
            final confidence = (data['confidence'] ?? 0.0) as num;
            
            final Map<String, double> probabilities = {};
            if (data['probabilities'] != null) {
              final probs = data['probabilities'] as Map;
              probs.forEach((key, value) {
                probabilities[key.toString()] = (value as num).toDouble();
              });
            }

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
        // 🔥 Registrar tiempo de envío para calcular RTT
        _lastSendTime = DateTime.now();
        
        final message = jsonEncode(data);
        _channel!.sink.add(message);
        
        // Log del tamaño del mensaje
        final sizeKB = message.length / 1024;
        print('📤 Enviando ${sizeKB.toStringAsFixed(1)}KB al servidor...');
      } catch (e) {
        print('❌ Error al enviar features: $e');
        _lastSendTime = null;
      }
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    
    // 🔥 Mostrar estadísticas finales de RTT
    if (_rttHistory.isNotEmpty) {
      final avgRtt = _rttHistory.reduce((a, b) => a + b) / _rttHistory.length;
      final minRtt = _rttHistory.reduce((a, b) => a < b ? a : b);
      final maxRtt = _rttHistory.reduce((a, b) => a > b ? a : b);
      print('📊 Estadísticas RTT - Promedio: ${avgRtt.toStringAsFixed(1)}ms | Min: ${minRtt}ms | Max: ${maxRtt}ms | Muestras: ${_rttHistory.length}');
    }
    
    print('✅ WebSocket desconectado');
  }
  
  // Obtener RTT promedio actual
  double? getAverageRtt() {
    if (_rttHistory.isEmpty) return null;
    return _rttHistory.reduce((a, b) => a + b) / _rttHistory.length;
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
  late final AudioFeedbackManager _audioManager;
  CameraController? _cameraController;
  List<MediaPipePose> _poses = [];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  int _cameraIndex = 1; 
  Size _absoluteImageSize = Size.zero;

  // Tipo de ejercicio actual
  late String _exerciseType; 
  
  // Estado de predicción
  String _currentPrediction = "";
  double _currentConfidence = 0.0;
  Map<String, double> _allProbabilities = {};
  String _currentStatus = "Iniciando...";
  int _repCounter = 0;
  
  // 🔥 Contador de correctos seguidos para audio
  int _consecutiveCorrectCount = 0;
  
  // 🔥 Landmarks a resaltar en rojo (cuando hay error)
  Set<int> _errorLandmarks = {};
  
  // 🔥 Control de parpadeo de bordes
  bool _showBorderFlash = false;
  Color _borderFlashColor = Colors.transparent;
  double _borderOpacity = 0.0;

  // PUSHUP: State Machine (Basada en Ángulo del Codo)
  String _pushupState = 'up'; 
  final List<Map<String, double>> _pushupCurrentRepData = [];
  static const double _pushupAngleDown = 100.0;  // < 100 grados es abajo
  static const double _pushupAngleUp = 160.0;    // > 160 grados es arriba
  
  int _frameCount = 0;

  // SQUAT: State Machine
  String _squatState = 'up';
  final List<Map<String, double>> _squatCurrentRepData = [];
  static const double _squatAngleDown = 160.0;
  static const double _squatAngleUp = 170.0;
  
  // PLANK: Buffer temporal
  final List<Map<String, double>> _plankFeatureBuffer = [];
  static const int _plankBufferSizeSeconds = 1;
  static const int _plankFpsEstimado = 15;

  // Control de tiempo
  DateTime _lastProcessedTime = DateTime.now();
  static const _processingInterval = Duration(milliseconds: 33); 
  
  // 🔥 Timer para mostrar tiempo transcurrido
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0; 

  // Cache para suavizado EMA
  final Map<int, List<double>> _smoothCache = {};
  static const double _emaAlpha = 0.6; 

  // Captura de datos
  final TrainingSessionService _sessionService = TrainingSessionService();
  DateTime? _trainingStartTime;
  final List<RepData> _capturedReps = [];
  final List<SecondData> _capturedSeconds = [];
  bool _isFinishingSession = false;

  @override
  void initState() {
    super.initState();
    _exerciseType = _mapExerciseNameToType(widget.exercise.name);
    _trainingStartTime = DateTime.now();
    _poseDetector = MediaPipePoseDetector();
    _audioManager = AudioFeedbackManager();
    
    // 🔥 Iniciar timer para tiempo transcurrido
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
    
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
    return 'plank'; 
  }
  
  String _getWebSocketUrl(String exerciseType) {
    const apiBaseUrl = 'ws://34.176.129.163:8080';
    return '$apiBaseUrl/ws/$exerciseType';
  }

  Future<void> _initializeMediaPipe() async {
    await _poseDetector.initialize(
      minDetectionConfidence: 0.5, 
      minTrackingConfidence: 0.5,
    );
  }

  Future<void> _initializeWebSocket() async {
    await _wsClient.connect();
    if (mounted) setState(() => _currentStatus = "WebSocket conectado");
  }

  Future<void> _initializeCamera() async {
    if (await Permission.camera.request().isGranted) {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraIndex = _cameraIndex < cameras.length ? _cameraIndex : 0;

      _cameraController = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _currentStatus = "Listo para entrenar";
        });
      }
    }
  }

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
          x: smoothedX, y: smoothedY, z: landmark.z, likelihood: landmark.likelihood,
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
    if (now.difference(_lastProcessedTime) < _processingInterval) return;
    _lastProcessedTime = now;

    _isProcessing = true;
    _absoluteImageSize = Size(image.width.toDouble(), image.height.toDouble());

    try {
      final result = await _poseDetector.processImage(
        imageData: image.planes[0].bytes,
        width: image.width,
        height: image.height,
      );

      _frameCount++;

      if (mounted && result != null && result.poses.isNotEmpty) {
        final pose = result.poses.first;
        final smoothedLandmarks = _smoothPose(pose.landmarks);
        final completePose = MediaPipePose(landmarks: smoothedLandmarks);

        setState(() => _poses = [completePose]);

        try {
          if (_exerciseType == 'pushup') {
            _processPushupFrame(smoothedLandmarks);
          } else if (_exerciseType == 'squat') {
            _processSquatFrame(smoothedLandmarks);
          } else if (_exerciseType == 'plank') {
            _processPlankFrame(smoothedLandmarks);
          }
        } catch (e) {
          print('❌ Error al procesar frame ($_exerciseType): $e');
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
      _pushupCurrentRepData.clear();
    } else if (_exerciseType == 'squat') {
      _squatCurrentRepData.clear();
    } else if (_exerciseType == 'plank') {
      _plankFeatureBuffer.clear();
    }
  }

  double _calculateAngle(List<double> a, List<double> b, List<double> c) {
    final radians = atan2(c[1] - b[1], c[0] - b[0]) - 
                   atan2(a[1] - b[1], a[0] - b[0]);
    var angle = radians.abs() * 180.0 / pi;
    if (angle > 180.0) angle = 360 - angle;
    return angle;
  }
  
  bool _validLandmark(MediaPipeLandmark? lm) {
    return lm != null && 
           lm.likelihood > 0.3 && 
           lm.x >= -0.3 && lm.x <= 1.3 && 
           lm.y >= -0.3 && lm.y <= 1.3;
  }

  Map<int, MediaPipeLandmark> _normalizeLandmarks(Map<int, MediaPipeLandmark> landmarks) {
    final width = _absoluteImageSize.width;
    final height = _absoluteImageSize.height;
    bool needRotation = Platform.isAndroid && width > height;

    return landmarks.map((key, lm) {
      double x, y;
      if (needRotation) {
        x = 1 - (lm.y / height); 
        y = lm.x / width;  
      } else {
        x = lm.x / width;
        y = lm.y / height;
      }
      return MapEntry(key, MediaPipeLandmark(x: x, y: y, z: lm.z, likelihood: lm.likelihood));
    });
  }

  // ==========================================================================
  // 🔥 PUSHUP: SELECCIÓN DEL LADO MÁS VISIBLE (NO MEZCLAR)
  // ==========================================================================
  Map<String, double>? _extractPushupFeatures(Map<int, MediaPipeLandmark> landmarks) {
    // 1. Definir puntos IZQUIERDOS
    final leftPoints = [
      landmarks[MediaPipePoseLandmark.leftShoulder], // 0
      landmarks[MediaPipePoseLandmark.leftHip],      // 1
      landmarks[MediaPipePoseLandmark.leftAnkle],    // 2
      landmarks[MediaPipePoseLandmark.leftElbow],    // 3
      landmarks[MediaPipePoseLandmark.leftWrist]     // 4
    ];

    // 2. Definir puntos DERECHOS
    final rightPoints = [
      landmarks[MediaPipePoseLandmark.rightShoulder], // 0
      landmarks[MediaPipePoseLandmark.rightHip],      // 1
      landmarks[MediaPipePoseLandmark.rightAnkle],    // 2
      landmarks[MediaPipePoseLandmark.rightElbow],    // 3
      landmarks[MediaPipePoseLandmark.rightWrist]     // 4
    ];

    // 3. Calcular "Puntaje de Visibilidad" acumulado para cada lado
    double leftScore = 0;
    double rightScore = 0;

    for (var lm in leftPoints) { if (lm != null) leftScore += lm.likelihood; }
    for (var lm in rightPoints) { if (lm != null) rightScore += lm.likelihood; }

    // 4. 🔥 ELEGIR SOLO UN LADO (El ganador se lo lleva todo)
    final useLeft = leftScore >= rightScore;
    final activePoints = useLeft ? leftPoints : rightPoints;
    
    // Debug para verificar que está eligiendo bien
    if (_frameCount % 60 == 0) {
      print('🔍 LADO DOMINANTE: ${useLeft ? "IZQUIERDA" : "DERECHA"} (L:$leftScore vs R:$rightScore)');
    }

    // 5. 🔥 VALIDACIÓN PERMISIVA (como Python fedback_real_time.py)
    // Solo verificar que los puntos existan y tengan coordenadas razonables
    // NO validar likelihood estricto porque al bajar en flexión puede ser bajo
    if (activePoints[0] == null || // Shoulder
        activePoints[1] == null || // Hip
        activePoints[3] == null) { // Elbow
      if (_frameCount % 60 == 0) {
        print('❌ Brazo dominante con puntos nulos');
      }
      return null;
    }
    
    // Verificar que los puntos estén dentro de rango razonable
    bool pointsInRange = true;
    for (var point in [activePoints[0], activePoints[1], activePoints[3]]) {
      if (point!.x < -0.3 || point.x > 1.3 || point.y < -0.3 || point.y > 1.3) {
        pointsInRange = false;
        break;
      }
    }
    
    if (!pointsInRange) {
      if (_frameCount % 60 == 0) {
        print('❌ Puntos fuera de rango');
      }
      return null;
    }

    // 6. Extraer coordenadas (Solo del lado activo)
    final shoulder = [activePoints[0]!.x, activePoints[0]!.y];
    final hip = [activePoints[1]!.x, activePoints[1]!.y];
    final elbow = [activePoints[3]!.x, activePoints[3]!.y];
    
    // Ankle y Wrist (Usar fallback local solo si es estrictamente necesario para no romper el JSON, 
    // pero la lógica principal depende del codo que ya validamos arriba)
    final ankle = _validLandmark(activePoints[2])
        ? [activePoints[2]!.x, activePoints[2]!.y]
        : [hip[0], hip[1] + 0.4]; // Estimación relativa al mismo lado
    
    final wrist = _validLandmark(activePoints[4])
        ? [activePoints[4]!.x, activePoints[4]!.y]
        : [elbow[0], elbow[1] + 0.1]; // Estimación relativa al mismo lado

    // 7. Retornar Features
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

  // ========== PLANK FEATURE EXTRACTION (MEJORADO) ==========
  Map<String, double>? _extractPlankFeatures(Map<int, MediaPipeLandmark> landmarks) {
    // Misma lógica de "Ganador se lleva todo" para Plank
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

    double leftScore = 0;
    double rightScore = 0;
    for (var lm in leftPoints) { if (lm != null) leftScore += lm.likelihood; }
    for (var lm in rightPoints) { if (lm != null) rightScore += lm.likelihood; }

    final useLeft = leftScore >= rightScore;
    final activePoints = useLeft ? leftPoints : rightPoints;

    // Validar esenciales del lado ganador
    if (!_validLandmark(activePoints[0]) || // Shoulder
        !_validLandmark(activePoints[2]) || // Hip
        !_validLandmark(activePoints[1])) {  // Elbow
      return null;
    }

    final shoulder = [activePoints[0]!.x, activePoints[0]!.y];
    final elbow = [activePoints[1]!.x, activePoints[1]!.y];
    final hip = [activePoints[2]!.x, activePoints[2]!.y];
    
    final ankle = _validLandmark(activePoints[3])
        ? [activePoints[3]!.x, activePoints[3]!.y]
        : [hip[0], hip[1] + 0.4];
    
    final wrist = _validLandmark(activePoints[4])
        ? [activePoints[4]!.x, activePoints[4]!.y]
        : [elbow[0], elbow[1] + 0.1];

    return {
      'body_angle': _calculateAngle(shoulder, hip, ankle),
      'hip_shoulder_vertical_diff': hip[1] - shoulder[1],
      'hip_ankle_vertical_diff': hip[1] - ankle[1],
      'shoulder_elbow_angle': _calculateAngle(hip, shoulder, elbow),
      'wrist_shoulder_hip_angle': _calculateAngle(wrist, shoulder, hip),
    };
  }

  // ========== LÓGICA DE PROCESAMIENTO ==========
  
  void _processPushupFrame(Map<int, MediaPipeLandmark> landmarks) {
    final normalizedLandmarks = _normalizeLandmarks(landmarks);
    final features = _extractPushupFeatures(normalizedLandmarks);
    
    if (features == null) {
      if (mounted && _currentStatus != 'Posición no detectada') {
        setState(() => _currentStatus = 'Posición no detectada');
      }
      return;
    }

    // 🔥 LÓGICA DE MÁQUINA DE ESTADOS (Ángulo Codo)
    final elbowAngle = features['shoulder_elbow_angle']!;
    
    // 1. Detectar bajada
    if (elbowAngle < _pushupAngleDown && _pushupState == 'up') {
      _pushupState = 'down';
      _pushupCurrentRepData.clear();
    }

    // 2. Recolectar datos
    if (_pushupState == 'down') {
      _pushupCurrentRepData.add(features);
    }

    // 3. Detectar subida
    if (elbowAngle > _pushupAngleUp && _pushupState == 'down') {
      _pushupState = 'up';
      _repCounter++;
      
      // 🔊 Reproducir audio de repetición (sin await para no bloquear)
      unawaited(_audioManager.playRepetition());
      
      // Validar duración mínima
      if (_pushupCurrentRepData.length >= 10) {
        print('✅ PUSHUP Rep $_repCounter completada. Enviando ${_pushupCurrentRepData.length} frames.');
        _wsClient.sendFeatures({'frames': _pushupCurrentRepData});
      } else {
        _repCounter--; 
      }
    }

    if (mounted && (_currentStatus == "Iniciando..." || _currentStatus == "Posición no detectada" || _currentStatus == "WebSocket conectado")) {
      setState(() {
        _currentStatus = _pushupState == 'up' ? 'Baja el pecho' : 'Sube...';
      });
    }
  }

  void _processSquatFrame(Map<int, MediaPipeLandmark> landmarks) {
    final normalizedLandmarks = _normalizeLandmarks(landmarks);
    final features = _extractSquatFeatures(normalizedLandmarks);
    if (features == null) {
      if (mounted && _currentStatus != 'Posición no detectada') {
        setState(() => _currentStatus = 'Posición no detectada');
      }
      return;
    }

    final avgKneeAngle = features['avg_knee_angle']!;

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
      
      // 🔊 Reproducir audio de repetición (sin await para no bloquear)
      unawaited(_audioManager.playRepetition());

      if (_squatCurrentRepData.isNotEmpty) {
        print('🔍 SQUAT Rep $_repCounter completada, enviando ${_squatCurrentRepData.length} frames');
        _wsClient.sendFeatures({'frames': _squatCurrentRepData});
      }
    }

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
        setState(() => _currentStatus = 'Posición no detectada');
      }
      return;
    }

    _plankFeatureBuffer.add(features);

    final bufferSize = _plankBufferSizeSeconds * _plankFpsEstimado;

    if (_plankFeatureBuffer.length >= bufferSize) {
      print('🔍 PLANK Buffer completo, enviando ${_plankFeatureBuffer.length} frames');
      _wsClient.sendFeatures({'frames': _plankFeatureBuffer});
      _plankFeatureBuffer.clear();
      
      // 🔥 NO cambiar status aquí - mantener última predicción visible
    } else {
      // Solo actualizar progreso si NO hay predicción previa
      final hasNoPrediction = _currentStatus == "Iniciando..." || 
                             _currentStatus == "Posición no detectada" || 
                             _currentStatus == "WebSocket conectado";
      
      if (mounted && hasNoPrediction) {
        setState(() => _currentStatus = 'Analizando... (${_plankFeatureBuffer.length}/$bufferSize)');
      }
      // Si ya hay predicción, NO tocar _currentStatus para mantenerla visible
    }
  }

  // ==========================================================================
  // 🔥 CONFIGURACIÓN DE SENSIBILIDAD (MAPAS DE MULTIPLICADORES)
  // ==========================================================================
  
  static const Map<String, double> _squatSensitivities = {
    'squat_correcto': 1.0,
    'squat_espalda_arqueada': 1.3,
    'squat_poca_profundidad': 3.0,
    'squat_valgo_rodilla': 4.0
  };

  static const Map<String, double> _pushupSensitivities = {
    "pushup_correcto": 1.0,
    "pushup_cadera_caida": 1.0,
    "pushup_codos_abiertos": 0.9,
    "pushup_pelvis_levantada": 1.0,
  };

  static const Map<String, double> _plankSensitivities = {
    "plank_correcto": 1.0,
    "plank_cadera_caida": 3.0,
    "plank_codos_abiertos": 1.2,
    "plank_pelvis_levantada": 1.6,
  };

  void _handlePrediction(Map<String, double> probabilities) {
    if (!mounted) return;

    // 1. 🔥 SELECCIONAR EL MAPA DE SENSIBILIDAD CORRECTO
    Map<String, double> sensitivityMap = {};
    if (_exerciseType == 'squat') {
      sensitivityMap = _squatSensitivities;
    } else if (_exerciseType == 'pushup') {
      sensitivityMap = _pushupSensitivities;
    } else if (_exerciseType == 'plank') {
      sensitivityMap = _plankSensitivities;
    }

    // 2. Aplicar multiplicadores
    Map<String, double> adjustedProbabilities = Map.from(probabilities);
    
    adjustedProbabilities.updateAll((key, value) {
      final multiplier = sensitivityMap[key] ?? 1.0;
      return value * multiplier;
    });

    // 3. Ordenar basado en probabilidades AJUSTADAS
    final sortedEntries = adjustedProbabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedEntries.isEmpty) return;

    final best = sortedEntries.first;

    // 4. Recuperar la probabilidad ORIGINAL para UI, pero aplicando CLAMP a 1.0
    //    (Nota: Podrías querer usar la 'adjusted' limitada a 1.0 si quieres 
    //    que la sensibilidad afecte visualmente la barra de confianza)
    double displayConfidence = adjustedProbabilities[best.key] ?? 0.0;
    
    // 🔥 ASEGURAR que NUNCA supere 100% (máximo 1.0)
    displayConfidence = displayConfidence.clamp(0.0, 1.0);

    setState(() {
      _currentPrediction = best.key;
      _currentConfidence = displayConfidence; 
      _allProbabilities = Map.fromEntries(sortedEntries); 
      
      String status = best.key
          .replaceAll('${_exerciseType}_', '')
          .replaceAll('_', ' ');
      
      if (_exerciseType == 'plank') {
        _currentStatus = status;
      } else {
        _currentStatus = 'Rep $_repCounter: $status';
      }
    });
    
    // 🔊 Reproducir audio según clasificación
    _playFeedbackAudio(best.key);

    _captureTrainingData(best.key, displayConfidence, probabilities);
  }
  
  // 🔊 Método para reproducir audio según clasificación
  void _playFeedbackAudio(String classification) {
    // Extraer el tipo de error/correcto
    final status = classification.replaceAll('${_exerciseType}_', '');
    
    if (status == 'correcto') {
      // ✅ Limpiar landmarks de error
      setState(() => _errorLandmarks = {});
      
      // 🔥 Parpadeo verde en los bordes
      _flashBorder(Colors.green);
      
      // Incrementar contador de correctos seguidos
      _consecutiveCorrectCount++;
      
      // Solo reproducir audio si hay 3 correctos seguidos
      if (_consecutiveCorrectCount >= 3) {
        _audioManager.playCorrecto();
        _consecutiveCorrectCount = 0; // Resetear contador después de reproducir
      }
    } else {
      // ❌ Si hay error, resetear contador y reproducir audio de error
      _consecutiveCorrectCount = 0;
      
      // 🔥 Parpadeo rojo en los bordes
      _flashBorder(Colors.red);
      
      // 🔥 Definir qué landmarks resaltar según el error
      setState(() => _errorLandmarks = _getLandmarksForError(status));
      
      if (_exerciseType == 'pushup' || _exerciseType == 'plank') {
        _audioManager.playPushupPlankError(status);
      } else if (_exerciseType == 'squat') {
        _audioManager.playSquatError(status);
      }
    }
  }
  
  // 🔥 Mapear errores a landmarks problemáticos
  Set<int> _getLandmarksForError(String errorType) {
    if (_exerciseType == 'pushup' || _exerciseType == 'plank') {
      switch (errorType) {
        case 'cadera_caida':
          return {MediaPipePoseLandmark.leftHip, MediaPipePoseLandmark.rightHip};
        case 'codos_abiertos':
          return {MediaPipePoseLandmark.leftElbow, MediaPipePoseLandmark.rightElbow, 
                  MediaPipePoseLandmark.leftShoulder, MediaPipePoseLandmark.rightShoulder};
        case 'pelvis_levantada':
          return {MediaPipePoseLandmark.leftHip, MediaPipePoseLandmark.rightHip};
        default:
          return {};
      }
    } else if (_exerciseType == 'squat') {
      switch (errorType) {
        case 'espalda_arqueada':
          return {MediaPipePoseLandmark.leftShoulder, MediaPipePoseLandmark.rightShoulder,
                  MediaPipePoseLandmark.leftHip, MediaPipePoseLandmark.rightHip};
        case 'poca_profundidad':
          return {MediaPipePoseLandmark.leftKnee, MediaPipePoseLandmark.rightKnee,
                  MediaPipePoseLandmark.leftHip, MediaPipePoseLandmark.rightHip};
        case 'valgo_rodilla':
          return {MediaPipePoseLandmark.leftKnee, MediaPipePoseLandmark.rightKnee};
        default:
          return {};
      }
    }
    return {};
  }
  
  // 🔥 Activar parpadeo de bordes con animación difuminada
  void _flashBorder(Color color) async {
    if (!mounted) return;
    
    setState(() {
      _borderFlashColor = color;
      _showBorderFlash = true;
    });
    
    // Aparecer suavemente (fade in) - 200ms
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
      if (!mounted) return;
      setState(() => _borderOpacity = i / 10.0);
    }
    
    // Mantener visible por 150ms
    await Future.delayed(const Duration(milliseconds: 150));
    
    // Desaparecer suavemente (fade out) - 300ms
    for (int i = 10; i >= 0; i--) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      setState(() => _borderOpacity = i / 10.0);
    }
    
    if (!mounted) return;
    setState(() => _showBorderFlash = false);
  }

  void _captureTrainingData(
    String classification,
    double confidence,
    Map<String, double> probabilities,
  ) {
    if (_exerciseType == 'pushup' || _exerciseType == 'squat') {
      if (_repCounter > _capturedReps.length) {
        _capturedReps.add(RepData(
          repNumber: _repCounter,
          classification: classification,
          confidence: confidence,
          probabilities: probabilities,
          timestamp: DateTime.now(),
        ));
      }
    } else if (_exerciseType == 'plank') {
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
    setState(() => _isFinishingSession = true);
    
    try {
      // 🔊 Reproducir audio PRIMERO y esperar a que termine
      await _audioManager.playTerminarEjercicio();
      
      // Esperar 500ms adicionales para asegurar que el audio se escuche completamente
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _cameraController?.stopImageStream();
      _wsClient.disconnect();

      if (_trainingStartTime == null) return;

      final endTime = DateTime.now();
      final duration = endTime.difference(_trainingStartTime!);

      final metrics = _sessionService.calculateMetrics(
        exerciseType: _exerciseType,
        repsData: _exerciseType != 'plank' ? _capturedReps : null,
        secondsData: _exerciseType == 'plank' ? _capturedSeconds : null,
        durationSeconds: duration.inSeconds,
      );

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

      await _sessionService.saveTrainingSession(sessionData);

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
      print('❌ Error al finalizar: $e');
      if (mounted) setState(() => _isFinishingSession = false);
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector.dispose();
    _wsClient.disconnect();
    _audioManager.dispose();
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
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('ESTADO:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_currentStatus.toUpperCase(), style: TextStyle(color: _getStatusColor(_currentStatus), fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('CONFIANZA:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Text(_currentConfidence > 0.0 ? '${(_currentConfidence * 100).toStringAsFixed(0)}%' : '--', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          if (_exerciseType != 'pushup' && _exerciseType != 'squat') ...[  
            LinearProgressIndicator(
              value: _exerciseType == 'plank' ? _plankFeatureBuffer.length / (_plankBufferSizeSeconds * _plankFpsEstimado) : 0.0,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 8),
            Text('Buffer: ${_plankFeatureBuffer.length}/${_plankBufferSizeSeconds * _plankFpsEstimado}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
          if (_exerciseType == 'pushup' || _exerciseType == 'squat') ...[  
            Text('Repeticiones: $_repCounter', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
  
  // 🔥 Barra superior con diseño similar a la imagen
  Widget _buildTopBar() {
    // Formatear tiempo transcurrido
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    final timeText = '$minutes:$seconds';
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          // Botón de retroceder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 16),
          // Información del ejercicio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nombre del ejercicio
                Text(
                  widget.exercise.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Estado
                Text(
                  _currentStatus,
                  style: TextStyle(
                    color: _getStatusColor(_currentStatus),
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Tiempo
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tiempo',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Repeticiones
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reps.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$_repCounter',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Botón de cambiar cámara
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              onPressed: _switchCamera,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('correcto')) return Colors.greenAccent;
    if (status.contains('No se detecta')) return Colors.orangeAccent;
    if (status.contains('Error') || status.contains('Iniciando')) return Colors.grey;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          if (_poses.isNotEmpty)
            CustomPaint(painter: PosePainterMediaPipe(
              poses: _poses, 
              absoluteImageSize: _absoluteImageSize, 
              cameraLensDirection: _cameraController!.description.lensDirection,
              highlightedLandmarks: _errorLandmarks,
              deviceOrientation: MediaQuery.of(context).orientation,
            )),
          // 🔥 Barra superior con información
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildTopBar()),
          ),
          // 🔥 Botón de terminar en la parte inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: _isFinishingSession
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Finalizando...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _finishTraining,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.stop_circle, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Terminar Entrenamiento',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          // 🔥 Bordes difuminados con parpadeo de feedback (solo en los bordes)
          if (_showBorderFlash)
            IgnorePointer(
              child: Stack(
                children: [
                  // Borde superior
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _borderFlashColor.withOpacity(_borderOpacity * 0.7),
                            _borderFlashColor.withOpacity(_borderOpacity * 0.3),
                            _borderFlashColor.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Borde inferior
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            _borderFlashColor.withOpacity(_borderOpacity * 0.7),
                            _borderFlashColor.withOpacity(_borderOpacity * 0.3),
                            _borderFlashColor.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Borde izquierdo
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            _borderFlashColor.withOpacity(_borderOpacity * 0.7),
                            _borderFlashColor.withOpacity(_borderOpacity * 0.3),
                            _borderFlashColor.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Borde derecho
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            _borderFlashColor.withOpacity(_borderOpacity * 0.7),
                            _borderFlashColor.withOpacity(_borderOpacity * 0.3),
                            _borderFlashColor.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}