import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Result of real-time frame face checks
class FrameCheckResult {
  final bool faceFound;
  final bool multipleFaces;
  final bool eyesOpen;
  final bool faceForward;
  final bool faceCovered;
  final int faceCount;
  final double leftEyeProb;
  final double rightEyeProb;

  final Rect? faceRect;

  FrameCheckResult({
    required this.faceFound,
    required this.multipleFaces,
    required this.eyesOpen,
    required this.faceForward,
    required this.faceCovered,
    required this.faceCount,
    required this.leftEyeProb,
    required this.rightEyeProb,
    this.faceRect,
  });

  /// All basic ML Kit checks pass
  bool get allPassed =>
      faceFound && !multipleFaces && eyesOpen && faceForward && !faceCovered;
}

class MLKitFaceService {
  late final FaceDetector _faceDetector;
  int _frameSkip = 0;
  FrameCheckResult? _lastResult;

  MLKitFaceService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
  }

  FrameCheckResult? get lastResult => _lastResult;

  /// Checks if the lower face (nose + mouth) is obscured using ML Kit contours.
  /// Returns true if neither the nose bottom nor lip contours are detectable.
  bool _isFaceCovered(Face face) {
    final noseBottom = face.contours[FaceContourType.noseBottom];
    final upperLip   = face.contours[FaceContourType.upperLipTop];
    final lowerLip   = face.contours[FaceContourType.lowerLipBottom];

    final bool noseVisible = noseBottom != null && noseBottom.points.isNotEmpty;
    final bool lipsVisible = (upperLip != null && upperLip.points.isNotEmpty) ||
                             (lowerLip != null && lowerLip.points.isNotEmpty);

    // Covered if neither nose nor lips are detectable
    return !noseVisible && !lipsVisible;
  }

  /// Run checks on live camera frame
  Future<FrameCheckResult?> processFrame(
    CameraImage image,
    InputImageRotation rotation,
  ) async {
    _frameSkip++;
    if (_frameSkip % 4 != 0) return _lastResult;

    try {
      final inputImage = _buildInputImage(image, rotation);
      final faces = await _faceDetector.processImage(inputImage);

      // No face
      if (faces.isEmpty) {
        _lastResult = FrameCheckResult(
          faceFound: false,
          multipleFaces: false,
          eyesOpen: false,
          faceForward: false,
          faceCovered: false,
          faceCount: 0,
          leftEyeProb: 0,
          rightEyeProb: 0,
        );
        return _lastResult;
      }

      // Multiple faces
      if (faces.length > 1) {
        _lastResult = FrameCheckResult(
          faceFound: true,
          multipleFaces: true,
          eyesOpen: false,
          faceForward: false,
          faceCovered: false,
          faceCount: faces.length,
          leftEyeProb: 0,
          rightEyeProb: 0,
        );
        return _lastResult;
      }

      final face = faces.first;
      final leftEye  = face.leftEyeOpenProbability ?? 0.0;
      final rightEye = face.rightEyeOpenProbability ?? 0.0;
      final eulerY   = face.headEulerAngleY ?? 0.0;
      final eulerZ   = face.headEulerAngleZ ?? 0.0;

      // Contour-based coverage: covered when nose/mouth contours are not detectable
      final bool faceCovered = _isFaceCovered(face);

      _lastResult = FrameCheckResult(
        faceFound: true,
        multipleFaces: false,
        eyesOpen: leftEye > 0.65 && rightEye > 0.65,
        faceForward: eulerY.abs() < 20 && eulerZ.abs() < 20,
        faceCovered: faceCovered,
        faceCount: 1,
        leftEyeProb: leftEye,
        rightEyeProb: rightEye,
        faceRect: face.boundingBox,
      );

      return _lastResult;
    } catch (_) {
      return _lastResult;
    }
  }

  /// Run full validation on captured still image
  Future<FrameCheckResult> validateStillImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      return FrameCheckResult(
        faceFound: false,
        multipleFaces: false,
        eyesOpen: false,
        faceForward: false,
        faceCovered: false,
        faceCount: 0,
        leftEyeProb: 0,
        rightEyeProb: 0,
      );
    }

    if (faces.length > 1) {
      return FrameCheckResult(
        faceFound: true,
        multipleFaces: true,
        eyesOpen: false,
        faceForward: false,
        faceCovered: false,
        faceCount: faces.length,
        leftEyeProb: 0,
        rightEyeProb: 0,
      );
    }

    final face = faces.first;
    final leftEye  = face.leftEyeOpenProbability ?? 0.0;
    final rightEye = face.rightEyeOpenProbability ?? 0.0;
    final eulerY   = face.headEulerAngleY ?? 0.0;
    final eulerZ   = face.headEulerAngleZ ?? 0.0;

    final bool faceCovered = _isFaceCovered(face);

    return FrameCheckResult(
      faceFound: true,
      multipleFaces: false,
      eyesOpen: leftEye > 0.65 && rightEye > 0.65,
      faceForward: eulerY.abs() < 20 && eulerZ.abs() < 20,
      faceCovered: faceCovered,
      faceCount: 1,
      leftEyeProb: leftEye,
      rightEyeProb: rightEye,
      faceRect: face.boundingBox,
    );
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

  void dispose() {
    _faceDetector.close();
  }
}
