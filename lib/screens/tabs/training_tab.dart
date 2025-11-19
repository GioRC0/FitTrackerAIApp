import 'package:flutter/material.dart';
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:fitracker_app/api/exercise_service.dart';
import 'package:fitracker_app/screens/exercise/exercise_detail_screen.dart';


class TrainingTab extends StatefulWidget {
  const TrainingTab({super.key});

  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab> {
  late Future<List<ExerciseDto>> _exercisesFuture;
  final ExerciseService _exerciseService = ExerciseService();

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  void _loadExercises() {
    _exercisesFuture = _exerciseService.getExercises();
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'principiante':
        return Colors.green.shade100;
      case 'intermedio':
        return Colors.yellow.shade100;
      case 'avanzado':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getDifficultyTextColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'principiante':
        return Colors.green.shade800;
      case 'intermedio':
        return Colors.yellow.shade800;
      case 'avanzado':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExerciseDto>>(
      future: _exercisesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error al cargar los ejercicios: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay ejercicios disponibles.'));
        }

        final exercises = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async => _loadExercises(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return _buildExerciseCard(context, exercise);
            },
          ),
        );
      },
    );
  }

  Widget _buildExerciseCard(BuildContext context, ExerciseDto exercise) {
    final duration = '${exercise.minTime}-${exercise.maxTime} min';
    final difficultyColor = _getDifficultyColor(exercise.difficulty);
    final difficultyTextColor = _getDifficultyTextColor(exercise.difficulty);

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias, // Ensures the InkWell ripple effect is contained
      child: InkWell(
        onTap: () {
          // 2. Implementa la navegación
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExerciseDetailScreen(exercise: exercise),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header: Imagen, Título, Descripción y Botón Play ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      exercise.imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 64,
                          height: 64,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / 
                                    loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported, size: 64),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          exercise.shortDescription,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.play_circle_outline, color: Theme.of(context).primaryColor, size: 28),
                ],
              ),
              const SizedBox(height: 12),
              // --- Info: Dificultad, Grupo Muscular y Duración ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 8.0,
                    children: [
                      Chip(
                        label: Text(exercise.difficulty),
                        backgroundColor: difficultyColor,
                        labelStyle: TextStyle(color: difficultyTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(exercise.muscleGroup),
                        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
                        backgroundColor: Colors.transparent,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: Theme.of(context).iconTheme.color?.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        duration,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // --- Stats: Mejor Marca y Progreso ---
              Row(
                children: [
                  Icon(Icons.emoji_events_outlined, size: 16, color: Theme.of(context).iconTheme.color?.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Text(
                    'Mejor: 20',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.trending_up, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('+12% esta semana', style: TextStyle(color: Colors.green)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}