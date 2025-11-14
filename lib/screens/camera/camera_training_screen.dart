import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pose_painter.dart';
import 'package:fitracker_app/services/plank_classifier_service.dart';

class CameraTrainingScreen extends StatefulWidget {
  const CameraTrainingScreen({super.key});

  @override
  State<CameraTrainingScreen> createState() => _CameraTrainingScreenState();
}

class _CameraTrainingScreenState extends State<CameraTrainingScreen> {
  late final PoseDetector _poseDetector;
  late final PlankClassifier _plankClassifier;
  CameraController? _cameraController;
  List<Pose> _poses = [];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  int _cameraIndex = 1; // 0 para trasera, 1 para frontal
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg;
  Size _absoluteImageSize = Size.zero;

  // Clasificación de plank
  String _currentPrediction = "";
  double _currentConfidence = 0.0;
  Map<String, double> _allProbabilities = {};
  String _currentStatus = "Iniciando...";

  // Buffer temporal de keypoints
  final List<Map<String, List<double>>> _keypointsBuffer = [];

  /// Queremos ~1 segundo de ventana.
  /// Con _processingInterval = 150 ms ≈ 6.6 fps → 7–8 frames ≈ 1 s.
  static const int _bufferSize = 8;

  // Control de tiempo para evitar sobrecarga
  DateTime _lastProcessedTime = DateTime.now();
  static const _processingInterval = Duration(milliseconds: 150);

  /// Sensibilidad por clase (equivalente a SENSIBILIDAD_CLASE en Python)
  static const Map<String, double> _sensitivityByClass = {
    'plank_cadera_caida': 1.0,
    'plank_codos_abiertos': 0.5,
    'plank_correcto': 1.3,
    'plank_pelvis_levantada': 1.0,
  };

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
    _plankClassifier = PlankClassifier();
    _initializeCamera();
    _initializeClassifier();
  }

  Future<void> _initializeClassifier() async {
    try {
      await _plankClassifier.load();
      setState(() {
        _currentStatus = "Listo para entrenar";
      });
    } catch (e) {
      print('❌ Error al inicializar clasificador: $e');
      setState(() {
        _currentStatus = "Error al cargar modelo";
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (await Permission.camera.request().isGranted) {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print("No se encontraron cámaras.");
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
        });
      }
    } else {
      print("Permiso de cámara denegado.");
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    _absoluteImageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
    } else if (Platform.isAndroid) {
      if (camera.lensDirection == CameraLensDirection.front) {
        rotation = InputImageRotation.rotation0deg;
      } else {
        rotation = InputImageRotation.rotation180deg;
      }
    } else {
      rotation = InputImageRotation.rotation0deg;
    }
    _imageRotation = rotation;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: _absoluteImageSize,
        rotation: _imageRotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Map<PoseLandmarkType, PoseLandmark> _smoothPose(
      Map<PoseLandmarkType, PoseLandmark> currentLandmarks) {
    // Sin suavizado, devolver landmarks originales
    return currentLandmarks;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;

    final now = DateTime.now();
    if (now.difference(_lastProcessedTime) < _processingInterval) {
      return;
    }
    _lastProcessedTime = now;

    _isProcessing = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isProcessing = false;
      return;
    }

    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (mounted && poses.isNotEmpty) {
        final pose = poses.first;

        final smoothedLandmarks = _smoothPose(pose.landmarks);
        final smoothedPose = Pose(landmarks: smoothedLandmarks);

        setState(() {
          _poses = [smoothedPose];
        });

        try {
          final keypoints = _landmarksToKeypoints(smoothedLandmarks);

          if (keypoints != null) {
            _keypointsBuffer.add(keypoints);

            if (_keypointsBuffer.length >= _bufferSize) {
              final probabilities =
                  await _plankClassifier.classify(_keypointsBuffer);

              // --- Ajuste de sensibilidad por clase (como en Python) ---
              // Construimos mapa {clase: prob}
              final Map<String, double> rawProbs = {
                for (int i = 0; i < classLabels.length; i++)
                  classLabels[i]: probabilities[i]
              };

              // Aplicar factor de sensibilidad y normalizar
              final Map<String, double> adjustedProbs = {};
              double total = 0.0;
              rawProbs.forEach((label, prob) {
                final factor = _sensitivityByClass[label] ?? 1.0;
                final adjusted = prob * factor;
                adjustedProbs[label] = adjusted;
                total += adjusted;
              });

              final Map<String, double> finalProbs =
                  total > 0.0
                      ? adjustedProbs.map(
                          (k, v) => MapEntry(k, v / total),
                        )
                      : adjustedProbs;

              // Ordenar por probabilidad descendente
              final sortedEntries = finalProbs.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final best = sortedEntries.first;
              final predictedClass = best.key;
              final bestProb = best.value;

              // Mantener el mapa en orden para mostrar top 4
              final orderedMap = <String, double>{};
              for (final e in sortedEntries) {
                orderedMap[e.key] = e.value;
              }

              setState(() {
                _currentPrediction = predictedClass;
                _currentConfidence = bestProb;
                _allProbabilities = orderedMap;
                _currentStatus = predictedClass
                    .replaceAll('plank_', '')
                    .replaceAll('_', ' ');
              });

              _keypointsBuffer.clear();
            }
          }
        } catch (e) {
          // Error silencioso, continuar
        }
      } else if (poses.isEmpty) {
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
      print("Error al procesar la imagen: $e");
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector.close();
    _plankClassifier.dispose();
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

  /// Convierte landmarks al formato Map<String, List<double>>,
  /// NORMALIZANDO x,y a [0,1] como en MediaPipe Python.
  Map<String, List<double>>? _landmarksToKeypoints(
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
    try {
      final shoulderL = landmarks[PoseLandmarkType.leftShoulder];
      final hipL = landmarks[PoseLandmarkType.leftHip];
      final ankleL = landmarks[PoseLandmarkType.leftAnkle];
      final elbowL = landmarks[PoseLandmarkType.leftElbow];
      final wristL = landmarks[PoseLandmarkType.leftWrist];

      if (shoulderL == null ||
          hipL == null ||
          ankleL == null ||
          elbowL == null ||
          wristL == null) {
        return null;
      }

      const minConfidence = 0.5;
      if (shoulderL.likelihood < minConfidence ||
          hipL.likelihood < minConfidence ||
          ankleL.likelihood < minConfidence ||
          elbowL.likelihood < minConfidence ||
          wristL.likelihood < minConfidence) {
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
            'Analizando: ${((_keypointsBuffer.length / _bufferSize) * 100).toStringAsFixed(0)}%',
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
              final displayName = entry.key
                  .replaceAll('plank_', '')
                  .replaceAll('_', ' ');
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
                        painter: PosePainter(
                          poses: _poses,
                          absoluteImageSize: _absoluteImageSize,
                          rotation: _imageRotation,
                          cameraLensDirection:
                              _cameraController!.description.lensDirection,
                          cameraDescription: _cameraController!.description,
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
