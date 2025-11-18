import 'package:flutter/material.dart';
import 'package:fitracker_app/models/training_session.dart';
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:fitracker_app/config/app_colors.dart';
import 'package:intl/intl.dart';

class SessionReportScreen extends StatelessWidget {
  final TrainingSessionData sessionData;
  final ExerciseDto exercise;

  const SessionReportScreen({
    Key? key,
    required this.sessionData,
    required this.exercise,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reporte de Sesión',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              exercise.name,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black87),
            onPressed: () {
              // TODO: Implementar compartir
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSessionSummary(context),
            const SizedBox(height: 16),
            _buildImprovementChart(context),
            const SizedBox(height: 16),
            _buildPerformanceBreakdown(context),
            const SizedBox(height: 16),
            _buildAchievements(context),
            const SizedBox(height: 16),
            _buildNextSteps(context),
            const SizedBox(height: 24),
            _buildActionButtons(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionSummary(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryAction,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '¡Excelente sesión!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sessionData.totalReps != null
                  ? 'Completaste ${sessionData.totalReps} repeticiones en ${_formatDuration(sessionData.durationSeconds)}'
                  : 'Mantuviste la posición por ${_formatDuration(sessionData.durationSeconds)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    sessionData.totalReps?.toString() ?? 
                        _formatDuration(sessionData.durationSeconds),
                    sessionData.totalReps != null ? 'Repeticiones' : 'Duración',
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    '${sessionData.metrics.techniquePercentage.toStringAsFixed(0)}%',
                    'Técnica',
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    _formatDuration(sessionData.durationSeconds),
                    'Tiempo',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryAction,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildImprovementChart(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: AppColors.primaryAction, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Mejora Semanal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Comparación con la semana anterior',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: 0.75,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF030213),
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+12%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[600],
                          ),
                        ),
                        Text(
                          'Mejora',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildComparisonRow(
              'Reps promedio semana anterior',
              '20.5',
              false,
            ),
            const SizedBox(height: 12),
            _buildComparisonRow(
              'Reps promedio esta semana',
              '23.2',
              false,
            ),
            const SizedBox(height: 12),
            _buildComparisonRow(
              'Sesión de hoy',
              sessionData.totalReps?.toString() ?? 
                  _formatDuration(sessionData.durationSeconds),
              true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String label, String value, bool highlight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            color: highlight ? Colors.green[600] : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceBreakdown(BuildContext context) {
    final performanceData = _getPerformanceData();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, color: AppColors.primaryAction, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Análisis de Rendimiento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...performanceData.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['name'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${(item['value'] as double).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (item['value'] as double) / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        item['color'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getPerformanceData() {
    final metrics = sessionData.metrics;
    final data = <Map<String, dynamic>>[];

    // Técnica - siempre presente
    data.add({
      'name': 'Técnica',
      'value': metrics.techniquePercentage,
      'color': Colors.green,
    });

    // Métricas específicas por ejercicio
    if (sessionData.exerciseType == 'pushup') {
      if (metrics.controlScore != null) {
        data.add({
          'name': 'Control',
          'value': metrics.controlScore!,
          'color': Colors.blue,
        });
      }
      if (metrics.stabilityScore != null) {
        data.add({
          'name': 'Estabilidad',
          'value': metrics.stabilityScore!,
          'color': Colors.orange,
        });
      }
    } else if (sessionData.exerciseType == 'squat') {
      if (metrics.depthScore != null) {
        data.add({
          'name': 'Profundidad',
          'value': metrics.depthScore!,
          'color': Colors.blue,
        });
      }
      if (metrics.alignmentScore != null) {
        data.add({
          'name': 'Alineación',
          'value': metrics.alignmentScore!,
          'color': Colors.orange,
        });
      }
      if (metrics.balanceScore != null) {
        data.add({
          'name': 'Balance',
          'value': metrics.balanceScore!,
          'color': Colors.purple,
        });
      }
    } else if (sessionData.exerciseType == 'plank') {
      if (metrics.hipScore != null) {
        data.add({
          'name': 'Posición Cadera',
          'value': metrics.hipScore!,
          'color': Colors.blue,
        });
      }
      if (metrics.coreScore != null) {
        data.add({
          'name': 'Core',
          'value': metrics.coreScore!,
          'color': Colors.orange,
        });
      }
      if (metrics.armPositionScore != null) {
        data.add({
          'name': 'Posición Brazos',
          'value': metrics.armPositionScore!,
          'color': Colors.purple,
        });
      }
      if (metrics.resistanceScore != null) {
        data.add({
          'name': 'Resistencia',
          'value': metrics.resistanceScore!,
          'color': Colors.red,
        });
      }
    }

    // Constancia - siempre presente
    data.add({
      'name': 'Constancia',
      'value': metrics.consistencyScore,
      'color': Colors.amber,
    });

    return data;
  }

  Widget _buildAchievements(BuildContext context) {
    final achievements = _getAchievements();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Logros Desbloqueados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...achievements.map((achievement) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAchievementItem(
                achievement['title'] as String,
                achievement['icon'] as String,
                achievement['unlocked'] as bool,
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getAchievements() {
    return [
      {
        'title': 'Nueva mejor marca personal',
        'icon': '🏆',
        'unlocked': sessionData.totalReps != null && sessionData.totalReps! > 12,
      },
      {
        'title': 'Técnica excelente',
        'icon': '⭐',
        'unlocked': sessionData.metrics.techniquePercentage > 85,
      },
      {
        'title': 'Constancia semanal',
        'icon': '🔥',
        'unlocked': true,
      },
    ];
  }

  Widget _buildAchievementItem(String title, String icon, bool unlocked) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? Colors.green[50] : Colors.grey[100],
        border: Border.all(
          color: unlocked ? Colors.green[200]! : Colors.grey[300]!,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: unlocked ? Colors.black87 : Colors.grey[600],
                  ),
                ),
                if (unlocked) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '¡Desbloqueado!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextSteps(BuildContext context) {
    final nextSteps = _getNextSteps();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Próximos Pasos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...nextSteps.map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildNextStepItem(
                step['title'] as String,
                step['description'] as String,
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _getNextSteps() {
    final reps = sessionData.totalReps ?? 0;
    return [
      {
        'title': 'Objetivo para mañana',
        'description': reps > 0
            ? 'Intenta alcanzar ${reps + 2} repeticiones'
            : 'Intenta mantener la posición por ${sessionData.durationSeconds + 10}s',
      },
      {
        'title': 'Área de mejora',
        'description': 'Enfócate en mantener un ritmo más constante',
      },
      {
        'title': 'Descanso recomendado',
        'description': '24 horas antes del próximo entrenamiento',
      },
    ];
  }

  Widget _buildNextStepItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryAction,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              // Navegar de vuelta a la pantalla principal
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAction,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Finalizar Sesión',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              // Navegar de vuelta a la pantalla de ejercicios
              Navigator.of(context).popUntil((route) => route.isFirst);
              // TODO: Navegar a la pantalla de selección de ejercicios
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryAction,
              side: BorderSide(color: AppColors.primaryAction),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Comenzar Otro Ejercicio',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
