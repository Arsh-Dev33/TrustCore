import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';
import '../models/verify_result.dart';
import '../models/face_verify_error.dart';
import '../models/face_validation_result.dart';
import '../services/face_detection_service.dart';
import '../services/face_embedding_service.dart';
import '../services/face_matcher_service.dart';
import '../services/liveness_service.dart';
import '../services/base64_service.dart';
import '../services/transaction_service.dart';
import 'widgets/face_oval_painter.dart';
import 'widgets/status_banner.dart';

class LibVerifyScreen extends StatefulWidget {
  final String userId;
  final String referenceImageBase64;
  final TrustCoreConfig config;

  const LibVerifyScreen({
    super.key,
    required this.userId,
    required this.referenceImageBase64,
    required this.config,
  });

  @override
  State<LibVerifyScreen> createState() => _LibVerifyScreenState();
}

class _LibVerifyScreenState extends State<LibVerifyScreen> {
  CameraController? _cameraController;
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();
  final FaceMatcherService _matcherService = FaceMatcherService();
  late final LivenessService _livenessService;

  String _statusMessage = 'Initializing camera...';
  ValidationError _currentError = ValidationError.none;
  bool _isValid = false;
  bool _isProcessing = false;
  bool _isCaptured = false;
  bool _livenessCompleted = false;
  bool _cameraReady = false;
  Timer? _livenessTimer;

  List<double>? _referenceEmbedding;

  @override
  void initState() {
    super.initState();
    _livenessService = LivenessService();
    _embeddingService.initialize(); // Load model in background
    _initCamera(); // Start camera immediately
    _loadReferenceImage();
  }

