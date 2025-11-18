import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fitracker_app/models/user_profile.dart';
import 'package:fitracker_app/data/auth_storage_service.dart';
import 'package:fitracker_app/config/api_config.dart';

class UserProfileService {
  final AuthStorageService _authStorage = AuthStorageService();

  /// Obtener perfil del usuario autenticado
  Future<UserProfile?> getUserProfile() async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('No access token found');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/users/profile';
      print('Fetching user profile from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      print('Profile response status: ${response.statusCode}');
      print('Profile response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          return UserProfile.fromJson(jsonResponse['data']);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Obtener estadísticas del usuario
  Future<UserStats?> getUserStats() async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('No access token found');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/users/profile/stats';
      print('Fetching user stats from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      print('Stats response status: ${response.statusCode}');
      print('Stats response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          return UserStats.fromJson(jsonResponse['data']);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching user stats: $e');
      return null;
    }
  }

  /// Obtener logros del usuario
  Future<List<Achievement>> getUserAchievements() async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('No access token found');
        return [];
      }

      final url = '${ApiConfig.apiBaseUrl}/users/profile/achievements';
      print('Fetching user achievements from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      print('Achievements response status: ${response.statusCode}');
      print('Achievements response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final List<dynamic> achievementsJson = jsonResponse['data'];
          return achievementsJson
              .map((json) => Achievement.fromJson(json))
              .toList();
        }
      }

      return [];
    } catch (e) {
      print('Error fetching user achievements: $e');
      return [];
    }
  }

  /// Actualizar perfil del usuario
  Future<UserProfile?> updateUserProfile(UpdateProfileRequest request) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null) {
        print('No access token found');
        return null;
      }

      final url = '${ApiConfig.apiBaseUrl}/users/profile';
      print('Updating user profile at: $url');
      print('Request body: ${jsonEncode(request.toJson())}');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      print('Update profile response status: ${response.statusCode}');
      print('Update profile response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          return UserProfile.fromJson(jsonResponse['data']);
        }
      }

      return null;
    } catch (e) {
      print('Error updating user profile: $e');
      return null;
    }
  }
}
