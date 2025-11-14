import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size absoluteImageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final CameraDescription cameraDescription;

  PosePainter({
    required this.poses,
    required this.absoluteImageSize,
    required this.rotation,
    required this.cameraLensDirection,
    required this.cameraDescription,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0
      ..color = Colors.green;

    final leftPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final rightPaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final centerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    for (final pose in poses) {
      // Dibujar las líneas primero (fondo)
      _drawPoseSkeleton(canvas, pose, size, leftPaint, rightPaint, centerPaint);
      
      // Puntos a mostrar: solo muñecas para manos y nariz para cabeza
      final landmarksToShow = [
        PoseLandmarkType.nose,          // 1 punto para cabeza
        PoseLandmarkType.leftWrist,     // 1 punto para mano izquierda
        PoseLandmarkType.rightWrist,    // 1 punto para mano derecha
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.rightAnkle,
      ];
      
      // Dibujar solo los puntos seleccionados
      pose.landmarks.forEach((type, landmark) {
        if (!landmarksToShow.contains(type)) return;
        
        final offset = _translatePoint(landmark, size);
        canvas.drawCircle(offset, 6, pointPaint);
        // Borde blanco para mejor visibilidad
        canvas.drawCircle(
          offset,
          6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = Colors.white,
        );
      });
    }
  }

  void _drawPoseSkeleton(
      Canvas canvas, Pose pose, Size size, Paint leftPaint, Paint rightPaint, Paint centerPaint) {
    void drawLine(
        PoseLandmarkType type1, PoseLandmarkType type2, Paint paintType) {
      final PoseLandmark? joint1 = pose.landmarks[type1];
      final PoseLandmark? joint2 = pose.landmarks[type2];
      if (joint1 != null && joint2 != null) {
        canvas.drawLine(
          _translatePoint(joint1, size),
          _translatePoint(joint2, size),
          paintType,
        );
      }
    }

    // Dibujar el esqueleto del cuerpo
    // Línea central (hombros y caderas)
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, centerPaint);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, centerPaint);
    
    // Lado izquierdo
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
    
    // Lado derecho
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, rightPaint);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, rightPaint);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);
  }

  // --- TRANSFORMACIÓN DE COORDENADAS CORREGIDA ---
  Offset _translatePoint(PoseLandmark landmark, Size canvasSize) {
    final double x = landmark.x;
    final double y = landmark.y;

    // Para rotaciones de 90° o 270°, las dimensiones de la imagen están intercambiadas
    final bool isRotated = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg ||
        rotation == InputImageRotation.rotation0deg ||
        rotation == InputImageRotation.rotation180deg;

    // Dimensiones efectivas considerando la rotación
    final double imageWidth = isRotated ? absoluteImageSize.height : absoluteImageSize.width;
    final double imageHeight = isRotated ? absoluteImageSize.width : absoluteImageSize.height;

    // Calcular el ratio de escalado usando las dimensiones rotadas
    final double scaleX = canvasSize.width / imageWidth;
    final double scaleY = canvasSize.height / imageHeight;

    // Transformar las coordenadas según la rotación
    double canvasX;
    double canvasY;

    switch (rotation) {
      case InputImageRotation.rotation0deg:
        // Sin rotación - cámara frontal en vertical
        // Rotar 90° a la izquierda (compensar rotación a la derecha)
        canvasX = y * scaleX;
        canvasY = canvasSize.height - (x * scaleY);
        // Aplicar mirror para cámara frontal
        if (cameraLensDirection == CameraLensDirection.front) {
          canvasX = canvasSize.width - canvasX;
        }
        break;
      case InputImageRotation.rotation90deg:
        // Rotación de 90° en sentido horario
        canvasX = y * scaleX;
        canvasY = canvasSize.height - (x * scaleY);
        break;
      case InputImageRotation.rotation180deg:
        // Rotación de 180° - cámara trasera en vertical
        // Rotar 90° a la izquierda
        canvasX = y * scaleX;
        canvasY = canvasSize.height - (x * scaleY);
        break;
      case InputImageRotation.rotation270deg:
        // Rotación de 270° en sentido horario
        canvasX = canvasSize.width - (y * scaleX);
        canvasY = x * scaleY;
        // Aplicar mirror para cámara frontal
        if (cameraLensDirection == CameraLensDirection.front) {
          canvasX = canvasSize.width - canvasX;
        }
        break;
    }

    return Offset(canvasX, canvasY);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.poses != poses ||
        oldDelegate.rotation != rotation ||
        oldDelegate.cameraLensDirection != cameraLensDirection;
  }
}
