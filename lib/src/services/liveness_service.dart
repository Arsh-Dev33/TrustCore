import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LivenessService {
  final FaceDetector _detector;

  double _prevLeftEye = 1.0;
  double _prevRightEye = 1.0;
  bool _blinkDetected = false;
  int _frameSkip = 0;

  LivenessService()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: true,
            performanceMode: FaceDetectorMode.fast,
          ),
        );

  bool get blinkDetected => _blinkDetected;

  /// Process each camera frame for blink detection
  Future<void> processFrame(
    CameraImage image,
    InputImageRotation rotation,
  ) async {
    // Process every 3rd frame for performance
    _frameSkip++;
    if (_frameSkip % 3 != 0) return;

    try {
      final inputImage = _buildInputImage(image, rotation);
      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) return;

      final face = faces.first;
      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;

      // Blink = eyes were open (>0.8) → now closed (<0.3)
      if (_prevLeftEye > 0.8 &&
          _prevRightEye > 0.8 &&
          leftEye < 0.3 &&
          rightEye < 0.3) {
        _blinkDetected = true;
      }

      _prevLeftEye = leftEye;
      _prevRightEye = rightEye;
    } catch (_) {}
  }

  InputImage _buildInputImage(CameraImage image, InputImageRotation rotation) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void reset() {
    _blinkDetected = false;
    _prevLeftEye = 1.0;
    _prevRightEye = 1.0;
    _frameSkip = 0;
  }

  void dispose() => _detector.close();
}
