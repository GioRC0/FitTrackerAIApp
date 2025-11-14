import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fitracker_app/services/mediapipe_pose_detector.dart';
import 'pose_painter_mediapipe.dart';

// ============================================================================
// WebSocketClient: Maneja comunicación con API de predicción
// ============================================================================
class WebSocketClient {
  final String wsUrl = 'wss://plank-repo.fly.dev/ws/predict';
  WebSocketChannel? _channel;
  Function(Map<String, double>)? onPrediction;
  bool _isConnected = false;

  /// Sensibilidad por clase (EQUIVALENTE A SENSIBILIDAD_CLASE en Python)
  static const Map<String, double> _sensitivityByClass = {
    'plank_cadera_caida': 0.45,
    'plank_codos_abiertos': 0.45,
    'plank_correcto': 1.75,
    'plank_pelvis_levantada': 1.0,
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
            rawProbs.forEach((label, prob) {
              final factor = _sensitivityByClass[label] ?? 1.0;
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
  const CameraTrainingScreen({super.key});

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
  int _cameraIndex = 0; // 0=trasera (por defecto para emulador), 1=frontal
  Size _absoluteImageSize = Size.zero;

  // Estado de predicción
  // ignore: unused_field
  String _currentPrediction = "";
  double _currentConfidence = 0.0;
  Map<String, double> _allProbabilities = {};
  String _currentStatus = "Iniciando...";

  // Buffer de keypoints para calcular features
  final List<Map<String, List<double>>> _keypointsBuffer = [];
  static const int _bufferSize = 15; // 15 frames ≈ 0.5 segundos a 30 FPS

  // Control de tiempo
  DateTime _lastProcessedTime = DateTime.now();
  static const _processingInterval = Duration(milliseconds: 33); // 30 FPS

  // Cache para suavizado EMA de landmarks
  final Map<int, List<double>> _smoothCache = {};
  static const double _emaAlpha = 0.6; // 60% nuevo, 40% anterior

  @override
  void initState() {
    super.initState();
    _poseDetector = MediaPipePoseDetector();
    _wsClient = WebSocketClient();
    _wsClient.onPrediction = _handlePrediction;
    _initializeMediaPipe();
    _initializeWebSocket();
    _initializeCamera();
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
          final keypoints = _landmarksToKeypoints(smoothedLandmarks);

          if (keypoints != null) {
            _keypointsBuffer.add(keypoints);

            // Cuando el buffer alcanza el tamaño completo (15 frames)
            if (_keypointsBuffer.length >= _bufferSize) {
              // Calcular features
              final features = _calculateFeatures(_keypointsBuffer);
              
              // DEBUG: Mostrar primeros 5 valores para verificar que cambian
              print('🔢 Features calculados (primeros 5): ${features.take(5).toList()}');
              
              // ENVIAR a la API
              _wsClient.sendFeatures(features);
              print('📤 Features enviados. Buffer: ${_keypointsBuffer.length}/$_bufferSize frames');
              
              // LIMPIAR el buffer completamente (RESET)
              _keypointsBuffer.clear();
              print('♻️ Buffer limpiado. Listo para acumular nuevamente.');
            }
          }
        } catch (e) {
          print('❌ Error al procesar keypoints: $e');
        }
      } else if (result == null || result.poses.isEmpty) {
        _keypointsBuffer.clear();
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

  /// Extrae 5 landmarks clave y normaliza a [0,1]
  Map<String, List<double>>? _landmarksToKeypoints(
      Map<int, MediaPipeLandmark> landmarks) {
    try {
      final shoulderL = landmarks[MediaPipePoseLandmark.leftShoulder];
      final hipL = landmarks[MediaPipePoseLandmark.leftHip];
      final ankleL = landmarks[MediaPipePoseLandmark.leftAnkle];
      final elbowL = landmarks[MediaPipePoseLandmark.leftElbow];
      final wristL = landmarks[MediaPipePoseLandmark.leftWrist];

      if (shoulderL == null || hipL == null || ankleL == null || 
          elbowL == null || wristL == null) {
        return null;
      }

      const minConfidence = 0.70; // Aumentado para mayor precisión
      if (shoulderL.likelihood < minConfidence ||
          hipL.likelihood < minConfidence ||
          ankleL.likelihood < minConfidence ||
          elbowL.likelihood < minConfidence ||
          wristL.likelihood < minConfidence) {
        // Keypoint con baja confianza - no se agrega al buffer ni se envía a la API
        print('⚠️ Frame rechazado: keypoint con confianza < 0.70');
        return null;
      }

      if (_absoluteImageSize.width <= 0 || _absoluteImageSize.height <= 0) {
        return null;
      }

      double nx(double x) => x / _absoluteImageSize.width;
      double ny(double y) => y / _absoluteImageSize.height;

      return {
        'shoulder_l': [nx(shoulderL.x), ny(shoulderL.y)],
        'hip_l': [nx(hipL.x), ny(hipL.y)],
        'ankle_l': [nx(ankleL.x), ny(ankleL.y)],
        'elbow_l': [nx(elbowL.x), ny(elbowL.y)],
        'wrist_l': [nx(wristL.x), ny(wristL.y)],
      };
    } catch (e) {
      return null;
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

  /// Calcula 25 features a partir del buffer de keypoints
  /// Igual que Python: 5 features derivadas × 5 estadísticas
  List<double> _calculateFeatures(List<Map<String, List<double>>> buffer) {
    // 1. Calcular las 5 FEATURES DERIVADAS para cada frame (igual que Python)
    final List<List<double>> derivedFeaturesPerFrame = [];
    
    for (final frame in buffer) {
      final shoulder = frame['shoulder_l']!;
      final hip = frame['hip_l']!;
      final ankle = frame['ankle_l']!;
      final elbow = frame['elbow_l']!;
      final wrist = frame['wrist_l']!;

      // Calcular las 5 features (IGUAL QUE PYTHON):
      final bodyAngle = _calculateAngle(shoulder, hip, ankle);
      final hipShoulderVerticalDiff = hip[1] - shoulder[1];
      final hipAnkleVerticalDiff = hip[1] - ankle[1];
      final shoulderElbowAngle = _calculateAngle(hip, shoulder, elbow);
      final wristShoulderHipAngle = _calculateAngle(wrist, shoulder, hip);

      derivedFeaturesPerFrame.add([
        bodyAngle,
        hipShoulderVerticalDiff,
        hipAnkleVerticalDiff,
        shoulderElbowAngle,
        wristShoulderHipAngle,
      ]);
    }

    // 2. Calcular estadísticas de cada feature (igual que Python)
    final List<double> features = [];
    
    // Para cada una de las 5 features
    for (int featureIdx = 0; featureIdx < 5; featureIdx++) {
      // Extraer todos los valores de esa feature en todos los frames
      final values = derivedFeaturesPerFrame
          .map((frame) => frame[featureIdx])
          .toList();

      // Calcular estadísticas
      final mean = values.fold(0.0, (a, b) => a + b) / values.length;
      final variance = values.fold(0.0, (a, b) => a + pow(b - mean, 2)) /
          values.length;
      final std = sqrt(variance);
      final min = values.fold(values[0], (a, b) => a < b ? a : b);
      final max = values.fold(values[0], (a, b) => a > b ? a : b);
      final range = max - min;

      // Agregar en el mismo orden que Python: mean, std, min, max, range
      features.addAll([mean, std, min, max, range]);
    }

    return features; // 5 features × 5 stats = 25 valores
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
      _currentStatus =
          best.key.replaceAll('plank_', '').replaceAll('_', ' ');
    });
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
    _keypointsBuffer.clear();
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
          LinearProgressIndicator(
            value: _keypointsBuffer.length / _bufferSize,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Buffer: ${_keypointsBuffer.length}/$_bufferSize',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
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
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cameraAspectRatio = _cameraController!.value.aspectRatio;

          return Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: cameraAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_cameraController!),
                    if (_poses.isNotEmpty)
                      CustomPaint(
                        painter: PosePainterMediaPipe(
                          poses: _poses,
                          absoluteImageSize: _absoluteImageSize,
                          cameraLensDirection:
                              _cameraController!.description.lensDirection,
                        ),
                      ),
                    Positioned(
                      top: 20,
                      left: 20,
                      right: 20,
                      child: _buildFeedbackPanel(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
