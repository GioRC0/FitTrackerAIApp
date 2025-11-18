import 'package:flutter/material.dart';
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:fitracker_app/models/progress_dashboard.dart';
import 'package:fitracker_app/services/training_session_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ProgressDashboardScreen extends StatefulWidget {
  final ExerciseDto exercise;

  const ProgressDashboardScreen({super.key, required this.exercise});

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TrainingSessionService _sessionService = TrainingSessionService();
  
  String _timeRange = 'week';
  bool _isLoading = true;
  String? _errorMessage;
  
  ProgressData? _progressData;
  FormAnalysis? _formAnalysis;
  Goals? _goals;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _sessionService.getProgressData(widget.exercise.id, range: _timeRange),
        _sessionService.getFormAnalysis(widget.exercise.id, range: _timeRange),
        _sessionService.getGoals(widget.exercise.id),
      ]);

      if (mounted) {
        setState(() {
          _progressData = results[0] as ProgressData?;
          _formAnalysis = results[1] as FormAnalysis?;
          _goals = results[2] as Goals?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos del dashboard';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeTimeRange(String newRange) async {
    if (newRange == _timeRange) return;
    
    setState(() {
      _timeRange = newRange;
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _sessionService.getProgressData(widget.exercise.id, range: _timeRange),
        _sessionService.getFormAnalysis(widget.exercise.id, range: _timeRange),
      ]);

      if (mounted) {
        setState(() {
          _progressData = results[0] as ProgressData?;
          _formAnalysis = results[1] as FormAnalysis?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cambiar el período';
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
            Text('Progreso - ${widget.exercise.name}'),
            const Text(
              'Dashboard detallado',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Progreso'),
            Tab(text: 'Técnica'),
            Tab(text: 'Logros'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProgressTab(),
                    _buildFormTab(),
                    _buildAchievementsTab(),
                  ],
                ),
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
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ==================== PROGRESS TAB ====================
  Widget _buildProgressTab() {
    if (_progressData == null) {
      return Center(
        child: Text('No hay datos disponibles', style: TextStyle(color: Colors.grey[600])),
      );
    }

    final data = _progressData!;
    final summary = data.summary;
    final isPlank = data.isPlank;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Range Selector
          Row(
            children: [
              _buildTimeRangeButton('Semana', 'week'),
              const SizedBox(width: 8),
              _buildTimeRangeButton('Mes', 'month'),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatsCard(
                  context,
                  Icons.track_changes,
                  isPlank ? 'Total tiempo' : 'Total esta semana',
                  isPlank ? '${summary.totalSeconds}s' : '${summary.totalReps}',
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatsCard(
                  context,
                  Icons.trending_up,
                  'Mejora',
                  '${summary.improvement >= 0 ? '+' : ''}${summary.improvement.toStringAsFixed(1)}%',
                  summary.improvement >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isPlank ? 'Segundos' : 'Repeticiones'} por ${_timeRange == 'week' ? 'día' : 'semana'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildLineChart(data.dataPoints, isPlank),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Weekly Overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen Semanal',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow(
                    'Días entrenados',
                    '${summary.daysWithActivity}/${_timeRange == 'week' ? '7' : '30'}',
                  ),
                  _buildSummaryRow(
                    'Promedio diario',
                    '${summary.averagePerDay.toStringAsFixed(1)} ${isPlank ? 'seg' : 'reps'}',
                  ),
                  _buildSummaryRow(
                    'Mejor día',
                    '${summary.bestDay.label} (${summary.bestDay.value} ${isPlank ? 'seg' : 'reps'})',
                  ),
                  _buildSummaryRow(
                    'Consistencia',
                    summary.consistency,
                    valueColor: _getConsistencyColor(summary.consistency),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String label, String range) {
    final isSelected = _timeRange == range;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _changeTimeRange(range),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey[300],
          foregroundColor: isSelected ? Colors.white : Colors.black87,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, IconData icon, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<ProgressDataPoint> dataPoints, bool isPlank) {
    if (dataPoints.isEmpty) {
      return Center(child: Text('No hay datos para mostrar', style: TextStyle(color: Colors.grey[600])));
    }

    final spots = dataPoints.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      final yValue = isPlank ? point.seconds.toDouble() : point.reps.toDouble();
      return FlSpot(index.toDouble(), yValue);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: isPlank ? 10 : 5,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < dataPoints.length) {
                  return Text(
                    dataPoints[index].label,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[300]!)),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Theme.of(context).primaryColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Color _getConsistencyColor(String consistency) {
    switch (consistency.toLowerCase()) {
      case 'excelente':
        return Colors.green;
      case 'buena':
        return Colors.blue;
      case 'regular':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  // ==================== FORM TAB ====================
  Widget _buildFormTab() {
    if (_formAnalysis == null) {
      return Center(
        child: Text('No hay datos disponibles', style: TextStyle(color: Colors.grey[600])),
      );
    }

    final analysis = _formAnalysis!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Average Score
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Puntuación de Técnica',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analysis.averageScore.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    'Puntuación promedio esta ${_timeRange == 'week' ? 'semana' : 'mes'}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildBarChart(analysis.aspectScores),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Feedback (Hardcoded)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Retroalimentación',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildFeedbackItem(
                    Colors.green,
                    'Excelente postura',
                    'Mantén la espalda recta consistentemente',
                  ),
                  const SizedBox(height: 12),
                  _buildFeedbackItem(
                    Colors.yellow,
                    'Mejora la velocidad',
                    'Trata de mantener un ritmo más constante',
                  ),
                  const SizedBox(height: 12),
                  _buildFeedbackItem(
                    Colors.blue,
                    'Buen rango de movimiento',
                    'Completas el movimiento correctamente',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<AspectScore> aspectScores) {
    if (aspectScores.isEmpty) {
      return Center(child: Text('No hay datos para mostrar', style: TextStyle(color: Colors.grey[600])));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < aspectScores.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      aspectScores[index].aspect,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[300]!)),
        barGroups: aspectScores.asMap().entries.map((entry) {
          final index = entry.key;
          final score = entry.value.score;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: score,
                color: Theme.of(context).primaryColor,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeedbackItem(Color color, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color.lerp(color, Colors.black, 0.4)!,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color.lerp(color, Colors.black, 0.3)!,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACHIEVEMENTS TAB ====================
  Widget _buildAchievementsTab() {
    if (_goals == null) {
      return Center(
        child: Text('No hay datos disponibles', style: TextStyle(color: Colors.grey[600])),
      );
    }

    final goals = _goals!;

    // Hardcoded achievements
    final achievements = [
      {'title': 'Primera semana completada', 'date': DateTime.now().subtract(const Duration(days: 7)), 'icon': '🎯'},
      {'title': 'Mejor forma de la semana', 'date': DateTime.now().subtract(const Duration(days: 2)), 'icon': '⭐'},
      {'title': '100 repeticiones totales', 'date': DateTime.now().subtract(const Duration(days: 1)), 'icon': '💯'},
      {'title': 'Racha de ${goals.currentStreak} días', 'date': DateTime.now(), 'icon': '🔥'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Achievements
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Logros Desbloqueados',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tus logros recientes en ${widget.exercise.name}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ...achievements.map((achievement) {
                    return _buildAchievementItem(
                      achievement['icon'] as String,
                      achievement['title'] as String,
                      achievement['date'] as DateTime,
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Next Goals
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Próximos Objetivos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...goals.goals.map((goal) {
                    return _buildGoalItem(goal);
                  }).toList(),
                ],
              ),
            ),
          ),

          // Streaks Info
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              '${goals.currentStreak}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Racha actual',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(Icons.military_tech, color: Colors.amber, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              '${goals.longestStreak}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Mejor racha',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(String icon, String title, DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    DateFormat('d MMM y', 'es_ES').format(date),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(Goal goal) {
    final progressPercent = (goal.progress / 100).clamp(0.0, 1.0);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${goal.current}/${goal.target} ${goal.description.split(' ').last}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressPercent,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        goal.achieved ? Colors.green : Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (goal.achieved)
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
          ],
        ),
      ),
    );
  }
}
