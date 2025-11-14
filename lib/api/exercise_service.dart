import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fitracker_app/models/exercises_dtos.dart';
import 'package:fitracker_app/data/auth_storage_service.dart';
import 'package:fitracker_app/api/api_service.dart'; // Para usar ApiException

class ExerciseService {
  // La URL base de tu API, sin el /auth
  final String _baseUrl = 'http://10.0.2.2:5180/api'; 
  final AuthStorageService _storageService = AuthStorageService();

  // Endpoint para obtener la lista de ejercicios
  Future<List<ExerciseDto>> getExercises() async {
    final token = await _storageService.getAccessToken();
    if (token == null) {
      throw ApiException('No se encontró token de autenticación. Inicia sesión de nuevo.');
    }

    final url = Uri.parse('$_baseUrl/exercises');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> exercisesJson = jsonDecode(response.body);
        return exercisesJson.map((json) => ExerciseDto.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        // TODO: Implementar la lógica para refrescar el token aquí o en un interceptor
        throw ApiException('Token expirado o inválido.', statusCode: response.statusCode);
      } else {
        throw ApiException('Error al obtener los ejercicios.', statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw ApiException('Error de red al obtener los ejercicios.');
      }
      rethrow;
    }
  }
}