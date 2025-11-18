class UserProfile {
  final String id;
  final String name;
  final String lastName;
  final String email;
  final double weight;
  final int height;
  final DateTime dateOfBirth;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.weight,
    required this.height,
    required this.dateOfBirth,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
      height: json['height'] ?? 0,
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lastName': lastName,
      'email': email,
      'weight': weight,
      'height': height,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get initials => '${name.isNotEmpty ? name[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
  String get fullName => '$name $lastName';
}

class UserStats {
  final int activeDays;
  final int masteredExercises;
  final int completedGoals;
  final int totalWorkouts;
  final int totalReps;
  final int totalSeconds;
  final int currentStreak;
  final int bestStreak;

  UserStats({
    required this.activeDays,
    required this.masteredExercises,
    required this.completedGoals,
    required this.totalWorkouts,
    required this.totalReps,
    required this.totalSeconds,
    required this.currentStreak,
    required this.bestStreak,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      activeDays: json['activeDays'] ?? 0,
      masteredExercises: json['masteredExercises'] ?? 0,
      completedGoals: json['completedGoals'] ?? 0,
      totalWorkouts: json['totalWorkouts'] ?? 0,
      totalReps: json['totalReps'] ?? 0,
      totalSeconds: json['totalSeconds'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      bestStreak: json['bestStreak'] ?? 0,
    );
  }
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool earned;
  final DateTime? earnedAt;
  final String category;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.earned,
    this.earnedAt,
    required this.category,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '🏆',
      earned: json['earned'] ?? false,
      earnedAt: json['earnedAt'] != null ? DateTime.parse(json['earnedAt']) : null,
      category: json['category'] ?? '',
    );
  }
}

class UpdateProfileRequest {
  final String name;
  final String lastName;
  final double weight;
  final int height;

  UpdateProfileRequest({
    required this.name,
    required this.lastName,
    required this.weight,
    required this.height,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lastName': lastName,
      'weight': weight,
      'height': height,
    };
  }
}
