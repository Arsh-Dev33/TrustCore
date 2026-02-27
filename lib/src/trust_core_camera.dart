import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'trust_core_result.dart';
import 'services/mlkit_face_service.dart';
import 'services/tflite_service.dart';
import 'services/liveness_service.dart';
import 'services/location_service.dart';
import 'widgets/face_oval_painter.dart';
import 'widgets/check_indicator.dart';

class TrustCoreCamera extends StatefulWidget {
  const TrustCoreCamera({super.key});

  @override
  State<TrustCoreCamera> createState() => _TrustCoreCameraState();
}

class _TrustCoreCameraState extends State<TrustCoreCamera>
    with WidgetsBindingObserver {
  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // Services
  late MLKitFaceService _mlKitService;
  late TFLiteService _tfliteService;
  late LivenessService _livenessService;

  // State
  bool _isCapturing = false;
  String _mainMessage = "Position your face in the oval";
  String? _retryReason; // persists after a failed attempt until face is in position

  // Check statuses
  CheckStatus _livenessStatus = CheckStatus.pending;
  CheckStatus _singleFaceStatus = CheckStatus.pending;
  CheckStatus _eyesOpenStatus = CheckStatus.pending;
  CheckStatus _maskStatus = CheckStatus.pending;
  CheckStatus _glassesStatus = CheckStatus.pending;
  CheckStatus _faceCoveredStatus = CheckStatus.pending;

  // Fail messages
  String? _livenessMessage;
  String? _singleFaceMessage;
  String? _eyesMessage;
  String? _maskMessage;
  String? _glassesMessage;
  String? _faceCoveredMessage;

  bool _allChecksPassed = false;
  bool _tfliteModelsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mlKitService = MLKitFaceService();
    _tfliteService = TFLiteService();
    _livenessService = LivenessService();
    _initAll();
  }

  Future<void> _initAll() async {
    await _requestPermissions();
    await _initCamera();
    await _loadTFLiteModels();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.location].request();
  }

  Future<void> _loadTFLiteModels() async {
    await _tfliteService.loadModels();
    setState(() => _tfliteModelsLoaded = _tfliteService.modelsLoaded);
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      front,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cameraController!.initialize();

    // Start real-time frame processing
    _cameraController!.startImageStream(_onCameraFrame);

    setState(() => _isCameraReady = true);
  }

  // Live stream: only liveness + face guidance until blink is confirmed
  void _onCameraFrame(CameraImage image) async {
    if (_isCapturing || _livenessStatus == CheckStatus.pass) return;

    await _livenessService.processFrame(
      image,
      InputImageRotation.rotation270deg,
    );

    final result = await _mlKitService.processFrame(
      image,
      InputImageRotation.rotation270deg,
    );

    if (!mounted) return;

    setState(() => _updateLivenessGuidance(result));
  }

  void _updateLivenessGuidance(FrameCheckResult? result) {
    if (_livenessService.blinkDetected) {
      _livenessStatus = CheckStatus.pass;
      _livenessMessage = null;
      _retryReason = null;
      _mainMessage = "Tap the button to capture";
      return;
    }

    if (result == null || !result.faceFound) {
      _livenessStatus = CheckStatus.pending;
      // Keep showing the retry reason until face is in position
      _mainMessage = _retryReason ?? "Position your face in the oval";
      return;
    }

    if (result.multipleFaces) {
      _livenessStatus = CheckStatus.pending;
      _mainMessage = "Only one person allowed";
      return;
    }

    if (result.faceCovered) {
      _livenessStatus = CheckStatus.pending;
      _mainMessage = "Remove face covering to continue";
      return;
    }

    // Face is properly in frame — clear retry reason and show blink guidance
    _retryReason = null;

    if (!result.faceForward) {
      _livenessStatus = CheckStatus.fail;
      _livenessMessage = "Please blink to confirm liveness";
      _mainMessage = "Look directly at the camera";
      return;
    }

    _livenessStatus = CheckStatus.fail;
    _livenessMessage = "Please blink to confirm liveness";
    _mainMessage = "Please blink";
  }

  void _checkAllPassed() {
    _allChecksPassed = _livenessStatus == CheckStatus.pass &&
        _singleFaceStatus == CheckStatus.pass &&
        _eyesOpenStatus == CheckStatus.pass &&
        _faceCoveredStatus == CheckStatus.pass &&
        _maskStatus == CheckStatus.pass &&
        _glassesStatus == CheckStatus.pass;
  }

  // On button tap: capture photo and run all remaining checks on the still image
  Future<void> _captureAndProcess() async {
    if (_isCapturing || _livenessStatus != CheckStatus.pass) return;

    setState(() {
      _isCapturing = true;
      _mainMessage = "Hold still...";
    });

    try {
      await _cameraController!.stopImageStream();
      final image = await _cameraController!.takePicture();

      // Run ML Kit on the still image
      setState(() => _mainMessage = "Checking face...");
      final faceResult = await _mlKitService.validateStillImage(image.path);

      if (!mounted) return;

      // Evaluate single face
      if (!faceResult.faceFound) {
        setState(() {
          _singleFaceStatus = CheckStatus.fail;
          _singleFaceMessage = "No face detected";
        });
        _showRetry("No face detected. Please try again.");
        return;
      }
      if (faceResult.multipleFaces) {
        setState(() {
          _singleFaceStatus = CheckStatus.fail;
          _singleFaceMessage = "Multiple faces detected";
        });
        _showRetry("Multiple faces detected. Only one person allowed.");
        return;
      }
      setState(() {
        _singleFaceStatus = CheckStatus.pass;
        _singleFaceMessage = null;
      });

      // Evaluate eyes open
      if (!faceResult.eyesOpen) {
        setState(() {
          _eyesOpenStatus = CheckStatus.fail;
          _eyesMessage = "Please keep both eyes open";
        });
        _showRetry("Please keep your eyes open.");
        return;
      }
      setState(() {
        _eyesOpenStatus = CheckStatus.pass;
        _eyesMessage = null;
      });

      // Evaluate face not covered
      if (faceResult.faceCovered) {
        setState(() {
          _faceCoveredStatus = CheckStatus.fail;
          _faceCoveredMessage = "Face is partially covered";
        });
        _showRetry("Your face appears to be partially covered.");
        return;
      }
      setState(() {
        _faceCoveredStatus = CheckStatus.pass;
        _faceCoveredMessage = null;
      });

      // Evaluate face forward
      if (!faceResult.faceForward) {
        _showRetry("Please look directly at the camera.");
        return;
      }

      // Run TFLite mask + glasses checks
      if (_tfliteModelsLoaded) {
        setState(() {
          _maskStatus = CheckStatus.loading;
          _glassesStatus = CheckStatus.loading;
          _mainMessage = "Checking for mask & glasses...";
        });

        final faceRect = faceResult.faceRect;
        final maskResult =
            await _tfliteService.detectMask(image.path, faceRect: faceRect);
        final glassesResult =
            await _tfliteService.detectGlasses(image.path, faceRect: faceRect);

        if (!mounted) return;

        setState(() {
          _maskStatus =
              maskResult.detected ? CheckStatus.fail : CheckStatus.pass;
          _maskMessage =
              maskResult.detected ? "Please remove your mask" : null;
          _glassesStatus =
              glassesResult.detected ? CheckStatus.fail : CheckStatus.pass;
          _glassesMessage =
              glassesResult.detected ? "Please remove your glasses" : null;
        });

        if (maskResult.detected) {
          _showRetry("Please remove your mask or face covering.");
          return;
        }
        if (glassesResult.detected) {
          _showRetry("Please remove your glasses or sunglasses.");
          return;
        }
      } else {
        setState(() {
          _maskStatus = CheckStatus.pass;
          _glassesStatus = CheckStatus.pass;
        });
      }

      // All checks passed — get location and return result
      _checkAllPassed();
      setState(() => _mainMessage = "Getting location...");
      final position = await LocationService.getCurrentPosition();

      setState(() => _mainMessage = "Processing...");
      final imageBytes = await File(image.path).readAsBytes();
      var decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        decoded = img.copyResize(decoded, width: 800);
        final compressed = img.encodeJpg(decoded, quality: 85);
        final base64Image = base64Encode(compressed);

        final result = TrustCoreResult(
          base64Image: base64Image,
          latitude: position?.latitude ?? 0.0,
          longitude: position?.longitude ?? 0.0,
          capturedAt: DateTime.now(),
        );

        if (mounted) Navigator.of(context).pop(result);
      }
    } catch (e) {
      _showRetry("Something went wrong. Please try again.");
    }
  }

  void _showRetry(String message) {
    setState(() {
      _retryReason = message;
      _mainMessage = message;
      _isCapturing = false;
      // Reset all statuses so checks re-run from scratch
      _livenessStatus = CheckStatus.pending;
      _singleFaceStatus = CheckStatus.pending;
      _eyesOpenStatus = CheckStatus.pending;
      _maskStatus = CheckStatus.pending;
      _glassesStatus = CheckStatus.pending;
      _faceCoveredStatus = CheckStatus.pending;
      _allChecksPassed = false;
    });

    // Restart stream
    _cameraController!.startImageStream(_onCameraFrame);
    _livenessService.reset();
  }

  List<CheckItem> get _checks => [
        CheckItem(
          label: "Liveness confirmed",
          status: _livenessStatus,
          failMessage: _livenessMessage,
        ),
        CheckItem(
          label: "Single face",
          status: _singleFaceStatus,
          failMessage: _singleFaceMessage,
        ),
        CheckItem(
          label: "Eyes open",
          status: _eyesOpenStatus,
          failMessage: _eyesMessage,
        ),
        CheckItem(
          label: "No mask or covering",
          status: _maskStatus,
          failMessage: _maskMessage,
        ),
        CheckItem(
          label: "No glasses",
          status: _glassesStatus,
          failMessage: _glassesMessage,
        ),
        CheckItem(
          label: "Face not covered",
          status: _faceCoveredStatus,
          failMessage: _faceCoveredMessage,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isCameraReady && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),

          // Oval overlay
          CustomPaint(
            painter: FaceOvalPainter(
              allChecksPassed: _allChecksPassed,
              isCapturing: _isCapturing,
            ),
            size: Size.infinite,
          ),

          // Top bar: close + title
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(null),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withAlpha(110),
                        border:
                            Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "FACE VERIFICATION",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
            ),
          ),

          // Bottom: guidance + checks + capture
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Guidance message — floating, no box
                    Text(
                      _mainMessage,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 10),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),

                    // Check indicators
                    CheckIndicatorPanel(checks: _checks),
                    const SizedBox(height: 22),

                    // Capture button
                    GestureDetector(
                      onTap: _isCapturing ? null : _captureAndProcess,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _livenessStatus == CheckStatus.pass
                              ? Colors.white
                              : Colors.white.withAlpha(35),
                          border: Border.all(
                            color: _livenessStatus == CheckStatus.pass
                                ? const Color(0xFF4ADE80)
                                : Colors.white24,
                            width: 2.0,
                          ),
                          boxShadow: _livenessStatus == CheckStatus.pass
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF4ADE80)
                                        .withAlpha(100),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: _isCapturing
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.black87,
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _livenessStatus == CheckStatus.pass
                          ? "TAP TO CAPTURE"
                          : "BLINK TO UNLOCK",
                      style: TextStyle(
                        color: _livenessStatus == CheckStatus.pass
                            ? Colors.white60
                            : Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _mlKitService.dispose();
    _tfliteService.dispose();
    _livenessService.dispose();
    super.dispose();
  }
}
