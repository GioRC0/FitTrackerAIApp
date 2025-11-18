import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fitracker_app/services/mediapipe_pose_detector.dart';

class PosePainterMediaPipe extends CustomPainter {
  final List<MediaPipePose> poses;
  final Size absoluteImageSize;
  final CameraLensDirection cameraLensDirection;

  PosePainterMediaPipe({
    required this.poses,
    required this.absoluteImageSize,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;

    final pose = poses.first;

    // Dibujar todas las conexiones del esqueleto
    _drawAllConnections(canvas, size, pose);
    
    // Dibujar todos los landmarks principales
    _drawAllLandmarks(canvas, size, pose);
  }
  
  void _drawAllLandmarks(Canvas canvas, Size size, MediaPipePose pose) {
    // Landmarks principales del cuerpo
    final mainLandmarks = [
      // Cara
      MediaPipePoseLandmark.nose,
      // Hombros
      MediaPipePoseLandmark.leftShoulder,
      MediaPipePoseLandmark.rightShoulder,
      // Codos
      MediaPipePoseLandmark.leftElbow,
      MediaPipePoseLandmark.rightElbow,
      // Muñecas
      MediaPipePoseLandmark.leftWrist,
      MediaPipePoseLandmark.rightWrist,
      // Caderas
      MediaPipePoseLandmark.leftHip,
      MediaPipePoseLandmark.rightHip,
      // Rodillas
      MediaPipePoseLandmark.leftKnee,
      MediaPipePoseLandmark.rightKnee,
      // Tobillos
      MediaPipePoseLandmark.leftAnkle,
      MediaPipePoseLandmark.rightAnkle,
    ];

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4.0;

    for (final landmarkIndex in mainLandmarks) {
      final landmark = pose.getLandmark(landmarkIndex);
      if (landmark == null) continue;

      final point = _translatePoint(landmark.x, landmark.y, size);

      // Solo dibujar si tiene buena confianza
      if (landmark.likelihood >= 0.5) {
        // Punto principal
        paint.color = Colors.greenAccent;
        canvas.drawCircle(point, 6.0, paint);

        // Círculo de confianza
        final confidencePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = _getConfidenceColor(landmark.likelihood);

        canvas.drawCircle(point, 10.0, confidencePaint);
      }
    }
  }
  
  void _drawAllConnections(Canvas canvas, Size size, MediaPipePose pose) {
    // Lista de conexiones del esqueleto completo
    final connections = [
      // Torso
      [MediaPipePoseLandmark.leftShoulder, MediaPipePoseLandmark.rightShoulder],
      [MediaPipePoseLandmark.leftShoulder, MediaPipePoseLandmark.leftHip],
      [MediaPipePoseLandmark.rightShoulder, MediaPipePoseLandmark.rightHip],
      [MediaPipePoseLandmark.leftHip, MediaPipePoseLandmark.rightHip],
      
      // Brazo izquierdo
      [MediaPipePoseLandmark.leftShoulder, MediaPipePoseLandmark.leftElbow],
      [MediaPipePoseLandmark.leftElbow, MediaPipePoseLandmark.leftWrist],
      
      // Brazo derecho
      [MediaPipePoseLandmark.rightShoulder, MediaPipePoseLandmark.rightElbow],
      [MediaPipePoseLandmark.rightElbow, MediaPipePoseLandmark.rightWrist],
      
      // Pierna izquierda
      [MediaPipePoseLandmark.leftHip, MediaPipePoseLandmark.leftKnee],
      [MediaPipePoseLandmark.leftKnee, MediaPipePoseLandmark.leftAnkle],
      
      // Pierna derecha
      [MediaPipePoseLandmark.rightHip, MediaPipePoseLandmark.rightKnee],
      [MediaPipePoseLandmark.rightKnee, MediaPipePoseLandmark.rightAnkle],
      
      // Cara
      [MediaPipePoseLandmark.nose, MediaPipePoseLandmark.leftShoulder],
      [MediaPipePoseLandmark.nose, MediaPipePoseLandmark.rightShoulder],
    ];

    for (final connection in connections) {
      _drawConnection(canvas, size, pose, connection[0], connection[1]);
    }
  }

  void _drawConnection(
    Canvas canvas,
    Size size,
    MediaPipePose pose,
    int startIndex,
    int endIndex,
  ) {
    final start = pose.getLandmark(startIndex);
    final end = pose.getLandmark(endIndex);

    if (start == null || end == null) return;
    if (start.likelihood < 0.5 || end.likelihood < 0.5) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent.withOpacity(0.7);

    canvas.drawLine(
      _translatePoint(start.x, start.y, size),
      _translatePoint(end.x, end.y, size),
      paint,
    );
  }

  Offset _translatePoint(double x, double y, Size size) {
    if (absoluteImageSize.width == 0 || absoluteImageSize.height == 0) {
      return Offset.zero;
    }
    
    // La cámara en Android captura en landscape (width > height)
    // Pero mostramos en portrait (width < height)
    // MediaPipe devuelve coordenadas en píxeles de la imagen landscape
    // Para rotar 90° horario: canvas_x = image_y, canvas_y = image_width - image_x
    
    final canvasX = y;  // x del canvas = y de la imagen
    final canvasY = absoluteImageSize.width - x;  // y del canvas = width - x de la imagen
    
    // Escalar al tamaño del canvas
    // El ancho del canvas corresponde al alto de la imagen
    final scaleX = size.width / absoluteImageSize.height;
    // El alto del canvas corresponde al ancho de la imagen  
    final scaleY = size.height / absoluteImageSize.width;
    
    final scaledX = canvasX * scaleX;
    final scaledY = canvasY * scaleY;
    
    // Invertir horizontalmente si es cámara frontal
    final flippedX = cameraLensDirection == CameraLensDirection.front
        ? size.width - scaledX
        : scaledX;
    
    return Offset(flippedX, scaledY);
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.yellow;
    return Colors.red;
  }

  @override
  bool shouldRepaint(covariant PosePainterMediaPipe oldDelegate) {
    return poses != oldDelegate.poses;
  }
}
