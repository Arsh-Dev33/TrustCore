enum ValidationError {
  noFace,
  multipleFaces,
  eyesClosed,
  lookingAway,
  tooFar,
  tooClose,
  eyewearDetected,
  fakeFace,
  none,
}

class FaceValidationResult {
  final bool isValid;
  final String message;
  final ValidationError error;
  final double? leftEyeOpenProb;
  final double? rightEyeOpenProb;
  final double? headEulerY;
  final double? headEulerZ;
  final List<double>? embedding;

  FaceValidationResult({
    required this.isValid,
    required this.message,
    this.error = ValidationError.none,
    this.leftEyeOpenProb,
    this.rightEyeOpenProb,
    this.headEulerY,
    this.headEulerZ,
    this.embedding,
  });

  factory FaceValidationResult.invalid(String message, ValidationError error) {
    return FaceValidationResult(isValid: false, message: message, error: error);
  }
}
