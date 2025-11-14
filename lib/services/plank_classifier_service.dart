import 'dart:typed_data';
import 'dart:ui';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:fitracker_app/utils/pose_utils.dart';

/// Resultado de la clasificación de plank
class PlankPrediction {
  final String className;
  final double confidence;
  final Map<String, double> allProbabilities;

  PlankPrediction({
    required this.className,
    required this.confidence,
    required this.allProbabilities,
  });
}

/// Servicio de clasificación de Plank usando TensorFlow Lite
/// Replica exactamente la lógica de real_time_feedback.py
class PlankClassifierService {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  // Configuración del buffer (1 segundo a ~30 FPS)
  static const int bufferSizeSeconds = 1;
  static const int estimatedFps = 30;
  static const int bufferFrameSize = bufferSizeSeconds * estimatedFps;

  // Buffer de features
  final List<List<double>> _featureBuffer = [];

  // Clases del modelo (en el mismo orden que el LabelEncoder de Python)
  // IMPORTANTE: Verificar que este orden coincida con tu modelo
  final List<String> _classes = [
    'plank_cadera_caida',
    'plank_codos_abiertos',
    'plank_correcto',
    'plank_pelvis_levantada',
  ];

  // Sensibilidades de clase (igual que en Python)
  final Map<String, double> _classSensitivity = {
    'plank_cadera_caida': 1.0,
    'plank_codos_abiertos': 0.5,
    'plank_correcto': 1.3,
    'plank_pelvis_levantada': 1.0,
  };

  // Parámetros del StandardScaler (extraídos de Python)
  static final List<double> _scalerMean = [127.636779983182, 1.5117658938626677, 124.47588168039412, 130.53651831018988, 6.0606366297957335, -0.06867082856624057, 0.00234318878192212, -0.07300013475034427, -0.0641702554006686, 0.008829879349675619, -0.04266501786151607, 0.0028978763782072404, -0.04874555132854943, -0.0370704456307422, 0.011675105697807194, 112.95053030896749, 1.2427157759370409, 110.63313465650462, 115.26743584696189, 4.63430119045721, 129.26302765840217, 1.0005582046494061, 127.33112290617265, 131.266017859763, 3.9348949535903515];
  static final List<double> _scalerScale = [45.704018963064584, 1.6664058741022247, 45.94423502519724, 45.888311469839266, 6.846611978116351, 0.08277159510312168, 0.0013734786148112796, 0.08321988205290305, 0.08223419533844367, 0.005723874410967971, 0.08312911013351998, 0.002346161170224612, 0.08481765189186219, 0.08334566680611374, 0.010963446129698275, 32.892291207960334, 1.0994823801867708, 33.61213847030448, 32.43374354960898, 4.216638382644308, 31.208528122807305, 0.8260764159537176, 31.346673904889965, 30.981041971579593, 3.532619818684677];

  /// Inicializa el modelo TFLite
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Cargar el modelo TFLite
      _interpreter = await Interpreter.fromAsset('assets/models/plank_classifier_model.tflite');
      
