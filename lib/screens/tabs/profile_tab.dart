import 'package:flutter/material.dart';
import 'package:fitracker_app/models/user_profile.dart';
import 'package:fitracker_app/services/user_profile_service.dart';
import 'package:fitracker_app/data/auth_storage_service.dart';
import 'package:fitracker_app/screens/splash_screen.dart';
import 'package:fitracker_app/screens/profile/edit_profile_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final UserProfileService _profileService = UserProfileService();
  final AuthStorageService _authStorage = AuthStorageService();

  UserProfile? _profile;
  UserStats? _stats;
  List<Achievement> _achievements = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _profileService.getUserProfile();
      final stats = await _profileService.getUserStats();
      final achievements = await _profileService.getUserAchievements();

      if (mounted) {
        setState(() {
          _profile = profile;
          _stats = stats;
          _achievements = achievements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar el perfil';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await _authStorage.clearSession();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _navigateToEditProfile() async {
    if (_profile == null) return;

    final updatedProfile = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(profile: _profile!),
      ),
    );

    if (updatedProfile != null) {
      setState(() {
        _profile = updatedProfile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || _profile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Error al cargar el perfil'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProfileData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            _buildProfileHeader(),
            const SizedBox(height: 16),

            // Stats
            if (_stats != null) ...[
              _buildStatsCard(),
              const SizedBox(height: 16),
            ],

            // Achievements
            _buildAchievementsCard(),
            const SizedBox(height: 16),

            // Settings & Actions
            _buildActionsSection(),
            const SizedBox(height: 16),

            // App Info
            _buildAppInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 32,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
              child: Text(
                _profile!.initials,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profile!.fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _profile!.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${_profile!.weight.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_profile!.height} cm',
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
            
            // Edit Button
            IconButton(
              onPressed: _navigateToEditProfile,
              icon: const Icon(Icons.edit_outlined),
              style: IconButton.styleFrom(
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final statItems = [
      {'label': 'Días activos', 'value': _stats!.activeDays.toString(), 'icon': Icons.calendar_today},
      {'label': 'Ejercicios dominados', 'value': _stats!.masteredExercises.toString(), 'icon': Icons.emoji_events},
      {'label': 'Objetivos cumplidos', 'value': _stats!.completedGoals.toString(), 'icon': Icons.flag},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadísticas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: statItems.map((stat) {
                return Expanded(
                  child: Column(
                    children: [
                      Icon(
                        stat['icon'] as IconData,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stat['value'] as String,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Logros',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Desbloquea logros completando ejercicios',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            if (_achievements.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No hay logros disponibles',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _achievements.length,
                itemBuilder: (context, index) {
                  final achievement = _achievements[index];
                  return _buildAchievementItem(achievement);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementItem(Achievement achievement) {
    final isEarned = achievement.earned;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEarned
            ? Theme.of(context).primaryColor.withOpacity(0.05)
            : Colors.grey[100],
        border: Border.all(
          color: isEarned
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            achievement.icon,
            style: TextStyle(
              fontSize: 32,
              color: isEarned ? null : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isEarned ? Colors.black : Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (isEarned) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Desbloqueado',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Implementar configuración
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Configuración próximamente')),
            );
          },
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Configuración'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            alignment: Alignment.centerLeft,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Implementar ver todos los logros
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ver todos los logros próximamente')),
            );
          },
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('Ver todos los logros'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            alignment: Alignment.centerLeft,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar Sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            minimumSize: const Size(double.infinity, 48),
            alignment: Alignment.centerLeft,
          ),
        ),
      ],
    );
  }

  Widget _buildAppInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'FitTracker AI v1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Monitoreo inteligente de ejercicios',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
