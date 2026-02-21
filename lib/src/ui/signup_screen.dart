import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';
import '../models/signup_result.dart';
import '../models/face_verify_error.dart';
import '../models/face_record.dart';
import '../models/face_validation_result.dart';
import '../services/face_detection_service.dart';
import '../services/face_storage_service.dart';
import '../services/liveness_service.dart';
import '../services/base64_service.dart';
import '../services/transaction_service.dart';
import '../utils/image_utils.dart';
import 'widgets/face_oval_painter.dart';
import 'widgets/status_banner.dart';

class SignupScreen extends StatefulWidget {
  final String userId;
  final TrustCoreConfig config;

  const SignupScreen({
    super.key,
    required this.userId,
    required this.config,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  CameraController? _cameraController;
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final FaceStorageService _storageService = FaceStorageService();
  late final LivenessService _livenessService;

  String _statusMessage = 'Initializing camera...';
  ValidationError _currentError = ValidationError.none;
  bool _isValid = false;
  bool _isProcessing = false;
  bool _isCaptured = false;
  bool _livenessCompleted = false;
  Timer? _livenessTimer;

  @override
  void initState() {
    super.initState();
    _livenessService = LivenessService();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      final txnId = TransactionService.generateTransactionId();
      Navigator.pop(
        context,
        SignupResult.failure(
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
        setState(() {
          _livenessCompleted = true;
          _statusMessage =
              'Liveness confirmed! Press capture button to register';
        });
        _cameraController?.stopImageStream();
        _livenessTimer?.cancel();
      }
    });
  }

  void _startLivenessTimer() {
    _livenessTimer = Timer(widget.config.livenessTimeout, () {
      if (!_livenessCompleted && mounted) {
        final txnId = TransactionService.generateTransactionId();
        Navigator.pop(
          context,
          SignupResult.failure(
            transactionId: txnId,
            message: 'Liveness check timed out',
            error: FaceVerifyError.livenessTimeout,
          ),
        );
      }
    });
  }

  Future<void> _captureAndValidate() async {
    if (_isProcessing || _isCaptured) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing...';
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

      // Face is valid — save and return
      setState(() {
        _isValid = true;
        _isCaptured = true;
        _statusMessage = 'Face captured successfully!';
      });

      final txnId = TransactionService.generateTransactionId();
      final savedPath = await ImageUtils.saveImage(
        image.path,
        '${widget.userId}_signup.jpg',
      );
      final base64Image = await Base64Service.imageFileToBase64(savedPath);

      // Store face record
      final record = FaceRecord(
        userId: widget.userId,
        imagePath: savedPath,
        embedding: validation.embedding ?? [],
        registeredAt: DateTime.now().toUtc(),
      );
      await _storageService.storeFace(record);

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.pop(
        context,
        SignupResult.success(
          transactionId: txnId,
          imageBase64: base64Image,
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetectionService.dispose();
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
          SignupResult.failure(
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
                    SignupResult.failure(
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

            // Manual capture button (always visible if liveness is done/disabled)
            if (_livenessCompleted && !_isCaptured && !_isProcessing)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'CAPTURE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _captureAndValidate,
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
