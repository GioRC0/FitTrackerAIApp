import 'package:flutter/material.dart';
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:intl/intl.dart'; // Necesitarás añadir 'intl' a tu pubspec.yaml
import 'package:fitracker_app/screens/exercise/pre_training_screen.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final ExerciseDto exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  // --- Datos Harcodeados ---
  static const weeklyData = {
    'totalSessions': 5,
    'totalReps': 125,
    'avgReps': 25,
    'bestSession': 30,
    'improvement': '+15%'
  };

  static const recentSessions = [
    {'date': '2025-10-01', 'reps': 25, 'duration': '5 min', 'form': 'Excelente'},
    {'date': '2025-09-30', 'reps': 22, 'duration': '4 min', 'form': 'Buena'},
    {'date': '2025-09-29', 'reps': 28, 'duration': '6 min', 'form': 'Excelente'},
  ];
  // -------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.name),
            Text(
              exercise.shortDescription,
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
            // --- Botón Comenzar Entrenamiento ---
            ElevatedButton.icon(
              onPressed: () {
                // 2. Navega a la pantalla de Pre-entrenamiento
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PreTrainingScreen(exercise: exercise),
                  ),
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
            ),
            const SizedBox(height: 24),

            // --- Resumen de la Semana ---
            _buildWeeklySummaryCard(context),
            const SizedBox(height: 24),

            // --- Sesiones Recientes ---
            _buildRecentSessionsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySummaryCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // TODO: Navegar a la pantalla de progreso detallado
          print('Ver progreso detallado');
        },
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.trending_up, color: Colors.green),
              title: const Text('Resumen de la Semana', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Toca para ver progreso detallado'),
              trailing: Chip(
                label: Text(weeklyData['improvement'].toString()),
                backgroundColor: Colors.green.shade100,
                labelStyle: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(child: _buildStatItem(context, Icons.track_changes, 'Total reps', weeklyData['totalReps'].toString())),
                  Expanded(child: _buildStatItem(context, Icons.calendar_today, 'Sesiones', weeklyData['totalSessions'].toString())),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Row(
                children: [
                  Expanded(child: _buildStatItem(context, Icons.functions, 'Promedio', '${weeklyData['avgReps']} reps')),
                  Expanded(child: _buildStatItem(context, Icons.emoji_events, 'Mejor sesión', '${weeklyData['bestSession']} reps')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentSessionsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesiones Recientes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...recentSessions.map((session) => _buildSessionItem(session)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    final date = DateFormat('d MMM y', 'es_ES').format(DateTime.parse(session['date']));
    final form = session['form'].toString();
    
    Color formColor;
    Color formTextColor;

    switch (form) {
      case 'Excelente':
        formColor = Colors.green.shade100;
        formTextColor = Colors.green.shade800;
        break;
      case 'Buena':
        formColor = Colors.blue.shade100;
        formTextColor = Colors.blue.shade800;
        break;
      default: // Regular
        formColor = Colors.yellow.shade100;
        formTextColor = Colors.yellow.shade800;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${session['reps']} reps • ${session['duration']}', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            Chip(
              label: Text(form),
              backgroundColor: formColor,
              labelStyle: TextStyle(color: formTextColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}