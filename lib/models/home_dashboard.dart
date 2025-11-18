/// Modelos para el dashboard de inicio (Home)

class HomeDashboard {
  final UserSummary user;
  final HomeStats stats;
  final RecentExercise? lastExercise;
  final List<RecentExercise> recentActivity;

  HomeDashboard({
    required this.user,
    required this.stats,
    this.lastExercise,
    required this.recentActivity,
  });

  factory HomeDashboard.fromJson(Map<String, dynamic> json) {
    return HomeDashboard(
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      stats: HomeStats.fromJson(json['stats'] as Map<String, dynamic>),
      lastExercise: json['lastExercise'] != null
          ? RecentExercise.fromJson(json['lastExercise'] as Map<String, dynamic>)
          : null,
      recentActivity: (json['recentActivity'] as List)
          .map((e) => RecentExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class UserSummary {
  final String name;

  UserSummary({required this.name});

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      name: json['name'] as String,
    );
  }
}

class HomeStats {
  final int weeklyWorkouts;
  final int weeklyTotalReps;
  final int weeklyTotalSeconds;
  final int bestStreak;
  final int currentStreak;

  HomeStats({
    required this.weeklyWorkouts,
    required this.weeklyTotalReps,
    required this.weeklyTotalSeconds,
    required this.bestStreak,
    required this.currentStreak,
  });

  factory HomeStats.fromJson(Map<String, dynamic> json) {
    return HomeStats(
      weeklyWorkouts: json['weeklyWorkouts'] as int,
      weeklyTotalReps: json['weeklyTotalReps'] as int,
      weeklyTotalSeconds: json['weeklyTotalSeconds'] as int,
      bestStreak: json['bestStreak'] as int,
      currentStreak: json['currentStreak'] as int,
    );
  }
}

class RecentExercise {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String exerciseType;
  final DateTime date;
  final int reps;
  final int seconds;
  final String improvement;
  final String duration;
  final String? imageUrl;

  RecentExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseType,
    required this.date,
    required this.reps,
    required this.seconds,
    required this.improvement,
    required this.duration,
    this.imageUrl,
  });

  factory RecentExercise.fromJson(Map<String, dynamic> json) {
    return RecentExercise(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      exerciseType: json['exerciseType'] as String,
      date: DateTime.parse(json['date'] as String),
      reps: json['reps'] as int,
      seconds: json['seconds'] as int,
      improvement: json['improvement'] as String,
      duration: json['duration'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  bool get isPlank => exerciseType.toLowerCase() == 'plank';
}
