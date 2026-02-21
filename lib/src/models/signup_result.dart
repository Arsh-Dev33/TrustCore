import 'face_verify_error.dart';

class SignupResult {
  final bool success;
  final String transactionId;
  final String? imageBase64;
  final String message;
  final DateTime timestamp;
  final FaceVerifyError? error;

  const SignupResult({
    required this.success,
    required this.transactionId,
    this.imageBase64,
    required this.message,
    required this.timestamp,
    this.error,
  });

  factory SignupResult.success({
    required String transactionId,
    required String imageBase64,
    String message = 'Face registered successfully',
  }) {
    return SignupResult(
      success: true,
      transactionId: transactionId,
      imageBase64: imageBase64,
      message: message,
      timestamp: DateTime.now().toUtc(),
    );
  }

  factory SignupResult.failure({
    required String transactionId,
    required String message,
    required FaceVerifyError error,
  }) {
    return SignupResult(
      success: false,
      transactionId: transactionId,
      message: message,
      timestamp: DateTime.now().toUtc(),
      error: error,
    );
  }
}
