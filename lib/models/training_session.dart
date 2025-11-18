/// Modelos para sesión de entrenamiento

/// Respuesta del servidor al crear una sesión
class TrainingSessionResponse {
  final String id;
  final String userId;
  final String exerciseId;
  final String exerciseType;
  final String exerciseName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int totalReps;
  final List<RepData>? repsData;
  final int totalSeconds;
  final List<SecondData>? secondsData;
  final PerformanceMetrics metrics;
  final DateTime createdAt;

  TrainingSessionResponse({
    required this.id,
    required this.userId,
    required this.exerciseId,
    required this.exerciseType,
    required this.exerciseName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.totalReps,
    this.repsData,
    required this.totalSeconds,
    this.secondsData,
    required this.metrics,
    required this.createdAt,
  });

  factory TrainingSessionResponse.fromJson(Map<String, dynamic> json) {
    return TrainingSessionResponse(
      id: json['id'] as String,
      userId: json['userId'] as String,
      exerciseId: json['exerciseId'] as String,
      exerciseType: json['exerciseType'] as String,
      exerciseName: json['exerciseName'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      durationSeconds: json['durationSeconds'] as int,
      totalReps: json['totalReps'] as int? ?? 0,
      repsData: json['repsData'] != null
          ? (json['repsData'] as List)
              .map((r) => RepData.fromJson(r as Map<String, dynamic>))
              .toList()
          : null,
      totalSeconds: json['totalSeconds'] as int? ?? 0,
      secondsData: json['secondsData'] != null
          ? (json['secondsData'] as List)
              .map((s) => SecondData.fromJson(s as Map<String, dynamic>))
              .toList()
          : null,
      metrics: PerformanceMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Progreso semanal
class WeeklyProgress {
  final String exerciseId;
  final String exerciseName;
  final WeekStats currentWeek;
  final WeekStats previousWeek;
  final ProgressComparison comparison;

  WeeklyProgress({
    required this.exerciseId,
    required this.exerciseName,
    required this.currentWeek,
    required this.previousWeek,
    required this.comparison,
  });

  factory WeeklyProgress.fromJson(Map<String, dynamic> json) {
    return WeeklyProgress(
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      currentWeek: WeekStats.fromJson(json['currentWeek'] as Map<String, dynamic>),
      previousWeek: WeekStats.fromJson(json['previousWeek'] as Map<String, dynamic>),
      comparison: ProgressComparison.fromJson(json['comparison'] as Map<String, dynamic>),
    );
  }
}

class WeekStats {
  final int totalSessions;
  final int totalReps;
  final int totalSeconds;
  final double averageTechniquePercentage;
  final double averageConsistencyScore;
  final double averageConfidence;

  WeekStats({
    required this.totalSessions,
    required this.totalReps,
    required this.totalSeconds,
    required this.averageTechniquePercentage,
    required this.averageConsistencyScore,
    required this.averageConfidence,
  });

  factory WeekStats.fromJson(Map<String, dynamic> json) {
    return WeekStats(
      totalSessions: json['totalSessions'] as int,
      totalReps: json['totalReps'] as int,
      totalSeconds: json['totalSeconds'] as int,
      averageTechniquePercentage: (json['averageTechniquePercentage'] as num).toDouble(),
      averageConsistencyScore: (json['averageConsistencyScore'] as num).toDouble(),
      averageConfidence: (json['averageConfidence'] as num).toDouble(),
    );
  }
}

class ProgressComparison {
  final double sessionsChange;
  final double repsChange;
  final double secondsChange;
  final double techniqueChange;
  final double consistencyChange;
  final double confidenceChange;

  ProgressComparison({
    required this.sessionsChange,
    required this.repsChange,
    required this.secondsChange,
    required this.techniqueChange,
    required this.consistencyChange,
    required this.confidenceChange,
  });

  factory ProgressComparison.fromJson(Map<String, dynamic> json) {
    return ProgressComparison(
      sessionsChange: (json['sessionsChange'] as num).toDouble(),
      repsChange: (json['repsChange'] as num).toDouble(),
      secondsChange: (json['secondsChange'] as num).toDouble(),
      techniqueChange: (json['techniqueChange'] as num).toDouble(),
      consistencyChange: (json['consistencyChange'] as num).toDouble(),
      confidenceChange: (json['confidenceChange'] as num).toDouble(),
    );
  }
}

class RepData {
  final int repNumber;
  final String classification;
  final double confidence;
  final Map<String, double> probabilities;
  final DateTime timestamp;

  RepData({
    required this.repNumber,
    required this.classification,
    required this.confidence,
    required this.probabilities,
    required this.timestamp,
  });

  factory RepData.fromJson(Map<String, dynamic> json) {
    return RepData(
      repNumber: json['repNumber'] as int,
      classification: json['classification'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      probabilities: Map<String, double>.from(
        (json['probabilities'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'repNumber': repNumber,
        'classification': classification,
        'confidence': confidence,
        'probabilities': probabilities,
        'timestamp': timestamp.toIso8601String(),
      };
}

class SecondData {
  final int secondNumber;
  final String classification;
  final double confidence;
  final Map<String, double> probabilities;
  final DateTime timestamp;

  SecondData({
    required this.secondNumber,
    required this.classification,
    required this.confidence,
    required this.probabilities,
    required this.timestamp,
  });

  factory SecondData.fromJson(Map<String, dynamic> json) {
    return SecondData(
      secondNumber: json['secondNumber'] as int,
      classification: json['classification'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      probabilities: Map<String, double>.from(
        (json['probabilities'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'secondNumber': secondNumber,
        'classification': classification,
        'confidence': confidence,
        'probabilities': probabilities,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PerformanceMetrics {
  final double techniquePercentage;
  final double consistencyScore;
  final double averageConfidence;
  final double? controlScore;
  final double? stabilityScore;
  final double? alignmentScore;
  final double? balanceScore;
  final double? depthScore;
  final double? hipScore;
  final double? coreScore;
  final double? armPositionScore;
  final double? resistanceScore;
  final double? repsPerMinute;

  PerformanceMetrics({
    required this.techniquePercentage,
    required this.consistencyScore,
    required this.averageConfidence,
    this.controlScore,
    this.stabilityScore,
    this.alignmentScore,
    this.balanceScore,
    this.depthScore,
    this.hipScore,
    this.coreScore,
    this.armPositionScore,
    this.resistanceScore,
    this.repsPerMinute,
  });

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return PerformanceMetrics(
      techniquePercentage: (json['techniquePercentage'] as num).toDouble(),
      consistencyScore: (json['consistencyScore'] as num).toDouble(),
      averageConfidence: (json['averageConfidence'] as num).toDouble(),
      controlScore: json['controlScore'] != null ? (json['controlScore'] as num).toDouble() : null,
      stabilityScore: json['stabilityScore'] != null ? (json['stabilityScore'] as num).toDouble() : null,
      alignmentScore: json['alignmentScore'] != null ? (json['alignmentScore'] as num).toDouble() : null,
      balanceScore: json['balanceScore'] != null ? (json['balanceScore'] as num).toDouble() : null,
      depthScore: json['depthScore'] != null ? (json['depthScore'] as num).toDouble() : null,
      hipScore: json['hipScore'] != null ? (json['hipScore'] as num).toDouble() : null,
      coreScore: json['coreScore'] != null ? (json['coreScore'] as num).toDouble() : null,
      armPositionScore: json['armPositionScore'] != null ? (json['armPositionScore'] as num).toDouble() : null,
      resistanceScore: json['resistanceScore'] != null ? (json['resistanceScore'] as num).toDouble() : null,
      repsPerMinute: json['repsPerMinute'] != null ? (json['repsPerMinute'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'techniquePercentage': techniquePercentage,
      'consistencyScore': consistencyScore,
      'averageConfidence': averageConfidence,
    };

    if (controlScore != null) json['controlScore'] = controlScore;
    if (stabilityScore != null) json['stabilityScore'] = stabilityScore;
    if (alignmentScore != null) json['alignmentScore'] = alignmentScore;
    if (balanceScore != null) json['balanceScore'] = balanceScore;
    if (depthScore != null) json['depthScore'] = depthScore;
    if (hipScore != null) json['hipScore'] = hipScore;
    if (coreScore != null) json['coreScore'] = coreScore;
    if (armPositionScore != null) json['armPositionScore'] = armPositionScore;
    if (resistanceScore != null) json['resistanceScore'] = resistanceScore;
    if (repsPerMinute != null) json['repsPerMinute'] = repsPerMinute;

    return json;
  }
}

class TrainingSessionData {
  final String exerciseId;
  final String exerciseType;
  final String exerciseName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int? totalReps;
  final List<RepData>? repsData;
  final int? totalSeconds;
  final List<SecondData>? secondsData;
  final PerformanceMetrics metrics;

  TrainingSessionData({
    required this.exerciseId,
    required this.exerciseType,
    required this.exerciseName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    this.totalReps,
    this.repsData,
    this.totalSeconds,
    this.secondsData,
    required this.metrics,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'exerciseId': exerciseId,
      'exerciseType': exerciseType,
      'exerciseName': exerciseName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationSeconds': durationSeconds,
      'metrics': metrics.toJson(),
    };

    if (totalReps != null) {
      json['totalReps'] = totalReps!;
      json['repsData'] = repsData?.map((r) => r.toJson()).toList() ?? [];
    }

    if (totalSeconds != null) {
      json['totalSeconds'] = totalSeconds!;
      json['secondsData'] = secondsData?.map((s) => s.toJson()).toList() ?? [];
    }

    return json;
  }
}
