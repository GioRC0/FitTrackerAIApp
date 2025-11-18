/// Modelos para estadísticas de ejercicio

class ExerciseStats {
  final WeeklySummary weeklySummary;
  final List<RecentSession> recentSessions;

  ExerciseStats({
    required this.weeklySummary,
    required this.recentSessions,
  });

  factory ExerciseStats.fromJson(Map<String, dynamic> json) {
    return ExerciseStats(
      weeklySummary: WeeklySummary.fromJson(json['weeklySummary'] as Map<String, dynamic>),
      recentSessions: (json['recentSessions'] as List)
          .map((s) => RecentSession.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WeeklySummary {
  final int totalSessions;
  final int totalReps;
  final int totalSeconds;
  final double averageReps;
  final double averageSeconds;
  final int bestSessionReps;
  final int bestSessionSeconds;
  final double improvementPercentage;
  final String exerciseType;

  WeeklySummary({
    required this.totalSessions,
    required this.totalReps,
    required this.totalSeconds,
    required this.averageReps,
    required this.averageSeconds,
    required this.bestSessionReps,
    required this.bestSessionSeconds,
    required this.improvementPercentage,
    required this.exerciseType,
  });

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    return WeeklySummary(
      totalSessions: json['totalSessions'] as int,
      totalReps: json['totalReps'] as int,
      totalSeconds: json['totalSeconds'] as int,
      averageReps: (json['averageReps'] as num).toDouble(),
      averageSeconds: (json['averageSeconds'] as num).toDouble(),
      bestSessionReps: json['bestSessionReps'] as int,
      bestSessionSeconds: json['bestSessionSeconds'] as int,
      improvementPercentage: (json['improvementPercentage'] as num).toDouble(),
      exerciseType: json['exerciseType'] as String,
    );
  }

  bool get isPlank => exerciseType.toLowerCase() == 'plank';
}

class RecentSession {
  final String id;
  final DateTime date;
  final int reps;
  final int seconds;
  final String duration;
  final String qualityLabel;
  final double techniquePercentage;

  RecentSession({
    required this.id,
    required this.date,
    required this.reps,
    required this.seconds,
    required this.duration,
    required this.qualityLabel,
    required this.techniquePercentage,
  });

  factory RecentSession.fromJson(Map<String, dynamic> json) {
    return RecentSession(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      reps: json['reps'] as int,
      seconds: json['seconds'] as int,
      duration: json['duration'] as String,
      qualityLabel: json['qualityLabel'] as String,
      techniquePercentage: (json['techniquePercentage'] as num).toDouble(),
    );
  }
}
