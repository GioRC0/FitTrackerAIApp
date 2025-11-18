# Training Session Service - Guía de Uso

Este documento explica cómo usar el `TrainingSessionService` para interactuar con la API de C#.

## Endpoints Disponibles

### 1. Crear Sesión de Entrenamiento
```dart
final response = await _sessionService.saveTrainingSession(sessionData);

if (response != null) {
  print('Sesión guardada con ID: ${response.id}');
  print('Usuario: ${response.userId}');
  print('Creada en: ${response.createdAt}');
}
```

**Endpoint:** `POST /api/trainingSessions`  
**Autenticación:** Bearer Token (JWT)  
**Body:** TrainingSessionCreateDto (PascalCase)  
**Response:** `{ "message": "...", "data": TrainingSessionResponseDto }`

### 2. Obtener Sesión por ID
```dart
final session = await _sessionService.getSessionById('session_id_here');

if (session != null) {
  print('Ejercicio: ${session.exerciseName}');
  print('Técnica: ${session.metrics.techniquePercentage}%');
  print('Reps: ${session.totalReps}');
}
```

**Endpoint:** `GET /api/trainingSessions/{id}`  
**Autenticación:** Bearer Token (JWT)  
**Response:** `{ "data": TrainingSessionResponseDto }`

### 3. Listar Sesiones del Usuario
```dart
final sessions = await _sessionService.getUserSessions(
  page: 1,
  pageSize: 10,
  exerciseId: 'exercise_id_optional',
);

for (var session in sessions) {
  print('${session.exerciseName}: ${session.totalReps} reps');
}
```

**Endpoint:** `GET /api/trainingSessions?page=1&pageSize=10&exerciseId=xxx`  
**Autenticación:** Bearer Token (JWT)  
**Response:** `{ "data": [TrainingSessionResponseDto], "pagination": {...} }`

### 4. Obtener Progreso Semanal
```dart
final progress = await _sessionService.getWeeklyProgress('exercise_id');

if (progress != null) {
  print('Ejercicio: ${progress.exerciseName}');
  print('Sesiones esta semana: ${progress.currentWeek.totalSessions}');
  print('Sesiones semana pasada: ${progress.previousWeek.totalSessions}');
  print('Cambio en técnica: ${progress.comparison.techniqueChange}%');
}
```

**Endpoint:** `GET /api/trainingSessions/weekly-progress/{exerciseId}`  
**Autenticación:** Bearer Token (JWT)  
**Response:** `{ "data": WeeklyProgressDto }`

## Modelos de Datos

### TrainingSessionData (Request - para enviar)
```dart
final sessionData = TrainingSessionData(
  exerciseId: widget.exercise.id,
  exerciseType: 'pushup', // 'pushup', 'squat', 'plank'
  exerciseName: 'Push-ups',
  startTime: DateTime.now(),
  endTime: DateTime.now(),
  durationSeconds: 120,
  totalReps: 15, // Solo para pushup/squat
  repsData: [...], // Lista de RepData
  totalSeconds: null, // Solo para plank
  secondsData: null, // Solo para plank
  metrics: PerformanceMetrics(...),
);
```

### TrainingSessionResponse (Response - lo que devuelve el servidor)
```dart
class TrainingSessionResponse {
  String id;                // ID de la sesión en MongoDB
  String userId;            // ID del usuario
  String exerciseId;        // ID del ejercicio
  String exerciseType;      // 'pushup', 'squat', 'plank'
  String exerciseName;      // Nombre del ejercicio
  DateTime startTime;       // Inicio
  DateTime endTime;         // Fin
  int durationSeconds;      // Duración total
  int totalReps;            // Total de repeticiones
  List<RepData>? repsData;  // Datos de cada rep
  int totalSeconds;         // Total de segundos (plank)
  List<SecondData>? secondsData; // Datos por segundo (plank)
  PerformanceMetrics metrics; // Métricas calculadas
  DateTime createdAt;       // Timestamp de creación en BD
}
```

