class ExerciseDto {
  final String id;
  final String name;
  final String shortDescription;
  final String fullDescription;
  final String difficulty;
  final String muscleGroup;
  final int minTime;
  final int maxTime;
  final List<String> steps;
  final List<String> tips;
  final String imageUrl;
  final String shortImageUrl;

  ExerciseDto({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.fullDescription,
    required this.difficulty,
    required this.muscleGroup,
    required this.minTime,
    required this.maxTime,
    required this.steps,
    required this.tips,
    required this.imageUrl,
    required this.shortImageUrl,
  });

  factory ExerciseDto.fromJson(Map<String, dynamic> json) {
    return ExerciseDto(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Nombre no disponible',
      shortDescription: json['shortDescription'] ?? '',
      fullDescription: json['fullDescription'] ?? '',
      difficulty: json['difficulty'] ?? 'Desconocida',
      muscleGroup: json['muscleGroup'] ?? 'Desconocido',
      minTime: json['minTime'] ?? 0,
      maxTime: json['maxTime'] ?? 0,
      steps: List<String>.from(json['steps'] ?? []),
      tips: List<String>.from(json['tips'] ?? []),
      imageUrl: json['imageUrl'] ?? '',
      shortImageUrl: json['shortImageUrl'] ?? '',
    );
  }
}