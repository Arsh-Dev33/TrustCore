import 'package:flutter/material.dart';

class FaceOvalPainter extends CustomPainter {
  final bool isValid;
  final bool isProcessing;

  FaceOvalPainter({this.isValid = false, this.isProcessing = false});

  @override
  void paint(Canvas canvas, Size size) {
    final Color color = isProcessing
        ? Colors.yellow
        : isValid
            ? Colors.green
            : Colors.white;

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      overlayPaint,
    );

    // Use a fixed aspect ratio for the oval to prevent stretching on tall screens
    final ovalWidth = size.width * 0.7;
    final ovalHeight = ovalWidth * 1.35; // Standard face aspect ratio

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: ovalWidth,
      height: ovalHeight,
    );

    canvas.drawOval(ovalRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    final guidePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final guides = [
      [ovalRect.topLeft, ovalRect.topLeft + const Offset(20, 0)],
      [ovalRect.topLeft, ovalRect.topLeft + const Offset(0, 20)],
      [ovalRect.topRight, ovalRect.topRight + const Offset(-20, 0)],
      [ovalRect.topRight, ovalRect.topRight + const Offset(0, 20)],
    ];
    for (final g in guides) {
      canvas.drawLine(g[0], g[1], guidePaint);
    }
  }

  @override
  bool shouldRepaint(FaceOvalPainter oldDelegate) =>
      oldDelegate.isValid != isValid ||
      oldDelegate.isProcessing != isProcessing;
}
