import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

const List<String> classLabels = [
  'plank_cadera_caida',
  'plank_codos_abiertos',
  'plank_correcto',
  'plank_pelvis_levantada'
];

class PlankClassifier {
  Interpreter? _interpreter;
  late List<double> _mean;
  late List<double> _scale;

  /// 🐛 DEBUG: Prueba manual con keypoints fijos para comparar con Python
  Future<void> testWithManualFrame() async {
    // ⚠️ REEMPLAZA ESTOS VALORES CON LOS QUE IMPRIMAS DESDE PYTHON
    final testKeypoints = {
      'shoulder_l': [0.5, 0.4],
      'hip_l': [0.52, 0.7],
      'ankle_l': [0.55, 0.95],
      'elbow_l': [0.45, 0.5],
      'wrist_l': [0.4, 0.6],
    };
    
    final buffer = List.generate(30, (_) => testKeypoints);
    if (_interpreter == null) await load();
    
    List<List<double>> featuresBuffer = buffer.map(extractFeatures).toList();
    List<double> stats = computeStats(featuresBuffer);
    List<double> norm = normalize(stats);
    var probs = predict(norm);
    
    int maxIdx = 0;
    double maxProb = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > maxProb) {
        maxProb = probs[i];
        maxIdx = i;
      }
    }
    print('Test manual: ${classLabels[maxIdx]} (${(maxProb * 100).toStringAsFixed(1)}%)');
  }

  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset('assets/models/plank_classifier_model.tflite');
    String scalerJson = await rootBundle.loadString('assets/models/plank_scaler_params.json');
    final scalerParams = json.decode(scalerJson);
    _mean = List<double>.from(scalerParams['mean'].map((x) => x.toDouble()));
    _scale = List<double>.from(scalerParams['scale'].map((x) => x.toDouble()));
  }

  double calculateAngle(List<double> a, List<double> b, List<double> c) {
    double radians = (atan2(c[1] - b[1], c[0] - b[0]) - atan2(a[1] - b[1], a[0] - b[0]));
    double angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) angle = 360 - angle;
    return angle;
  }

  List<double> extractFeatures(Map<String, List<double>> keypoints, {bool debug = false}) {
    double bodyAngle = calculateAngle(keypoints['shoulder_l']!, keypoints['hip_l']!, keypoints['ankle_l']!);
    double hipShoulderVerticalDiff = keypoints['hip_l']![1] - keypoints['shoulder_l']![1];
    double hipAnkleVerticalDiff = keypoints['hip_l']![1] - keypoints['ankle_l']![1];
    double shoulderElbowAngle = calculateAngle(keypoints['hip_l']!, keypoints['shoulder_l']!, keypoints['elbow_l']!);
    double wristShoulderHipAngle = calculateAngle(keypoints['wrist_l']!, keypoints['shoulder_l']!, keypoints['hip_l']!);
    
    return [
      bodyAngle,
      hipShoulderVerticalDiff,
      hipAnkleVerticalDiff,
      shoulderElbowAngle,
      wristShoulderHipAngle
    ];
  }

  List<double> computeStats(List<List<double>> buffer) {
    List<double> stats = [];
    for (int i = 0; i < 5; i++) {
      List<double> values = buffer.map((f) => f[i]).toList();
      double mean = values.reduce((a, b) => a + b) / values.length;
      double std = sqrt(values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length);
      double minVal = values.reduce(min);
      double maxVal = values.reduce(max);
      double range = maxVal - minVal;
      stats.addAll([mean, std, minVal, maxVal, range]);
    }
    return stats;
  }

  List<double> normalize(List<double> features) {
    List<double> norm = [];
    for (int i = 0; i < features.length; i++) {
      norm.add((features[i] - _mean[i]) / _scale[i]);
    }
    return norm;
  }

  List<double> predict(List<double> normFeatures) {
    var input = [normFeatures];
    var output = List.filled(classLabels.length, 0.0).reshape([1, classLabels.length]);
    _interpreter!.run(input, output);
    return List<double>.from(output[0]);
  }

  Future<List<double>> classify(List<Map<String, List<double>>> buffer, {bool debug = false}) async {
    if (_interpreter == null) await load();
    List<List<double>> featuresBuffer = buffer.map(extractFeatures).toList();
    
    // DEBUG: Imprimir features del primer frame
    if (featuresBuffer.isNotEmpty) {
      print('📊 Features from first frame:');
      final features = featuresBuffer[0];
      print('  body_angle: ${features[0].toStringAsFixed(4)}');
      print('  hip_shoulder_vertical_diff: ${features[1].toStringAsFixed(4)}');
      print('  hip_ankle_vertical_diff: ${features[2].toStringAsFixed(4)}');
      print('  shoulder_elbow_angle: ${features[3].toStringAsFixed(4)}');
      print('  wrist_shoulder_hip_angle: ${features[4].toStringAsFixed(4)}');
    }
    
    List<double> stats = computeStats(featuresBuffer);
    
    // DEBUG: Imprimir stats computados
    print('📈 Computed stats (25 values):');
    for (int i = 0; i < 5; i++) {
      final featureNames = ['body_angle', 'hip_shoulder_vertical_diff', 'hip_ankle_vertical_diff', 'shoulder_elbow_angle', 'wrist_shoulder_hip_angle'];
      print('  ${featureNames[i]}: mean=${stats[i*5].toStringAsFixed(4)}, std=${stats[i*5+1].toStringAsFixed(4)}, min=${stats[i*5+2].toStringAsFixed(4)}, max=${stats[i*5+3].toStringAsFixed(4)}, range=${stats[i*5+4].toStringAsFixed(4)}');
    }
    
    List<double> norm = normalize(stats);
    
    // DEBUG: Imprimir features normalizados
    print('🔢 Normalized features (after StandardScaler):');
    print('  ${norm.map((v) => v.toStringAsFixed(4)).join(', ')}');
    
    return predict(norm);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