  Future<void> _loadReferenceImage() async {
    try {
      final tempPath =
          await Base64Service.base64ToTempFile(widget.referenceImageBase64);
      final result = await _faceDetectionService.validateFace(tempPath);

      if (result.isValid && result.boundingBox != null) {
        _referenceEmbedding = await _embeddingService.getEmbedding(
          tempPath,
          result.boundingBox!,
        );
        await Base64Service.cleanupTempFile(tempPath);
      } else {
        if (!mounted) return;
        final txnId = TransactionService.generateTransactionId();
        Navigator.pop(
          context,
          VerifyResult.failure(
            transactionId: txnId,
            message: 'Invalid reference image: ${result.message}',
            error: FaceVerifyError.invalidReferenceImage,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final txnId = TransactionService.generateTransactionId();
      Navigator.pop(
        context,
        VerifyResult.failure(
          transactionId: txnId,
          message: 'Failed to process reference image',
          error: FaceVerifyError.invalidReferenceImage,
        ),
      );
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      final txnId = TransactionService.generateTransactionId();
      Navigator.pop(
        context,
        VerifyResult.failure(
          transactionId: txnId,
          message: 'Camera permission denied',
          error: FaceVerifyError.cameraPermissionDenied,
        ),
      );
      return;
    }

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      widget.config.cameraResolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    if (widget.config.requireLiveness) {
      _startLivenessDetection();
      _startLivenessTimer();
    } else {
      _livenessCompleted = true;
      _cameraReady = true;
    }

    setState(() {
      _statusMessage = widget.config.requireLiveness
          ? 'Please blink your eyes for liveness check'
          : 'Position your face in the oval';
    });
  }

  void _startLivenessDetection() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_livenessCompleted || _isProcessing) return;
      final rotation = InputImageRotation.rotation270deg;
      final blinkDetected =
          await _livenessService.processFrame(image, rotation);
      if (blinkDetected && mounted) {
        _livenessTimer?.cancel();
        try {
          await _cameraController?.stopImageStream();
        } catch (_) {}
        // Small delay to let camera stabilize after stopping stream
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        setState(() {
          _livenessCompleted = true;
          _cameraReady = true;
          _statusMessage = 'Liveness confirmed! Press verify button';
        });
      }
    });
  }

  void _startLivenessTimer() {
    _livenessTimer = Timer(widget.config.livenessTimeout, () {
      if (!_livenessCompleted && mounted) {
        final txnId = TransactionService.generateTransactionId();
        Navigator.pop(
          context,
          VerifyResult.failure(
            transactionId: txnId,
            message: 'Liveness check timed out',
            error: FaceVerifyError.livenessTimeout,
          ),
        );
      }
    });
  }

  Future<void> _captureAndVerify() async {
    if (_isProcessing ||
        _isCaptured ||
        _referenceEmbedding == null ||
        !_cameraReady) {
      return;
    }
    setState(() {
      _isProcessing = true;
      _currentError = ValidationError.none;
      _statusMessage = 'Verifying...';
    });

    try {
      final image = await _cameraController!.takePicture();
      final validation = await _faceDetectionService.validateFace(image.path);

      if (!validation.isValid) {
        setState(() {
          _isProcessing = false;
          _isValid = false;
          _currentError = validation.error;
          _statusMessage = validation.message;
        });
        return;
      }

      // Generate real embedding using TFLite MobileFaceNet model
      final newEmbedding = await _embeddingService.getEmbedding(
        image.path,
        validation.boundingBox!,
      );

      // Compare embeddings
      final matchResult = _matcherService.compareFaces(
        _referenceEmbedding!,
        newEmbedding,
      );

      final txnId = TransactionService.generateTransactionId();
      final capturedBase64 = await Base64Service.imageFileToBase64(image.path);
      final passed =
          matchResult.similarityPercent >= widget.config.matchThreshold;

      setState(() {
        _isValid = passed;
        _isCaptured = true;
        _statusMessage = passed
            ? '${matchResult.similarityPercent.toStringAsFixed(1)}% — ${matchResult.verdict}'
            : 'Verification failed: ${matchResult.similarityPercent.toStringAsFixed(1)}%';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.pop(
        context,
        VerifyResult.success(
          transactionId: txnId,
          matchPercent: matchResult.similarityPercent,
          verdict: matchResult.verdict,
          passed: passed,
          capturedBase64: capturedBase64,
        ),
      );
    } catch (e) {
      debugPrint('TrustCore verify error: $e');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isValid = false;
        _currentError = ValidationError.noFace;
        _statusMessage = 'Something went wrong. Please try again.';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _currentError = ValidationError.none;
        _isCaptured = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetectionService.dispose();
    _embeddingService.dispose();
    _livenessService.dispose();
    _livenessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final txnId = TransactionService.generateTransactionId();
        Navigator.pop(
          context,
          VerifyResult.failure(
            transactionId: txnId,
            message: 'User cancelled',
            error: FaceVerifyError.userCancelled,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Camera preview
            if (_cameraController != null &&
                _cameraController!.value.isInitialized)
              Positioned.fill(
                child: CameraPreview(_cameraController!),
              ),

            // Face oval overlay
            Positioned.fill(
              child: CustomPaint(
                painter: FaceOvalPainter(
                  isValid: _isValid,
                  isProcessing: _isProcessing,
                ),
              ),
            ),

            // Top status bar (only for errors or success)
            if (_currentError != ValidationError.none || _isValid)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: StatusBanner(
                  message: _statusMessage,
                  error: _currentError,
                  isSuccess: _isValid,
                ),
              ),

            // Cancel button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () {
                  final txnId = TransactionService.generateTransactionId();
                  Navigator.pop(
                    context,
                    VerifyResult.failure(
                      transactionId: txnId,
                      message: 'User cancelled',
                      error: FaceVerifyError.userCancelled,
                    ),
                  );
                },
              ),
            ),

            // Liveness status chip
            if (widget.config.requireLiveness)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_livenessCompleted ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _livenessCompleted ? Icons.verified : Icons.pending,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _livenessCompleted ? 'LIVE' : 'BLINK',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Manual capture/verify button
            if (_livenessCompleted &&
                _cameraReady &&
                !_isCaptured &&
                !_isProcessing)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'VERIFY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _captureAndVerify,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Processing indicator
            if (_isProcessing)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
