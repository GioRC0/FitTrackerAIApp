/// Modelos para el dashboard de progreso

// ========== Progress Data ==========
class ProgressData {
  final String timeRange;
  final String exerciseId;
  final String exerciseName;
  final String exerciseType;
  final List<ProgressDataPoint> dataPoints;
  final ProgressSummary summary;

  ProgressData({
    required this.timeRange,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseType,
    required this.dataPoints,
    required this.summary,
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    return ProgressData(
      timeRange: json['timeRange'] as String,
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      exerciseType: json['exerciseType'] as String,
      dataPoints: (json['dataPoints'] as List)
          .map((dp) => ProgressDataPoint.fromJson(dp as Map<String, dynamic>))
          .toList(),
      summary: ProgressSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }

  bool get isPlank => exerciseType.toLowerCase() == 'plank';
}

class ProgressDataPoint {
  final String label;
  final DateTime date;
  final int reps;
  final int seconds;
  final double averageForm;

  ProgressDataPoint({
    required this.label,
    required this.date,
    required this.reps,
    required this.seconds,
    required this.averageForm,
  });

  factory ProgressDataPoint.fromJson(Map<String, dynamic> json) {
    return ProgressDataPoint(
      label: json['label'] as String,
      date: DateTime.parse(json['date'] as String),
      reps: json['reps'] as int,
      seconds: json['seconds'] as int,
      averageForm: (json['averageForm'] as num).toDouble(),
    );
  }
}

class ProgressSummary {
  final int totalReps;
  final int totalSeconds;
  final int totalSessions;
  final int daysWithActivity;
  final double averagePerDay;
  final double averageFormScore;
  final BestDay bestDay;
  final double improvement;
  final String consistency;

  ProgressSummary({
    required this.totalReps,
    required this.totalSeconds,
    required this.totalSessions,
    required this.daysWithActivity,
    required this.averagePerDay,
    required this.averageFormScore,
    required this.bestDay,
    required this.improvement,
    required this.consistency,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      totalReps: json['totalReps'] as int,
      totalSeconds: json['totalSeconds'] as int,
      totalSessions: json['totalSessions'] as int,
      daysWithActivity: json['daysWithActivity'] as int,
      averagePerDay: (json['averagePerDay'] as num).toDouble(),
      averageFormScore: (json['averageFormScore'] as num).toDouble(),
      bestDay: BestDay.fromJson(json['bestDay'] as Map<String, dynamic>),
      improvement: (json['improvement'] as num).toDouble(),
      consistency: json['consistency'] as String,
    );
  }
}

class BestDay {
  final String label;
  final int value;

  BestDay({
    required this.label,
    required this.value,
  });

  factory BestDay.fromJson(Map<String, dynamic> json) {
    return BestDay(
      label: json['label'] as String,
      value: json['value'] as int,
    );
  }
}

// ========== Form Analysis ==========
class FormAnalysis {
  final double averageScore;
  final List<AspectScore> aspectScores;
  final List<TrendPoint> trend;

  FormAnalysis({
    required this.averageScore,
    required this.aspectScores,
    required this.trend,
  });

  factory FormAnalysis.fromJson(Map<String, dynamic> json) {
    return FormAnalysis(
      averageScore: (json['averageScore'] as num).toDouble(),
      aspectScores: (json['aspectScores'] as List)
          .map((as) => AspectScore.fromJson(as as Map<String, dynamic>))
          .toList(),
      trend: (json['trend'] as List)
          .map((tp) => TrendPoint.fromJson(tp as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AspectScore {
  final String aspect;
  final double score;
  final String metric;

  AspectScore({
    required this.aspect,
    required this.score,
    required this.metric,
  });

  factory AspectScore.fromJson(Map<String, dynamic> json) {
    return AspectScore(
      aspect: json['aspect'] as String,
      score: (json['score'] as num).toDouble(),
      metric: json['metric'] as String,
    );
  }
}

class TrendPoint {
  final DateTime date;
  final double score;

  TrendPoint({
    required this.date,
    required this.score,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: DateTime.parse(json['date'] as String),
      score: (json['score'] as num).toDouble(),
    );
  }
}

// ========== Goals ==========
class Goals {
  final List<Goal> goals;
  final int currentStreak;
  final int longestStreak;

  Goals({
    required this.goals,
    required this.currentStreak,
    required this.longestStreak,
  });

  factory Goals.fromJson(Map<String, dynamic> json) {
    return Goals(
      goals: (json['goals'] as List)
          .map((g) => Goal.fromJson(g as Map<String, dynamic>))
          .toList(),
      currentStreak: json['currentStreak'] as int,
      longestStreak: json['longestStreak'] as int,
    );
  }
}

class Goal {
  final String id;
  final String title;
  final String description;
  final int current;
  final int target;
  final double progress;
  final bool achieved;

  Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.progress,
    required this.achieved,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      current: json['current'] as int,
      target: json['target'] as int,
      progress: (json['progress'] as num).toDouble(),
      achieved: json['achieved'] as bool,
    );
  }
}
