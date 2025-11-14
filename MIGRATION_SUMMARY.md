# Resumen de Migración: Google ML Kit → MediaPipe Pose Landmarker

## 🎯 Objetivo
Reemplazar Google ML Kit Pose Detection con MediaPipe Pose Landmarker nativo para mayor precisión en la detección de poses para ejercicios de plank.

---

## ✅ Archivos Modificados

### 1. **android/app/build.gradle.kts**
```kotlin
// Agregado:
dependencies {
    implementation("com.google.mediapipe:tasks-vision:0.10.14")
    implementation("androidx.camera:camera-core:1.3.1")
    implementation("androidx.camera:camera-camera2:1.3.1")
    implementation("androidx.camera:camera-lifecycle:1.3.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

android {
    defaultConfig {
        minSdk = 24  // MediaPipe requiere Android 7.0+
    }
}
```

### 2. **android/app/src/main/kotlin/.../MediaPipePosePlugin.kt** (NUEVO)
Plugin nativo de Platform Channel:
- Descarga automática de `pose_landmarker_lite.task` (~30MB) en primera ejecución
- Procesa imágenes YUV420 de la cámara
- Convierte resultados a formato Map para Dart
- Métodos: `initialize()`, `processImage()`, `dispose()`

### 3. **android/app/src/main/kotlin/.../MainActivity.kt**
```kotlin
// Agregado:
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.plugins.add(MediaPipePosePlugin())
}
```

### 4. **lib/services/mediapipe_pose_detector.dart** (NUEVO)
Wrapper Dart para Platform Channel:
- `MediaPipePoseDetector`: Clase principal
- `MediaPipePoseResult`: Resultado de detección
- `MediaPipePose`: Una pose con 33 landmarks
- `MediaPipeLandmark`: Coordenadas x, y, z, likelihood
- `MediaPipePoseLandmark`: Constantes de índices 0-32

### 5. **lib/screens/camera/pose_painter_mediapipe.dart** (NUEVO)
CustomPainter para visualización:
- Muestra 5 keypoints esenciales: leftShoulder, leftHip, leftAnkle, leftElbow, leftWrist
- Dibuja conexiones entre puntos
- Color según confianza: verde (≥0.8), amarillo (≥0.6), rojo (<0.6)
- Maneja flip de cámara frontal

### 6. **lib/screens/camera/camera_training_screen.dart** (MODIFICADO)
Cambios principales:

#### Imports
```dart
// ANTES:
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'pose_painter.dart';

// DESPUÉS:
import 'package:fitracker_app/services/mediapipe_pose_detector.dart';
import 'pose_painter_mediapipe.dart';
```

#### Variables de estado
```dart
// ANTES:
late final PoseDetector _poseDetector;
List<Pose> _poses = [];
InputImageRotation _imageRotation = InputImageRotation.rotation0deg;
final Map<PoseLandmarkType, List<double>> _smoothCache = {};

// DESPUÉS:
late final MediaPipePoseDetector _poseDetector;
List<MediaPipePose> _poses = [];
// InputImageRotation eliminado (no necesario)
final Map<int, List<double>> _smoothCache = {};
```

#### Inicialización
```dart
// ANTES:
_poseDetector = PoseDetector(options: PoseDetectorOptions());

// DESPUÉS:
_poseDetector = MediaPipePoseDetector();
await _poseDetector.initialize(
  minDetectionConfidence: 0.7,
  minTrackingConfidence: 0.7,
);
```

#### Procesamiento de imágenes
```dart
// ANTES:
final inputImage = _inputImageFromCameraImage(image);
final poses = await _poseDetector.processImage(inputImage);

// DESPUÉS:
final result = await _poseDetector.processImage(
  imageData: image.planes[0].bytes,
  width: image.width,
  height: image.height,
);
```

#### Suavizado de poses
```dart
// ANTES:
Map<PoseLandmarkType, PoseLandmark> _smoothPose(
    Map<PoseLandmarkType, PoseLandmark> currentLandmarks) { ... }

// DESPUÉS:
Map<int, MediaPipeLandmark> _smoothPose(
    Map<int, MediaPipeLandmark> currentLandmarks) { ... }
```

#### Extracción de keypoints
```dart
// ANTES:
final shoulderL = landmarks[PoseLandmarkType.leftShoulder];
final hipL = landmarks[PoseLandmarkType.leftHip];

// DESPUÉS:
final shoulderL = landmarks[MediaPipePoseLandmark.leftShoulder];
final hipL = landmarks[MediaPipePoseLandmark.leftHip];
```

