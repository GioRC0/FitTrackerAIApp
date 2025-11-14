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

    // Solo mostrar 5 keypoints esenciales para plancha (lado izquierdo)
    final landmarksToShow = [
      MediaPipePoseLandmark.leftShoulder,
      MediaPipePoseLandmark.leftHip,
      MediaPipePoseLandmark.leftAnkle,
      MediaPipePoseLandmark.leftElbow,
      MediaPipePoseLandmark.leftWrist,
    ];

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4.0
      ..color = Colors.greenAccent;

    // Dibujar puntos clave
    for (final landmarkIndex in landmarksToShow) {
      final landmark = pose.getLandmark(landmarkIndex);
      if (landmark == null) continue;

      final x = _translateX(landmark.x, size);
      final y = _translateY(landmark.y, size);

      // Solo dibujar si tiene buena confianza
      if (landmark.likelihood >= 0.5) {
        canvas.drawCircle(
          Offset(x, y),
          8.0,
          paint,
        );

        // Dibujar círculo de confianza
        final confidencePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = _getConfidenceColor(landmark.likelihood);

        canvas.drawCircle(
          Offset(x, y),
          12.0,
          confidencePaint,
        );
      }
    }

    // Dibujar conexiones (líneas entre puntos)
    _drawConnection(canvas, size, pose, 
      MediaPipePoseLandmark.leftShoulder, MediaPipePoseLandmark.leftElbow);
    _drawConnection(canvas, size, pose, 
      MediaPipePoseLandmark.leftElbow, MediaPipePoseLandmark.leftWrist);
    _drawConnection(canvas, size, pose, 
      MediaPipePoseLandmark.leftShoulder, MediaPipePoseLandmark.leftHip);
    _drawConnection(canvas, size, pose, 
      MediaPipePoseLandmark.leftHip, MediaPipePoseLandmark.leftAnkle);
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
      Offset(_translateX(start.x, size), _translateY(start.y, size)),
      Offset(_translateX(end.x, size), _translateY(end.y, size)),
      paint,
    );
  }

  double _translateX(double x, Size size) {
    if (absoluteImageSize.width == 0) return 0;
    
    // MediaPipe ya da coordenadas absolutas en píxeles
    final normalizedX = x / absoluteImageSize.width;
    
    // Invertir horizontalmente si es cámara frontal
    final flippedX = cameraLensDirection == CameraLensDirection.front
        ? size.width - (normalizedX * size.width)
        : normalizedX * size.width;
    
    return flippedX;
  }

  double _translateY(double y, Size size) {
    if (absoluteImageSize.height == 0) return 0;
    
    // MediaPipe ya da coordenadas absolutas en píxeles
    final normalizedY = y / absoluteImageSize.height;
    return normalizedY * size.height;
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
