import 'face_verify_error.dart';

class VerifyResult {
  final bool passed;
  final String transactionId;
  final double matchPercent;
  final String verdict;
  final String? capturedBase64;
  final String message;
  final DateTime timestamp;
  final FaceVerifyError? error;

  const VerifyResult({
    required this.passed,
    required this.transactionId,
    required this.matchPercent,
    required this.verdict,
    this.capturedBase64,
    required this.message,
    required this.timestamp,
    this.error,
  });

  factory VerifyResult.success({
    required String transactionId,
    required double matchPercent,
    required String verdict,
    required bool passed,
    required String capturedBase64,
  }) {
    return VerifyResult(
      passed: passed,
      transactionId: transactionId,
      matchPercent: matchPercent,
      verdict: verdict,
      capturedBase64: capturedBase64,
      message: passed ? 'Verification passed' : 'Verification failed',
      timestamp: DateTime.now().toUtc(),
    );
  }

  factory VerifyResult.failure({
    required String transactionId,
    required String message,
    required FaceVerifyError error,
  }) {
    return VerifyResult(
      passed: false,
      transactionId: transactionId,
      matchPercent: 0.0,
      verdict: 'Error',
      message: message,
      timestamp: DateTime.now().toUtc(),
      error: error,
    );
  }
}
