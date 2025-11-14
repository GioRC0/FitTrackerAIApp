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
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg; // Variable para guardar la rotación
  Size _absoluteImageSize = Size.zero; // Variable para guardar el tamaño de la imagen
  
  // Variables para clasificación de plank
  String _currentPrediction = ""; // Usado en lógica de clasificación
  double _currentConfidence = 0.0; // Usado en _buildFeedbackPanel
  Map<String, double> _allProbabilities = {}; // Usado en _buildFeedbackPanel
  String _currentStatus = "Iniciando...";
  
  // Buffer de keypoints para clasificación (30 frames)
  final List<Map<String, List<double>>> _keypointsBuffer = [];
  static const int _bufferSize = 30;
  
  // Control de tiempo para evitar sobrecarga
  DateTime _lastProcessedTime = DateTime.now();
  static const _processingInterval = Duration(milliseconds: 150); // Procesar cada 150ms (~7 FPS, más estable)
  
  // Suavizado de poses (Exponential Moving Average)
  Map<PoseLandmarkType, PoseLandmark>? _smoothedLandmarks;
  static const double _smoothingAlpha = 0.5; // 50% actual + 50% anterior: balance entre reactividad y estabilidad

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
      // 🐛 DEBUG: Descomentar para probar con frame manual
      // await _plankClassifier.testWithManualFrame();
      
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
      
      // Asegurarse de que el índice de la cámara es válido
      _cameraIndex = _cameraIndex < cameras.length ? _cameraIndex : 0;

      _cameraController = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.medium, // Cambiar a medium para mejor rendimiento
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
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

  // --- FUNCIÓN AUXILIAR PARA CONVERTIR LA IMAGEN ---
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    // Guardamos el tamaño y la rotación para pasarlos al Painter
    _absoluteImageSize = Size(image.width.toDouble(), image.height.toDouble());


    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
    } else if (Platform.isAndroid) {
      // Para Android, usar la rotación directa del sensor
      // Si los landmarks están girados 90° a la izquierda, necesitamos rotar 90° más
      if (camera.lensDirection == CameraLensDirection.front) {
        // Cámara frontal
        rotation = InputImageRotation.rotation0deg;
      } else {
        // Cámara trasera
        rotation = InputImageRotation.rotation180deg;
      }
    } else {
      rotation = InputImageRotation.rotation0deg;
    }
    _imageRotation = rotation;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Concatenar todos los bytes de los planos en una sola lista
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

  /// Suaviza las poses usando Exponential Moving Average (EMA)
  Map<PoseLandmarkType, PoseLandmark> _smoothPose(Map<PoseLandmarkType, PoseLandmark> currentLandmarks) {
    if (_smoothedLandmarks == null) {
      // Primera vez: inicializar con los valores actuales
      _smoothedLandmarks = Map.from(currentLandmarks);
      return _smoothedLandmarks!;
    }

    // Aplicar EMA: smoothed = alpha * current + (1 - alpha) * previous
    final smoothed = <PoseLandmarkType, PoseLandmark>{};
    for (final entry in currentLandmarks.entries) {
      final type = entry.key;
      final current = entry.value;
      final previous = _smoothedLandmarks![type];

      if (previous != null) {
        smoothed[type] = PoseLandmark(
          type: type,
          x: _smoothingAlpha * current.x + (1 - _smoothingAlpha) * previous.x,
          y: _smoothingAlpha * current.y + (1 - _smoothingAlpha) * previous.y,
          z: _smoothingAlpha * current.z + (1 - _smoothingAlpha) * previous.z,
          likelihood: current.likelihood,
        );
      } else {
        smoothed[type] = current;
      }
    }

    _smoothedLandmarks = smoothed;
    return smoothed;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    
    // Throttling: solo procesar cada 100ms para evitar sobrecarga
    final now = DateTime.now();
    if (now.difference(_lastProcessedTime) < _processingInterval) {
      return;
    }
    _lastProcessedTime = now;
    
    _isProcessing = true;

    // Usa la nueva función auxiliar para crear el InputImage
    final inputImage = _inputImageFromCameraImage(image);

    if (inputImage == null) {
      _isProcessing = false;
      return;
    }

    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (mounted && poses.isNotEmpty) {
        final pose = poses.first;
        
        // Suavizar landmarks para reducir tambaleo visual y de clasificación
        final smoothedLandmarks = _smoothPose(pose.landmarks);
        
        // Crear un Pose suavizado para el painter
        final smoothedPose = Pose(landmarks: smoothedLandmarks);
        
        setState(() {
          _poses = [smoothedPose]; // Mostrar pose suavizada
        });

        // Procesar con el clasificador
        try {
          // Convertir landmarks a formato Map<String, List<double>>
          final keypoints = _landmarksToKeypoints(smoothedLandmarks);
          
          if (keypoints != null) {
            _keypointsBuffer.add(keypoints);
            
            // Si tenemos suficientes frames, clasificar
            if (_keypointsBuffer.length >= _bufferSize) {
              final probabilities = await _plankClassifier.classify(_keypointsBuffer);
              
              // Encontrar la clase con mayor probabilidad
              int maxIdx = 0;
              double maxProb = probabilities[0];
              for (int i = 1; i < probabilities.length; i++) {
                if (probabilities[i] > maxProb) {
                  maxProb = probabilities[i];
                  maxIdx = i;
                }
              }
              
              final predictedClass = classLabels[maxIdx];
              
              setState(() {
                _currentPrediction = predictedClass;
                _currentConfidence = maxProb;
                _allProbabilities = {
                  for (int i = 0; i < classLabels.length; i++) classLabels[i]: probabilities[i]
                };
                _currentStatus = predictedClass.replaceAll('plank_', '').replaceAll('_', ' ');
              });
              
              // Limpiar buffer después de clasificar
              _keypointsBuffer.clear();
            }
          }
        } catch (e) {
          // Error silencioso, continuar procesando
        }
      } else if (poses.isEmpty) {
        // No se detecta persona
        _keypointsBuffer.clear();
        _smoothedLandmarks = null; // Resetear suavizado
        if (_currentStatus != "No se detecta cuerpo") {
          setState(() {
            _currentStatus = "No se detecta cuerpo";
            _currentPrediction = "";
            _currentConfidence = 0.0;
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

  /// Convierte landmarks de Google ML Kit al formato Map<String, List<double>>
  /// Filtra por confianza mínima para reducir ruido
  Map<String, List<double>>? _landmarksToKeypoints(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    try {
      final shoulderL = landmarks[PoseLandmarkType.leftShoulder];
      final hipL = landmarks[PoseLandmarkType.leftHip];
      final ankleL = landmarks[PoseLandmarkType.leftAnkle];
      final elbowL = landmarks[PoseLandmarkType.leftElbow];
      final wristL = landmarks[PoseLandmarkType.leftWrist];

      if (shoulderL == null || hipL == null || ankleL == null || 
          elbowL == null || wristL == null) {
        return null;
      }

      // ✅ Filtrar por confianza mínima (MediaPipe likelihood)
      const minConfidence = 0.5;
      if (shoulderL.likelihood < minConfidence || 
          hipL.likelihood < minConfidence ||
          ankleL.likelihood < minConfidence ||
          elbowL.likelihood < minConfidence ||
          wristL.likelihood < minConfidence) {
        return null;
      }

      // ✅ Validar que las coordenadas estén en el rango esperado [0, 1]
      bool isValidCoord(double val) => val >= 0.0 && val <= 1.0;
      if (!isValidCoord(shoulderL.x) || !isValidCoord(shoulderL.y) ||
          !isValidCoord(hipL.x) || !isValidCoord(hipL.y) ||
          !isValidCoord(ankleL.x) || !isValidCoord(ankleL.y) ||
          !isValidCoord(elbowL.x) || !isValidCoord(elbowL.y) ||
          !isValidCoord(wristL.x) || !isValidCoord(wristL.y)) {
        return null;
      }

      return {
        'shoulder_l': [shoulderL.x, shoulderL.y],
        'hip_l': [hipL.x, hipL.y],
        'ankle_l': [ankleL.x, ankleL.y],
        'elbow_l': [elbowL.x, elbowL.y],
        'wrist_l': [wristL.x, wristL.y],
      };
    } catch (e) {
      return null;
    }
  }

  /// Construye el panel de feedback en tiempo real (replica la UI de Python)
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
          // Estado actual
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
          
          // Confianza
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
          
          // Barra de progreso del buffer
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
          
          // Probabilidades de todas las clases
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
              final displayName = entry.key.replaceAll('plank_', '').replaceAll('_', ' ');
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
      return Colors.redAccent; // Postura incorrecta
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          // Calcular el aspect ratio de la cámara
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
                    // --- Overlay con landmarks ---
                    if (_poses.isNotEmpty)
                      CustomPaint(
                        painter: PosePainter(
                          poses: _poses,
                          absoluteImageSize: _absoluteImageSize,
                          rotation: _imageRotation,
                          cameraLensDirection: _cameraController!.description.lensDirection,
                          cameraDescription: _cameraController!.description,
                        ),
                      ),
                    // --- Panel de Feedback en Tiempo Real ---
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