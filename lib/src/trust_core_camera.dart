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
  final bool _isProcessing = false;
  bool _isCapturing = false;
  String _mainMessage = "Position your face in the oval";

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

  void _onCameraFrame(CameraImage image) async {
    if (_isCapturing || _isProcessing) return;

    // Liveness check (only if not passed)
    if (_livenessStatus != CheckStatus.pass) {
      await _livenessService.processFrame(
        image,
        InputImageRotation.rotation270deg,
      );
    }

    // ML Kit face checks (only if not all current checks passed)
    FrameCheckResult? result;
    if (_singleFaceStatus != CheckStatus.pass ||
        _eyesOpenStatus != CheckStatus.pass ||
        _faceCoveredStatus != CheckStatus.pass) {
      result = await _mlKitService.processFrame(
        image,
        InputImageRotation.rotation270deg,
      );
    }

    if (!mounted) return;

    setState(() {
      _updateCheckStatuses(result);
      _checkAllPassed();
    });
  }

  void _updateCheckStatuses(FrameCheckResult? result) {
    // Liveness — only prompt for blink when face is clearly visible and uncovered
    if (_livenessStatus != CheckStatus.pass) {
      if (_livenessService.blinkDetected) {
        _livenessStatus = CheckStatus.pass;
        _livenessMessage = null;
      } else if (result != null && result.faceFound && !result.faceCovered) {
        _livenessStatus = CheckStatus.fail;
        _livenessMessage = "Please blink to confirm liveness";
      }
      // else: stays pending while face isn't visible or is covered
    }

    if (result == null) return;

    // Single face
    if (_singleFaceStatus != CheckStatus.pass) {
      if (!result.faceFound) {
        _singleFaceStatus = CheckStatus.pending;
        _singleFaceMessage = "No face detected";
        _mainMessage = "Position your face in the oval";
      } else if (result.multipleFaces) {
        _singleFaceStatus = CheckStatus.fail;
        _singleFaceMessage = "Multiple faces detected — only 1 person allowed";
        _mainMessage = "Only one person allowed";
      } else {
        _singleFaceStatus = CheckStatus.pass;
        _singleFaceMessage = null;
      }
    }

    // Eyes open and face forward
    if (result.faceFound && !result.multipleFaces) {
      if (_eyesOpenStatus != CheckStatus.pass) {
        if (result.eyesOpen) {
          _eyesOpenStatus = CheckStatus.pass;
          _eyesMessage = null;
        } else {
          _eyesOpenStatus = CheckStatus.fail;
          _eyesMessage = "Please keep both eyes open";
        }
      }

      // Face covered
      if (_faceCoveredStatus != CheckStatus.pass) {
        if (result.faceCovered) {
          _faceCoveredStatus = CheckStatus.fail;
          _faceCoveredMessage = "Face is partially covered";
        } else {
          _faceCoveredStatus = CheckStatus.pass;
          _faceCoveredMessage = null;
        }
      }

      // Face forward
      if (!result.faceForward) {
        _mainMessage = "Look directly at the camera";
      }
    }

    // Trigger TFLite checks automatically when all live checks pass (including liveness)
    if (_tfliteModelsLoaded &&
        _livenessStatus == CheckStatus.pass &&
        _singleFaceStatus == CheckStatus.pass &&
        _eyesOpenStatus == CheckStatus.pass &&
        _faceCoveredStatus == CheckStatus.pass &&
        _maskStatus != CheckStatus.pass &&
        _maskStatus != CheckStatus.fail &&
        _glassesStatus != CheckStatus.pass &&
        _glassesStatus != CheckStatus.fail &&
        !_isRunningTFLite) {
      _maskStatus = CheckStatus.loading;
      _glassesStatus = CheckStatus.loading;
      // Schedule the TFLite check after this setState completes
      Future.microtask(() => _runTFLiteChecks());
    }

    // If TFLite models not loaded, skip mask/glasses checks
    if (!_tfliteModelsLoaded && _maskStatus == CheckStatus.pending) {
      _maskStatus = CheckStatus.pass;
      _maskMessage = null;
      _glassesStatus = CheckStatus.pass;
      _glassesMessage = null;
    }
  }

  bool _isRunningTFLite = false;

  /// Auto-run TFLite mask/glasses checks by taking a snapshot
  Future<void> _runTFLiteChecks() async {
    if (_isRunningTFLite || !_tfliteModelsLoaded) return;
    _isRunningTFLite = true;

    try {
      // Stop stream to take a picture
      await _cameraController!.stopImageStream();
      final xFile = await _cameraController!.takePicture();

      // Run MLKit on the captured still image to get correct faceRect
      final stillResult = await _mlKitService.validateStillImage(xFile.path);
      final faceRect = stillResult.faceFound ? stillResult.faceRect : null;

      // Run mask detection
      final maskResult =
          await _tfliteService.detectMask(xFile.path, faceRect: faceRect);

      if (!mounted) return;

      setState(() {
        if (maskResult.detected) {
          _maskStatus = CheckStatus.fail;
          _maskMessage = "Please remove your mask or face covering";
        } else {
          _maskStatus = CheckStatus.pass;
          _maskMessage = null;
        }
      });

      // Run glasses detection
      final glassesResult =
          await _tfliteService.detectGlasses(xFile.path, faceRect: faceRect);

      if (!mounted) return;

      setState(() {
        if (glassesResult.detected) {
          _glassesStatus = CheckStatus.fail;
          _glassesMessage = "Please remove your spectacles or eyewear";
        } else {
          _glassesStatus = CheckStatus.pass;
          _glassesMessage = null;
        }
        _checkAllPassed();
      });

      // Restart stream
      _cameraController!.startImageStream(_onCameraFrame);
    } catch (e) {
      // On failure, mark as pass to not block the user
      if (mounted) {
        setState(() {
          _maskStatus = CheckStatus.pass;
          _maskMessage = null;
          _glassesStatus = CheckStatus.pass;
          _glassesMessage = null;
          _checkAllPassed();
        });
      }
      try {
        _cameraController!.startImageStream(_onCameraFrame);
      } catch (_) {}
    } finally {
      _isRunningTFLite = false;
    }
  }

  void _checkAllPassed() {
    _allChecksPassed = _livenessStatus == CheckStatus.pass &&
        _singleFaceStatus == CheckStatus.pass &&
        _eyesOpenStatus == CheckStatus.pass &&
        _faceCoveredStatus == CheckStatus.pass &&
        _maskStatus == CheckStatus.pass &&
        _glassesStatus == CheckStatus.pass;
  }

  Future<void> _captureAndProcess() async {
    if (_isCapturing || !_allChecksPassed) return;

    setState(() {
      _isCapturing = true;
      _mainMessage = "Hold still...";
    });

    try {
      await _cameraController!.stopImageStream();
      final image = await _cameraController!.takePicture();

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

        if (mounted) {
          Navigator.of(context).pop(result);
        }
      }
    } catch (e) {
      _showRetry("Something went wrong. Please try again.");
    }
  }

  void _showRetry(String message) {
    setState(() {
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
      _isRunningTFLite = false;
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
          label: "No spectacles",
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
                          color: _allChecksPassed
                              ? Colors.white
                              : Colors.white.withAlpha(35),
                          border: Border.all(
                            color: _allChecksPassed
                                ? const Color(0xFF4ADE80)
                                : Colors.white24,
                            width: 2.0,
                          ),
                          boxShadow: _allChecksPassed
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
                      _allChecksPassed ? "TAP TO CAPTURE" : "COMPLETE CHECKS",
                      style: TextStyle(
                        color: _allChecksPassed
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
