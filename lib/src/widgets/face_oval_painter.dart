import 'package:flutter/material.dart';

class FaceOvalPainter extends CustomPainter {
  final bool allChecksPassed;
  final bool isCapturing;

  FaceOvalPainter({
    this.allChecksPassed = false,
    this.isCapturing = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.68,
      height: size.height * 0.46,
    );

    // Dimmed overlay with oval cutout — lighter for a more open feel
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      backgroundPath,
      Paint()
        ..color = Colors.black.withAlpha(100)
        ..style = PaintingStyle.fill,
    );

    // Soft glow when capturing or all passed
    if (allChecksPassed || isCapturing) {
      final glowColor = isCapturing
          ? const Color(0xFFFBBF24).withAlpha(55) // amber
          : const Color(0xFF4ADE80).withAlpha(50); // lime green

      canvas.drawOval(
        ovalRect.inflate(8),
        Paint()
          ..color = glowColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Oval border — clean, thin
    final Color borderColor = isCapturing
        ? const Color(0xFFFBBF24)
        : allChecksPassed
            ? const Color(0xFF4ADE80)
            : Colors.white.withAlpha(210);

    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = allChecksPassed ? 2.5 : 1.8,
    );
  }

  @override
  bool shouldRepaint(FaceOvalPainter oldDelegate) =>
      oldDelegate.allChecksPassed != allChecksPassed ||
      oldDelegate.isCapturing != isCapturing;
}
