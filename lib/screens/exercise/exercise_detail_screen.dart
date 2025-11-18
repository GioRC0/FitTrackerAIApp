import 'package:flutter/material.dart';
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:fitracker_app/models/exercise_stats.dart';
import 'package:fitracker_app/services/training_session_service.dart';
import 'package:intl/intl.dart';
import 'package:fitracker_app/screens/exercise/pre_training_screen.dart';
import 'package:fitracker_app/screens/exercise/progress_dashboard_screen.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final ExerciseDto exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final TrainingSessionService _sessionService = TrainingSessionService();
  ExerciseStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stats = await _sessionService.getExerciseStats(widget.exercise.id, recentLimit: 5);
      
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar estadísticas';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.exercise.name),
            Text(
              widget.exercise.shortDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Recargar estadísticas',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _stats == null
                  ? _buildNoDataView()
                  : _buildContentView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay datos disponibles',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '¡Comienza tu primera sesión!',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PreTrainingScreen(exercise: widget.exercise),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Comenzar Entrenamiento'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Botón Comenzar Entrenamiento ---
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PreTrainingScreen(exercise: widget.exercise),
                ),
              ).then((_) => _loadStats()); // Recargar stats al volver
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
    );
  }

  Widget _buildWeeklySummaryCard(BuildContext context) {
    final summary = _stats!.weeklySummary;
    final improvementText = summary.improvementPercentage >= 0
        ? '+${summary.improvementPercentage.toStringAsFixed(1)}%'
        : '${summary.improvementPercentage.toStringAsFixed(1)}%';
    final improvementColor = summary.improvementPercentage >= 0 ? Colors.green : Colors.red;
    
    final isPlank = summary.isPlank;
    final totalValue = isPlank ? summary.totalSeconds : summary.totalReps;
    final averageValue = isPlank ? summary.averageSeconds : summary.averageReps;
    final bestValue = isPlank ? summary.bestSessionSeconds : summary.bestSessionReps;
    final unit = isPlank ? 's' : 'reps';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProgressDashboardScreen(exercise: widget.exercise),
            ),
          );
        },
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.trending_up, color: improvementColor),
              title: const Text('Resumen de la Semana', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Toca para ver progreso detallado'),
              trailing: Chip(
                label: Text(improvementText),
                backgroundColor: improvementColor.shade100,
                labelStyle: TextStyle(color: improvementColor.shade800, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      Icons.track_changes,
                      isPlank ? 'Total tiempo' : 'Total reps',
                      '$totalValue $unit',
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      Icons.calendar_today,
                      'Sesiones',
                      summary.totalSessions.toString(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      Icons.functions,
                      'Promedio',
                      '${averageValue.toStringAsFixed(isPlank ? 0 : 1)} $unit',
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      Icons.emoji_events,
                      'Mejor sesión',
                      '$bestValue $unit',
                    ),
                  ),
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
    final sessions = _stats!.recentSessions;
    
    if (sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.history, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No hay sesiones recientes',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesiones Recientes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...sessions.map((session) => _buildSessionItem(session)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(RecentSession session) {
    final date = DateFormat('d MMM y', 'es_ES').format(session.date);
    final qualityLabel = session.qualityLabel;
    
    Color formColor;
    Color formTextColor;

    switch (qualityLabel) {
      case 'Excelente':
        formColor = Colors.green.shade100;
        formTextColor = Colors.green.shade800;
        break;
      case 'Buena':
        formColor = Colors.blue.shade100;
        formTextColor = Colors.blue.shade800;
        break;
      case 'Regular':
        formColor = Colors.yellow.shade100;
        formTextColor = Colors.yellow.shade800;
        break;
      case 'Mala':
        formColor = Colors.red.shade100;
        formTextColor = Colors.red.shade800;
        break;
      default:
        formColor = Colors.grey.shade100;
        formTextColor = Colors.grey.shade800;
    }

    final isPlank = session.seconds > 0;
    final performanceText = isPlank
        ? '${session.seconds}s • ${session.duration}'
        : '${session.reps} reps • ${session.duration}';

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    performanceText,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Técnica: ${session.techniquePercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(qualityLabel),
              backgroundColor: formColor,
              labelStyle: TextStyle(
                color: formTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}