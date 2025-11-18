import 'package:flutter/material.dart';
import 'package:fitracker_app/models/home_dashboard.dart';
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:fitracker_app/services/training_session_service.dart';
import 'package:fitracker_app/screens/exercise/exercise_detail_screen.dart';
import 'package:intl/intl.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToTraining;
  
  const HomeTab({super.key, this.onNavigateToTraining});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TrainingSessionService _sessionService = TrainingSessionService();
  HomeDashboard? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dashboard = await _sessionService.getHomeDashboard();
      
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar el dashboard';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToExercise(String exerciseId, String exerciseName, String exerciseType) {
    // Crear un ExerciseDto temporal para navegar al detalle del ejercicio
    final exercise = ExerciseDto(
      id: exerciseId,
      name: exerciseName,
      shortDescription: '',
      fullDescription: '',
      difficulty: '',
      muscleGroup: '',
      minTime: 0,
      maxTime: 0,
      steps: [],
      tips: [],
      imageUrl: '',
      shortImageUrl: '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseDetailScreen(exercise: exercise),
      ),
    ).then((_) => _loadDashboard()); // Recargar al volver
  }

  void _navigateToTrainingTab() {
    // Cambiar al tab de entrenamiento (índice 1)
    widget.onNavigateToTraining?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_dashboard == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No hay datos disponibles'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _navigateToTrainingTab,
              child: const Text('Comenzar a entrenar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),

            // Continue Last Exercise
            if (_dashboard!.lastExercise != null) ...[
              _buildContinueLastExerciseCard(),
              const SizedBox(height: 24),
            ],

            // Stats Cards
            _buildStatsCards(),
            const SizedBox(height: 24),

            // Recent Activity
            _buildRecentActivityCard(),
            const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.fitness_center,
                color: Theme.of(context).primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FitSmart',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Entrenamiento inteligente',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          '¡Hola, ${_dashboard!.user.name}!',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Aquí está tu actividad reciente',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildContinueLastExerciseCard() {
    final lastExercise = _dashboard!.lastExercise!;
    final displayValue = lastExercise.isPlank
        ? '${lastExercise.seconds}'
        : '${lastExercise.reps}';
    final displayUnit = lastExercise.isPlank ? 'seg' : 'reps';

    return Card(
      color: Theme.of(context).primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToExercise(
          lastExercise.exerciseId,
          lastExercise.exerciseName,
          lastExercise.exerciseType,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continuar ${lastExercise.exerciseName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          displayValue,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayUnit,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _navigateToExercise(
                        lastExercise.exerciseId,
                        lastExercise.exerciseName,
                        lastExercise.exerciseType,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Continuar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              if (lastExercise.imageUrl != null) ...[
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    lastExercise.imageUrl!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: Colors.white,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = _dashboard!.stats;
    final lastExercise = _dashboard!.lastExercise;
    final isPlank = lastExercise?.isPlank ?? false;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            stats.weeklyWorkouts.toString(),
            'Esta semana',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            (stats.weeklyTotalReps + stats.weeklyTotalSeconds).toString(),
            isPlank ? 'Total segundos' : 'Total reps',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            stats.bestStreak.toString(),
            'Mejor racha',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final recentActivity = _dashboard!.recentActivity;

    if (recentActivity.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.fitness_center_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No hay actividad reciente',
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
            Row(
              children: [
                Icon(Icons.show_chart, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Actividad Reciente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recentActivity.map((activity) {
              return _buildActivityItem(activity);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(RecentExercise activity) {
    final displayValue = activity.isPlank
        ? '${activity.seconds} seg'
        : '${activity.reps} reps';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => _navigateToExercise(
          activity.exerciseId,
          activity.exerciseName,
          activity.exerciseType,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.exerciseName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('d MMM y', 'es_ES').format(activity.date),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          activity.duration,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    displayValue,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 12,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activity.improvement,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
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
    );
  }

  Widget _buildQuickActionsCard() {
    final lastExercise = _dashboard!.lastExercise;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acciones Rápidas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (lastExercise != null)
              OutlinedButton.icon(
                onPressed: () => _navigateToExercise(
                  lastExercise.exerciseId,
                  lastExercise.exerciseName,
                  lastExercise.exerciseType,
                ),
                icon: const Icon(Icons.fitness_center),
                label: const Text('Continuar último ejercicio'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  alignment: Alignment.centerLeft,
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _navigateToTrainingTab(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Comenzar nuevo ejercicio'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