#### CustomPaint
```dart
// ANTES:
CustomPaint(
  painter: PosePainter(
    poses: _poses,
    absoluteImageSize: _absoluteImageSize,
    rotation: _imageRotation,
    cameraLensDirection: _cameraController!.description.lensDirection,
    cameraDescription: _cameraController!.description,
  ),
)

// DESPUÉS:
CustomPaint(
  painter: PosePainterMediaPipe(
    poses: _poses,
    absoluteImageSize: _absoluteImageSize,
    cameraLensDirection: _cameraController!.description.lensDirection,
  ),
)
```

#### Dispose
```dart
// ANTES:
_poseDetector.close();

// DESPUÉS:
_poseDetector.dispose();
```

---

## 📊 Comparación: ML Kit vs MediaPipe

| Característica | Google ML Kit | MediaPipe |
|----------------|---------------|-----------|
| **Landmarks** | 33 puntos | 33 puntos (misma estructura) |
| **Precisión** | Buena | Mejor (modelo más reciente) |
| **Plataforma** | iOS + Android | Solo Android (por ahora) |
| **Modelo** | Interno (incluido) | Externa (~30MB, descarga automática) |
| **Requisitos** | API 19+ | API 24+ (Android 7.0+) |
| **Configuración** | Simple | Platform Channel + Plugin nativo |
| **Confianza** | Por landmark | Global + por landmark |
| **Mantenimiento** | Google (activo) | Google MediaPipe (activo) |

---

## 🚀 Ventajas de MediaPipe

1. **Mayor precisión**: Modelo más reciente y optimizado
2. **Más opciones**: Parámetros de detección y tracking configurables
3. **Mejor tracking**: Seguimiento de poses entre frames
4. **z-coordinate**: Coordenada de profundidad más precisa
5. **Likelihood individual**: Confianza por cada landmark

---

## ⚠️ Limitaciones Actuales

- **Solo Android**: iOS no implementado (pendiente)
- **Descarga inicial**: Modelo ~30MB se descarga en primera ejecución
- **API mínima**: Requiere Android 7.0+ (API 24)
- **No emulador**: Requiere dispositivo físico para pruebas

---

## 🧪 Testing

### Para probar en Android:
```bash
# Conectar dispositivo Android (API 24+)
flutter clean
flutter pub get
flutter run
```

### Logs importantes a observar:
```
🔽 Descargando modelo MediaPipe...
✅ Modelo descargado exitosamente
🎯 MediaPipe inicializado: minDetection=0.7, minTracking=0.7
👤 Pose detectada: 33 landmarks
🔢 Features calculados (primeros 5): [...]
📤 FEATURES ENVIADOS: 25 valores
```

---

## 📝 Archivos que NO se modificaron

- `pubspec.yaml`: Sin nuevas dependencias Dart (solo Kotlin nativo)
- WebSocket client: Sigue igual
- Cálculo de features: Sigue igual (5 features × 5 stats = 25 valores)
- Buffer logic: Sigue igual (15 frames, clear después de envío)
- Sensitivity factors: Siguen iguales

---

## 🎯 Próximos Pasos

1. ✅ Migración completa a MediaPipe
2. **🔜 Testing en dispositivo físico Android**
3. Validar precisión vs ML Kit
4. Ajustar parámetros si es necesario
5. (Opcional) Implementar soporte iOS

---

## 🔧 Troubleshooting

### Problema: Modelo no descarga
```bash
# Verificar permisos de internet en AndroidManifest.xml
<uses-permission android:name="android.permission.INTERNET" />
```

### Problema: No detecta poses
```bash
# Verificar logs de inicialización
flutter logs | grep -i mediapipe
```

### Problema: Crashes en Android
```bash
# Verificar minSdk en build.gradle
minSdk = 24  // No menor a 24
```

---

## 📚 Referencias

- [MediaPipe Pose Landmarker](https://developers.google.com/mediapipe/solutions/vision/pose_landmarker)
- [MediaPipe Tasks Vision (Android)](https://developers.google.com/mediapipe/solutions/vision/pose_landmarker/android)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)

---

## ✨ Estado Final

✅ **Compilación**: 0 errores  
✅ **Código migrado**: 100%  
✅ **Listo para testing**: Sí  
📱 **Plataforma**: Android únicamente  
🎯 **Siguiente**: Probar en dispositivo físico