      _isInitialized = true;
      print('PlankClassifier inicializado correctamente');
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      print('Error al inicializar PlankClassifier: $e');
      rethrow;
    }
  }

  /// Procesa un frame de pose y retorna la predicción cuando el buffer está lleno
  PlankPrediction? processFrame(Map<PoseLandmarkType, PoseLandmark> landmarks, {required Size imageSize}) {
    if (!_isInitialized) {
      throw StateError('PlankClassifier no está inicializado. Llama a initialize() primero.');
    }

    // Extraer features del frame actual (con coordenadas normalizadas)
    final features = PoseUtils.extractPlankFeatures(landmarks, imageSize: imageSize);
    if (features == null) {
      // No se pudieron extraer features (persona no visible completamente)
      _featureBuffer.clear();
      return null;
    }

    // Agregar al buffer
    _featureBuffer.add(features);

    // Si el buffer está lleno, hacer predicción
    if (_featureBuffer.length >= bufferFrameSize) {
      final prediction = _makePrediction();
      _featureBuffer.clear(); // Limpiar buffer después de la predicción
      return prediction;
    }

    return null;
  }

  /// Realiza la predicción usando el modelo TFLite
  PlankPrediction _makePrediction() {
    print('🔍 DEBUG - Buffer size: ${_featureBuffer.length} frames');
    print('🔍 DEBUG - Primeros 3 frames del buffer:');
    for (int i = 0; i < 3 && i < _featureBuffer.length; i++) {
      print('   Frame $i: ${_featureBuffer[i].map((f) => f.toStringAsFixed(2)).join(", ")}');
    }
    
    // Calcular features agregadas (igual que en Python)
    final aggregatedFeatures = PoseUtils.calculateAggregatedFeatures(_featureBuffer);
    
    print('🔍 DEBUG - Features agregadas (${aggregatedFeatures.length}): ${aggregatedFeatures.map((f) => f.toStringAsFixed(2)).join(", ")}');

    // IMPORTANTE: Normalizar features usando StandardScaler
    // El modelo TFLite fue entrenado con StandardScaler en Python
    final normalizedFeatures = _normalizeFeatures(aggregatedFeatures);
    
    print('🔍 DEBUG - Features normalizadas (${normalizedFeatures.length}): ${normalizedFeatures.map((f) => f.toStringAsFixed(2)).join(", ")}');

    // Preparar input para el modelo
    // Shape: [1, 25] (5 features * 5 estadísticas)
    final input = Float32List.fromList(normalizedFeatures);
    final inputReshaped = input.reshape([1, normalizedFeatures.length]);

    // Preparar output
    // Shape: [1, 4] (4 clases)
    final output = List.filled(1 * _classes.length, 0.0).reshape([1, _classes.length]);

    // Ejecutar inferencia
    _interpreter!.run(inputReshaped, output);

    // Extraer probabilidades
    final probabilities = (output[0] as List).cast<double>();
    
    print('🔍 DEBUG - Probabilidades RAW del modelo: ${probabilities.map((p) => p.toStringAsFixed(4)).join(", ")}');

    // Aplicar sensibilidades de clase (igual que en Python)
    final adjustedProbas = <String, double>{};
    double totalAdjustedProba = 0.0;

    for (int i = 0; i < _classes.length; i++) {
      final className = _classes[i];
      final prob = probabilities[i];
      final sensitivity = _classSensitivity[className] ?? 1.0;
      final adjustedProb = prob * sensitivity;
      adjustedProbas[className] = adjustedProb;
      totalAdjustedProba += adjustedProb;
    }

    // Normalizar probabilidades ajustadas
    final finalProbas = <String, double>{};
    if (totalAdjustedProba > 0) {
      for (final entry in adjustedProbas.entries) {
        finalProbas[entry.key] = entry.value / totalAdjustedProba;
      }
    } else {
      // Si la suma es 0, usar las probabilidades originales
      for (int i = 0; i < _classes.length; i++) {
        finalProbas[_classes[i]] = probabilities[i];
      }
    }

    // Encontrar la clase con mayor probabilidad
    String bestClass = _classes[0];
    double bestProba = finalProbas[bestClass] ?? 0.0;

    for (final entry in finalProbas.entries) {
      if (entry.value > bestProba) {
        bestClass = entry.key;
        bestProba = entry.value;
      }
    }

    // Ordenar probabilidades de mayor a menor
    final sortedProbas = Map.fromEntries(
      finalProbas.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
    );

    return PlankPrediction(
      className: bestClass,
      confidence: bestProba,
      allProbabilities: sortedProbas,
    );
  }

  /// Normaliza las features usando StandardScaler
  /// Usa los parámetros extraídos del scaler de Python para replicar exactamente
  /// la normalización aplicada durante el entrenamiento
  List<double> _normalizeFeatures(List<double> features) {
    if (features.length != _scalerMean.length) {
      throw Exception('Features length mismatch: ${features.length} vs ${_scalerMean.length}');
    }

    final normalized = <double>[];
    for (int i = 0; i < features.length; i++) {
      normalized.add((features[i] - _scalerMean[i]) / _scalerScale[i]);
    }
    return normalized;
  }

  /// Limpia el buffer de features
  void clearBuffer() {
    _featureBuffer.clear();
  }

  /// Obtiene el tamaño actual del buffer
  int get bufferSize => _featureBuffer.length;

  /// Obtiene el porcentaje de llenado del buffer (0.0 a 1.0)
  double get bufferProgress => _featureBuffer.length / bufferFrameSize;

  /// Libera los recursos del intérprete
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _featureBuffer.clear();
  }

  bool get isInitialized => _isInitialized;
}
