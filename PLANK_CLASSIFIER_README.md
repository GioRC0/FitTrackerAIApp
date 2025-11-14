# Instrucciones de Configuración del Clasificador de Plank

## ✅ Implementación Completada

Se ha implementado exitosamente el clasificador de Plank en tiempo real en tu app Flutter, replicando exactamente la funcionalidad de `real_time_feedback.py`.

---

## 📋 Pasos Finales para Ejecutar

### 1. Instalar Dependencias
Ejecuta en la terminal:
```bash
flutter pub get
```

### 2. Copiar el Modelo TFLite
Copia tu archivo `plank_classifier_model.tflite` a la carpeta:
```
fitracker_app/assets/models/plank_classifier_model.tflite
```

**IMPORTANTE**: Verifica que el modelo tenga:
- **Input shape**: `[1, 25]` (5 features × 5 estadísticas)
- **Output shape**: `[1, 4]` (4 clases)

### 3. Verificar el Orden de las Clases
En `lib/services/plank_classifier_service.dart`, línea 34-39, verifica que el orden de las clases coincida EXACTAMENTE con tu LabelEncoder:

```dart
final List<String> _classes = [
  'plank_cadera_caida',
  'plank_codos_abiertos',
  'plank_correcto',
  'plank_pelvis_levantada',
];
```

Para verificar el orden correcto, ejecuta en Python:
```python
import joblib
le = joblib.load('plank_label_encoder_tflow.pkl')
print(le.classes_)
```

---

## 🎯 Funcionalidades Implementadas

### ✅ Detección de Pose con Google ML Kit
- Usa los mismos 33 landmarks que MediaPipe
- Optimizado para dispositivos móviles
- Funciona en Android e iOS

### ✅ Cálculo de Features (PoseUtils)
- `calculateAngle()`: Calcula ángulos entre 3 puntos
- `extractPlankFeatures()`: Extrae las 5 features del frame
- `calculateAggregatedFeatures()`: Calcula mean, std, min, max, range

### ✅ Clasificador TFLite (PlankClassifierService)
- Buffer de 30 frames (1 segundo)
- Predicción cada segundo
- Ajuste de sensibilidades por clase
- Normalización de probabilidades

### ✅ UI de Feedback en Tiempo Real
- Panel con estado actual (verde=correcto, rojo=incorrecto)
- Porcentaje de confianza
- Barra de progreso del buffer
- Desglose de probabilidades de todas las clases

---

## 📊 Flujo de Datos

```
Camera Frame
    ↓
Google ML Kit Pose Detection (33 landmarks)
    ↓
PoseUtils.extractPlankFeatures() (5 features)
    ↓
Buffer de 30 frames
    ↓
PoseUtils.calculateAggregatedFeatures() (25 features)
    ↓
TFLite Model (4 probabilidades)
    ↓
Ajuste de sensibilidades
    ↓
UI Feedback
```

---

## 🔧 Configuración de Sensibilidades

Puedes ajustar las sensibilidades en `plank_classifier_service.dart`:

```dart
final Map<String, double> _classSensitivity = {
  'plank_cadera_caida': 1.0,
  'plank_codos_abiertos': 0.5,    // Menos sensible
  'plank_correcto': 1.3,            // Más sensible
  'plank_pelvis_levantada': 1.0,
};
```

---

## 🚀 Cómo Probar

1. Ejecuta la app: `flutter run`
2. Navega a "Entrenamiento"
3. Selecciona un ejercicio
4. Ve a "Pre-entrenamiento"
5. Toca "Comenzar Entrenamiento"
6. La cámara se abrirá y verás:
   - Esqueleto en tiempo real
   - Panel de feedback arriba
   - Estado de tu plank
   - Confianza de la predicción

---

## 📝 Diferencias con el Código Python

| Aspecto | Python | Flutter (Implementado) |
|---------|--------|------------------------|
| Detección de Pose | MediaPipe | Google ML Kit (mismo modelo) |
| Modelo ML | Scikit-Learn (.pkl) | TensorFlow Lite (.tflite) |
| Buffer | 30 frames | 30 frames ✅ |
| Features | 5 básicas → 25 agregadas | Idéntico ✅ |
| Sensibilidades | Ajustables | Idéntico ✅ |
| UI Feedback | OpenCV | Flutter Widgets ✅ |

---

## 🐛 Troubleshooting

### Error: "No se pudo cargar el modelo"
- Verifica que `plank_classifier_model.tflite` esté en `assets/models/`
- Ejecuta `flutter clean && flutter pub get`

### Predicciones incorrectas
- Verifica el orden de las clases en `_classes`
- Asegúrate de que el modelo TFLite incluya la normalización (StandardScaler)

### App lenta
- Reduce `bufferFrameSize` de 30 a 20 frames
- Cambia `ResolutionPreset.medium` a `low`

---

## 🎓 Próximos Pasos

Para implementar otros ejercicios (sentadillas, flexiones):

1. Entrena un modelo nuevo con tu script de TensorFlow
2. Exporta a `.tflite`
3. Crea un nuevo servicio: `SquatClassifierService`, `PushupClassifierService`
4. Define las features específicas en `PoseUtils`
5. Integra en `CameraTrainingScreen`

¿Necesitas ayuda con esto? ¡Avísame!

---

## 📦 Archivos Creados

- ✅ `lib/utils/pose_utils.dart` - Cálculos de ángulos y features
- ✅ `lib/services/plank_classifier_service.dart` - Clasificador TFLite
- ✅ `lib/screens/camera/camera_training_screen.dart` - Integración completa
- ✅ `assets/models/` - Carpeta para modelo (copia tu .tflite aquí)
- ✅ `pubspec.yaml` - Dependencia tflite_flutter agregada

---

**¡Listo para probar! 🚀**
