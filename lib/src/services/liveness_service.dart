import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class LivenessService {
  final FaceDetector _detector;
  bool _blinkDetected = false;
  double _previousLeftEye = 1.0;
  double _previousRightEye = 1.0;
  int _frameCount = 0;

  LivenessService()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: true,
            performanceMode: FaceDetectorMode.fast,
          ),
        );

  Future<bool> processFrame(
    CameraImage cameraImage,
    InputImageRotation rotation,
  ) async {
    _frameCount++;
    if (_frameCount % 3 != 0) {
      return _blinkDetected;
    }

    final bytesBuilder = BytesBuilder();
    for (final Plane plane in cameraImage.planes) {
      bytesBuilder.add(plane.bytes);
    }
    final bytes = bytesBuilder.toBytes();

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(
          cameraImage.width.toDouble(),
          cameraImage.height.toDouble(),
        ),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      ),
    );

    try {
      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) return _blinkDetected;
      final face = faces.first;
      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;
      if (_previousLeftEye > 0.75 && _previousRightEye > 0.75) {
        if (leftEye < 0.3 && rightEye < 0.3) {
          _blinkDetected = true;
        }
      }
      _previousLeftEye = leftEye;
      _previousRightEye = rightEye;
    } catch (_) {}
    return _blinkDetected;
  }

  void reset() {
    _blinkDetected = false;
    _previousLeftEye = 1.0;
    _previousRightEye = 1.0;
    _frameCount = 0;
  }

  void dispose() {
    _detector.close();
  }
}