### WeeklyProgress (Response)
```dart
class WeeklyProgress {
  String exerciseId;
  String exerciseName;
  WeekStats currentWeek;    // Estadísticas semana actual
  WeekStats previousWeek;   // Estadísticas semana anterior
  ProgressComparison comparison; // Comparación % de cambio
}

class WeekStats {
  int totalSessions;        // Total de sesiones
  int totalReps;            // Total de reps
  int totalSeconds;         // Total de segundos
  double averageTechniquePercentage;
  double averageConsistencyScore;
  double averageConfidence;
}

class ProgressComparison {
  double sessionsChange;    // % cambio en sesiones
  double repsChange;        // % cambio en reps
  double secondsChange;     // % cambio en segundos
  double techniqueChange;   // % cambio en técnica
  double consistencyChange; // % cambio en consistencia
  double confidenceChange;  // % cambio en confianza
}
```

## Formato JSON

### Request (PascalCase - C# Style)
```json
{
  "ExerciseId": "675c1234...",
  "ExerciseType": "pushup",
  "ExerciseName": "Push-ups",
  "StartTime": "2025-11-17T10:30:00Z",
  "EndTime": "2025-11-17T10:32:00Z",
  "DurationSeconds": 120,
  "TotalReps": 15,
  "RepsData": [
    {
      "RepNumber": 1,
      "Classification": "pushup_correcto",
      "Confidence": 0.95,
      "Probabilities": {
        "pushup_correcto": 0.95,
        "pushup_codos_abiertos": 0.03,
        "pushup_espalda_arqueada": 0.02
      },
      "Timestamp": "2025-11-17T10:30:15Z"
    }
  ],
  "Metrics": {
    "TechniquePercentage": 85.5,
    "ConsistencyScore": 92.3,
    "AverageConfidence": 0.87,
    "ControlScore": 88.5,
    "StabilityScore": 91.2,
    "RepsPerMinute": 7.5
  }
}
```

### Response (PascalCase - C# Style)
```json
{
  "message": "Sesión de entrenamiento creada exitosamente",
  "data": {
    "Id": "mongo_object_id_here",
    "UserId": "user_id_here",
    "ExerciseId": "675c1234...",
    "ExerciseType": "pushup",
    "ExerciseName": "Push-ups",
    "StartTime": "2025-11-17T10:30:00Z",
    "EndTime": "2025-11-17T10:32:00Z",
    "DurationSeconds": 120,
    "TotalReps": 15,
    "RepsData": [...],
    "TotalSeconds": 0,
    "SecondsData": null,
    "Metrics": {...},
    "CreatedAt": "2025-11-17T10:32:05Z"
  }
}
```

## Manejo de Errores

```dart
try {
  final response = await _sessionService.saveTrainingSession(sessionData);
  
  if (response != null) {
    // Éxito
    print('✅ Sesión guardada: ${response.id}');
  } else {
    // Error (401, 403, 500, etc.)
    print('❌ Error al guardar sesión');
    // Mostrar mensaje al usuario
  }
} catch (e) {
  // Excepción de red o parsing
  print('❌ Excepción: $e');
  // Mostrar mensaje de error de conexión
}
```

## Logs de Debug

El servicio imprime logs detallados:

```
📤 Enviando sesión a: http://192.168.18.174:5180/api/trainingSessions
📦 Datos: {...}
📥 Status Code: 201
📥 Response Body: {...}
✅ Sesión guardada exitosamente con ID: 675c12345...
```

Revisar la consola para diagnosticar problemas con la API.

## Autenticación

El servicio usa `AuthStorageService` automáticamente:
- Obtiene el access token del almacenamiento seguro
- Agrega el header: `Authorization: Bearer {token}`
- Si no hay token, retorna `null` inmediatamente

Asegúrate de que el usuario esté autenticado antes de llamar estos métodos.
