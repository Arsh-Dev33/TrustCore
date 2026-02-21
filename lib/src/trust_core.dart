import 'package:flutter/material.dart';
import 'config.dart';
import 'models/signup_result.dart';
import 'models/verify_result.dart';
import 'models/face_verify_error.dart';
import 'services/face_storage_service.dart';
import 'services/transaction_service.dart';
import 'ui/signup_screen.dart';
import 'ui/lib_verify_screen.dart';

class TrustCore {
  final TrustCoreConfig config;
  final FaceStorageService _storage = FaceStorageService();

  TrustCore({this.config = const TrustCoreConfig()});

  Future<SignupResult> signup({
    required BuildContext context,
    required String userId,
  }) async {
    final result = await Navigator.push<SignupResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SignupScreen(userId: userId, config: config),
      ),
    );
    return result ??
        SignupResult.failure(
          transactionId: TransactionService.generateTransactionId(),
          message: 'User cancelled',
          error: FaceVerifyError.userCancelled,
        );
  }

  Future<VerifyResult> verify({
    required BuildContext context,
    required String userId,
    required String referenceImageBase64,
  }) async {
    if (referenceImageBase64.isEmpty) {
      return VerifyResult.failure(
        transactionId: TransactionService.generateTransactionId(),
        message: 'Reference image is empty',
        error: FaceVerifyError.noReferenceImage,
      );
    }
    final result = await Navigator.push<VerifyResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LibVerifyScreen(
          userId: userId,
          referenceImageBase64: referenceImageBase64,
          config: config,
        ),
      ),
    );
    return result ??
        VerifyResult.failure(
          transactionId: TransactionService.generateTransactionId(),
          message: 'User cancelled',
          error: FaceVerifyError.userCancelled,
        );
  }

  Future<bool> isRegistered(String userId) => _storage.isRegistered(userId);
  Future<void> deleteFace(String userId) => _storage.deleteFace(userId);
  Future<List<String>> getAllRegisteredUsers() => _storage.getAllUsers();
}
