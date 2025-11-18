import 'dart:convert';
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:fitracker_app/api/api_service.dart';
import 'package:fitracker_app/api/authenticated_http_client.dart';
import 'package:fitracker_app/config/api_config.dart';

class ExerciseService {
  final AuthenticatedHttpClient _httpClient = AuthenticatedHttpClient();

  /// Obtiene la lista de ejercicios con manejo automático de refresh token
  Future<List<ExerciseDto>> getExercises() async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/exercises');
    
    try {
      final headers = await _httpClient.getAuthHeaders();
      final response = await _httpClient.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> exercisesJson = jsonDecode(response.body);
        return exercisesJson.map((json) => ExerciseDto.fromJson(json)).toList();
      } else {
        throw ApiException('Error al obtener los ejercicios.', statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Error de red al obtener los ejercicios.');
    }
  }
}