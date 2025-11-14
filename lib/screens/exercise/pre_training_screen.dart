import 'package:flutter/material.dart';
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:fitracker_app/screens/camera/camera_training_screen.dart';

class PreTrainingScreen extends StatelessWidget {
  final ExerciseDto exercise;

  const PreTrainingScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final duration = '${exercise.minTime}-${exercise.maxTime} min';
    final bestMark = '20 reps'; // Dato harcodeado como en el ejemplo

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.name),
            Text(
              'Preparación para entrenar',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageHeader(context),
            const SizedBox(height: 24),
            _buildDescriptionCard(context),
            const SizedBox(height: 16),
            _buildStatsRow(context, duration, bestMark),
            const SizedBox(height: 16),
            _buildStepsCard(context),
            const SizedBox(height: 16),
            if (exercise.tips.isNotEmpty) ...[
              _buildTipCard(context),
              const SizedBox(height: 24),
            ],
            _buildStartButton(context),
            const SizedBox(height: 16),
            _buildSafetyNote(context),
          ],
        ),
      ),
    );
  }

  Widget _buildImageHeader(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Image.network(
            exercise.imageUrl,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              height: 200,
              child: Icon(Icons.image_not_supported, size: 50),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(exercise.difficulty),
                      backgroundColor: Theme.of(context).primaryColor,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                    Chip(
                      label: Text(exercise.muscleGroup),
                      backgroundColor: Colors.white.withOpacity(0.8),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
        title: const Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Text(exercise.fullDescription),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, String duration, String bestMark) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(context, Icons.timer_outlined, 'Duración estimada', duration)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(context, Icons.emoji_events_outlined, 'Tu mejor marca', bestMark)),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, IconData icon, String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paso a Paso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...List.generate(exercise.steps.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(exercise.steps[index])),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Consejo Clave', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(exercise.tips.first),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        // Navega a la pantalla de entrenamiento con cámara
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CameraTrainingScreen()),
        );
      },
      icon: const Icon(Icons.play_arrow),
      label: const Text('Comenzar Entrenamiento'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSafetyNote(BuildContext context) {
    return Card(
      color: Colors.grey.shade200,
      child: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text(
          'Recuerda calentar antes de comenzar y detente si sientes dolor. La IA monitoreará tu técnica en tiempo real.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }
}