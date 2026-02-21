import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/face_validation_result.dart';
import '../utils/vector_utils.dart';

class FaceDetectionService {
  late final FaceDetector _detector;

  FaceDetectionService() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );
  }

  Future<FaceValidationResult> validateFace(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _detector.processImage(inputImage);

    if (faces.isEmpty) {
      return FaceValidationResult.invalid(
        "No face detected. Please center your face.",
        ValidationError.noFace,
      );
    }
    if (faces.length > 1) {
      return FaceValidationResult.invalid(
        "Multiple faces detected. Only one person allowed.",
        ValidationError.multipleFaces,
      );
    }

    final face = faces.first;
    final leftEye = face.leftEyeOpenProbability ?? 0.0;
    final rightEye = face.rightEyeOpenProbability ?? 0.0;
    if (leftEye < 0.65 || rightEye < 0.65) {
      return FaceValidationResult.invalid(
        "Please keep both eyes open.",
        ValidationError.eyesClosed,
      );
    }

    final eulerY = face.headEulerAngleY ?? 0.0;
    final eulerZ = face.headEulerAngleZ ?? 0.0;
    if (eulerY.abs() > 20.0 || eulerZ.abs() > 20.0) {
      return FaceValidationResult.invalid(
        "Please look directly at the camera.",
        ValidationError.lookingAway,
      );
    }

    final faceArea = face.boundingBox.width * face.boundingBox.height;
    if (faceArea < 10000) {
      return FaceValidationResult.invalid(
        "Move closer to the camera.",
        ValidationError.tooFar,
      );
    }

    final embedding = _extractEmbedding(face);
    return FaceValidationResult(
      isValid: true,
      message: "Face validated successfully!",
      leftEyeOpenProb: leftEye,
      rightEyeOpenProb: rightEye,
      headEulerY: eulerY,
      headEulerZ: eulerZ,
      embedding: embedding,
    );
  }

  List<double> _extractEmbedding(Face face) {
    final List<double> features = [];
    for (final contourType in FaceContourType.values) {
      final contour = face.contours[contourType];
      if (contour != null) {
        for (final point in contour.points) {
          features.add(point.x.toDouble());
          features.add(point.y.toDouble());
        }
      }
    }
    if (features.isEmpty) {
      final box = face.boundingBox;
      features.addAll([
        box.left,
        box.top,
        box.right,
        box.bottom,
        box.width,
        box.height,
      ]);
      for (final landmarkType in FaceLandmarkType.values) {
        final landmark = face.landmarks[landmarkType];
        if (landmark != null) {
          features.add(landmark.position.x.toDouble());
          features.add(landmark.position.y.toDouble());
        }
      }
    }
    final box = face.boundingBox;
    final normalized = <double>[];
    for (int i = 0; i < features.length; i += 2) {
      if (i + 1 < features.length) {
        normalized.add((features[i] - box.left) / box.width);
        normalized.add((features[i + 1] - box.top) / box.height);
      }
    }
    return VectorUtils.normalize(normalized);
  }

  void dispose() {
    _detector.close();
  }
}
