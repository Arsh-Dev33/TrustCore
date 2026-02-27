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
    // Dim overlay
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.68,
      height: size.height * 0.46,
    );

    // Dim overlay with transparent oval hole
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    final overlayPaint = Paint()
      ..color = Colors.black.withAlpha(140) // 0.55 * 255
      ..style = PaintingStyle.fill;

    canvas.drawPath(backgroundPath, overlayPaint);

    // Border color
    final Color borderColor = isCapturing
        ? Colors.yellow
        : allChecksPassed
            ? Colors.green
            : Colors.white;

    // Animated dashed border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawOval(ovalRect, borderPaint);

    // Corner tick marks
    final tickPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(ovalRect.topLeft + const Offset(18, 0),
        ovalRect.topLeft + const Offset(0, 0), tickPaint);
    canvas.drawLine(ovalRect.topLeft + const Offset(0, 0),
        ovalRect.topLeft + const Offset(0, 18), tickPaint);

    // Top-right
    canvas.drawLine(ovalRect.topRight + const Offset(-18, 0),
        ovalRect.topRight + const Offset(0, 0), tickPaint);
    canvas.drawLine(ovalRect.topRight + const Offset(0, 0),
        ovalRect.topRight + const Offset(0, 18), tickPaint);

    // Bottom-left
    canvas.drawLine(ovalRect.bottomLeft + const Offset(18, 0),
        ovalRect.bottomLeft + const Offset(0, 0), tickPaint);
    canvas.drawLine(ovalRect.bottomLeft + const Offset(0, 0),
        ovalRect.bottomLeft + const Offset(0, -18), tickPaint);

    // Bottom-right
    canvas.drawLine(ovalRect.bottomRight + const Offset(-18, 0),
        ovalRect.bottomRight + const Offset(0, 0), tickPaint);
    canvas.drawLine(ovalRect.bottomRight + const Offset(0, 0),
        ovalRect.bottomRight + const Offset(0, -18), tickPaint);
  }

  @override
  bool shouldRepaint(FaceOvalPainter oldDelegate) =>
      oldDelegate.allChecksPassed != allChecksPassed ||
      oldDelegate.isCapturing != isCapturing;
}
