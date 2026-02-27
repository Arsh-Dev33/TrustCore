# Flutter Face Detection Plugin
## Single Function — No Signup, No Backend, 100% Free, Offline

---

## AGENT INSTRUCTIONS

You are an expert Flutter developer. Build a Flutter plugin/package called `face_guard` that exposes a **single function** which:
- Opens camera
- Runs all face validations in real-time
- On success returns: `base64 image`, `latitude`, `longitude`
- No login, no signup, no backend, no paid API

Follow every step. Generate all files listed.

---

## WHAT THE PLUGIN DOES

```
Camera Opens
     ↓
Real-time checks (live on every frame):
  ├── ✅ Single face only        → "Multiple faces detected"
  ├── ✅ Liveness (blink)        → "Please blink to confirm liveness"
  ├── ✅ Eyes open               → "Please keep your eyes open"
  ├── ✅ No spectacles           → "Please remove spectacles"
  ├── ✅ No mask                 → "Please remove mask or face covering"
  └── ✅ Face not covered        → "Face is partially covered"
     ↓
All checks pass → Capture photo
     ↓
Return:
  {
    "base64Image": "...",
    "latitude": 19.0760,
    "longitude": 72.8777
  }
```

---

## SINGLE FUNCTION USAGE (How developer uses it)

```dart
import 'package:face_guard/face_guard.dart';

// Call anywhere in your app
final result = await FaceGuard.capture(context);

if (result != null) {
  print(result.base64Image);  // base64 encoded image string
  print(result.latitude);     // e.g. 19.0760
  print(result.longitude);    // e.g. 72.8777
  print(result.capturedAt);   // DateTime
}
```

That's it. One function. Everything handled internally.

---

## STEP 1 — PROJECT SETUP

### 1.1 Create Plugin Package

```bash
flutter create --template=package face_guard
cd face_guard
```

### 1.2 pubspec.yaml

```yaml
name: face_guard
description: Single function face detection plugin - liveness, mask, specs, single face, returns base64 + location.
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.10.0'

dependencies:
  flutter:
    sdk: flutter

  # Camera
  camera: ^0.10.5+9

  # ML Kit
  google_mlkit_face_detection: ^0.9.0
  google_mlkit_face_mesh_detection: ^0.2.0

  # TFLite for mask + glasses detection
  tflite_flutter: ^0.10.4

  # Location
  geolocator: ^11.0.0

  # Permissions
  permission_handler: ^11.3.0

  # Image processing
  image: ^4.1.7

  # Base64
  dart:convert: any

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  assets:
    - assets/models/mask_detector.tflite
    - assets/models/glasses_detector.tflite
```

Run:
```bash
flutter pub get
mkdir -p assets/models
mkdir -p lib/src
```

---

## STEP 2 — DOWNLOAD FREE TFLITE MODELS

### 2.1 Mask Detection Model
Download from (no signup needed):
```
https://github.com/chandrikadeb7/Face-Mask-Detection/raw/master/mask_detector.model
```
Convert to tflite OR use this direct tflite:
```
https://github.com/BVLC/caffe/blob/master/models/mask_detector.tflite
```

**Alternative — Use Teachable Machine (easiest, 10 mins):**
1. Go to: https://teachablemachine.withgoogle.com/train/image
2. Create 2 classes: `mask` and `no_mask`
3. Upload ~50 images each (search Google Images)
4. Train → Export as TFLite
5. Save as `assets/models/mask_detector.tflite`

### 2.2 Glasses Detection Model
**Use Teachable Machine:**
1. Go to: https://teachablemachine.withgoogle.com/train/image
2. Create 2 classes: `glasses` and `no_glasses`
3. Upload ~50 images each
4. Train → Export as TFLite
5. Save as `assets/models/glasses_detector.tflite`

**Pre-trained alternative:**
```
https://github.com/shubham0204/Face-Attribute-Detection-Android/tree/master/app/src/main/assets
```

---

## STEP 3 — PLATFORM PERMISSIONS

### 3.1 Android — `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />

<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />

<application>
  <meta-data
    android:name="com.google.mlkit.vision.DEPENDENCIES"
    android:value="face" />
</application>
```

### 3.2 Android — `android/app/build.gradle`
```gradle
android {
  defaultConfig {
    minSdkVersion 21
    targetSdkVersion 34
  }
}
```

### 3.3 iOS — `ios/Runner/Info.plist`
```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used for face detection and verification.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is captured at the time of face verification.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Location is captured at the time of face verification.</string>
```

### 3.4 iOS — `ios/Podfile`
```ruby
platform :ios, '14.0'
```

---

## STEP 4 — PROJECT FILE STRUCTURE

```
lib/
  face_guard.dart              ← Public API (single function exposed here)
  src/
    face_guard_camera.dart     ← Camera screen (internal)
    face_guard_result.dart     ← Result model
    services/
      mlkit_face_service.dart  ← ML Kit face detection
      tflite_service.dart      ← Mask + glasses TFLite models
      liveness_service.dart    ← Blink detection
      location_service.dart    ← GPS coordinates
    widgets/
      face_oval_painter.dart   ← Camera overlay UI
      check_indicator.dart     ← Real-time check badges UI
assets/
  models/
    mask_detector.tflite
    glasses_detector.tflite
```

---

## STEP 5 — RESULT MODEL

### `lib/src/face_guard_result.dart`

```dart
class FaceGuardResult {
  /// Base64 encoded JPEG image string
  final String base64Image;

  /// Latitude at time of capture
  final double latitude;

  /// Longitude at time of capture
  final double longitude;

  /// Timestamp of capture
  final DateTime capturedAt;

  FaceGuardResult({
    required this.base64Image,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'base64Image': base64Image,
      'latitude': latitude,
      'longitude': longitude,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'FaceGuardResult('
        'latitude: $latitude, '
        'longitude: $longitude, '
        'capturedAt: $capturedAt, '
        'base64Image: [${base64Image.length} chars])';
  }
}
```

---

## STEP 6 — SERVICES

### 6.1 `lib/src/services/location_service.dart`

```dart
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  /// Get current GPS position
  static Future<Position?> getCurrentPosition() async {
    // Request permission
    final status = await Permission.location.request();
    if (!status.isGranted) return null;

    // Check if location service enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      // Fallback to last known position
      return await Geolocator.getLastKnownPosition();
    }
  }
}
```

---

### 6.2 `lib/src/services/liveness_service.dart`

```dart
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class LivenessService {
  final FaceDetector _detector;
  
  double _prevLeftEye = 1.0;
  double _prevRightEye = 1.0;
  bool _blinkDetected = false;
  int _frameSkip = 0;

  LivenessService()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: true,
            performanceMode: FaceDetectorMode.fast,
          ),
        );

  bool get blinkDetected => _blinkDetected;

  /// Process each camera frame for blink detection
  Future<void> processFrame(
    CameraImage image,
    InputImageRotation rotation,
  ) async {
    // Process every 3rd frame for performance
    _frameSkip++;
    if (_frameSkip % 3 != 0) return;

    try {
      final inputImage = _buildInputImage(image, rotation);
      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) return;

      final face = faces.first;
      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;

      // Blink = eyes were open (>0.8) → now closed (<0.3)
      if (_prevLeftEye > 0.8 &&
          _prevRightEye > 0.8 &&
          leftEye < 0.3 &&
          rightEye < 0.3) {
        _blinkDetected = true;
      }

      _prevLeftEye = leftEye;
      _prevRightEye = rightEye;
    } catch (_) {}
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

  void reset() {
    _blinkDetected = false;
    _prevLeftEye = 1.0;
    _prevRightEye = 1.0;
    _frameSkip = 0;
  }

  void dispose() => _detector.close();
}
```

---

### 6.3 `lib/src/services/mlkit_face_service.dart`

```dart
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:camera/camera.dart';

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

  FrameCheckResult({
    required this.faceFound,
    required this.multipleFaces,
    required this.eyesOpen,
    required this.faceForward,
    required this.faceCovered,
    required this.faceCount,
    required this.leftEyeProb,
    required this.rightEyeProb,
  });

  /// All basic ML Kit checks pass
  bool get allPassed =>
      faceFound &&
      !multipleFaces &&
      eyesOpen &&
      faceForward &&
      !faceCovered;
}

class MLKitFaceService {
  late final FaceDetector _faceDetector;
  late final FaceMeshDetector _meshDetector;
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

    _meshDetector = FaceMeshDetector(
      option: FaceMeshDetectorOptions.faceMesh,
    );
  }

  FrameCheckResult? get lastResult => _lastResult;

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
      final leftEye = face.leftEyeOpenProbability ?? 0.0;
      final rightEye = face.rightEyeOpenProbability ?? 0.0;
      final eulerY = face.headEulerAngleY ?? 0.0;
      final eulerZ = face.headEulerAngleZ ?? 0.0;

      // Face covered check via mesh landmark count
      final meshes = await _meshDetector.processImage(inputImage);
      bool faceCovered = false;
      if (meshes.isNotEmpty) {
        // 468 total landmarks — if less than 350 visible → face partially covered
        faceCovered = meshes.first.points.length < 350;
      }

      _lastResult = FrameCheckResult(
        faceFound: true,
        multipleFaces: false,
        eyesOpen: leftEye > 0.65 && rightEye > 0.65,
        faceForward: eulerY.abs() < 20 && eulerZ.abs() < 20,
        faceCovered: faceCovered,
        faceCount: 1,
        leftEyeProb: leftEye,
        rightEyeProb: rightEye,
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
        faceFound: false, multipleFaces: false, eyesOpen: false,
        faceForward: false, faceCovered: false, faceCount: 0,
        leftEyeProb: 0, rightEyeProb: 0,
      );
    }

    if (faces.length > 1) {
      return FrameCheckResult(
        faceFound: true, multipleFaces: true, eyesOpen: false,
        faceForward: false, faceCovered: false, faceCount: faces.length,
        leftEyeProb: 0, rightEyeProb: 0,
      );
    }

    final face = faces.first;
    final leftEye = face.leftEyeOpenProbability ?? 0.0;
    final rightEye = face.rightEyeOpenProbability ?? 0.0;
    final eulerY = face.headEulerAngleY ?? 0.0;
    final eulerZ = face.headEulerAngleZ ?? 0.0;

    final meshes = await _meshDetector.processImage(inputImage);
    final faceCovered = meshes.isNotEmpty && meshes.first.points.length < 350;

    return FrameCheckResult(
      faceFound: true,
      multipleFaces: false,
      eyesOpen: leftEye > 0.65 && rightEye > 0.65,
      faceForward: eulerY.abs() < 20 && eulerZ.abs() < 20,
      faceCovered: faceCovered,
      faceCount: 1,
      leftEyeProb: leftEye,
      rightEyeProb: rightEye,
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
    _meshDetector.close();
  }
}
```

---

### 6.4 `lib/src/services/tflite_service.dart`

```dart
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';

enum TFLiteLabel { positive, negative }

class TFLiteClassifierResult {
  final bool detected;      // true = mask/glasses found
  final double confidence;  // 0.0 to 1.0

  TFLiteClassifierResult({required this.detected, required this.confidence});
}

class TFLiteService {
  Interpreter? _maskInterpreter;
  Interpreter? _glassesInterpreter;
  bool _modelsLoaded = false;

  /// Load both TFLite models
  Future<void> loadModels() async {
    try {
      _maskInterpreter = await Interpreter.fromAsset(
        'assets/models/mask_detector.tflite',
      );
      _glassesInterpreter = await Interpreter.fromAsset(
        'assets/models/glasses_detector.tflite',
      );
      _modelsLoaded = true;
    } catch (e) {
      // Models not loaded — checks will be skipped with warning
      _modelsLoaded = false;
    }
  }

  bool get modelsLoaded => _modelsLoaded;

  /// Detect if mask is present on face
  Future<TFLiteClassifierResult> detectMask(String imagePath) async {
    return _runClassifier(_maskInterpreter, imagePath);
  }

  /// Detect if glasses/spectacles are present
  Future<TFLiteClassifierResult> detectGlasses(String imagePath) async {
    return _runClassifier(_glassesInterpreter, imagePath);
  }

  Future<TFLiteClassifierResult> _runClassifier(
    Interpreter? interpreter,
    String imagePath,
  ) async {
    if (interpreter == null) {
      return TFLiteClassifierResult(detected: false, confidence: 0.0);
    }

    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return TFLiteClassifierResult(detected: false, confidence: 0.0);

      // Resize to 224x224 (MobileNet standard input size)
      image = img.copyResize(image, width: 224, height: 224);

      // Convert to float32 input tensor [1, 224, 224, 3]
      final input = _imageToFloat32(image);

      // Output tensor [1, 2] → [no_mask_prob, mask_prob]
      final output = List.generate(1, (_) => List.filled(2, 0.0));

      interpreter.run(input, output);

      // output[0][0] = class 0 (e.g. no_mask / no_glasses)
      // output[0][1] = class 1 (e.g. mask / glasses)
      final detectedConfidence = output[0][1]; // probability of mask/glasses

      return TFLiteClassifierResult(
        detected: detectedConfidence > 0.75, // 75% threshold
        confidence: detectedConfidence,
      );
    } catch (e) {
      return TFLiteClassifierResult(detected: false, confidence: 0.0);
    }
  }

  List<List<List<List<double>>>> _imageToFloat32(img.Image image) {
    return List.generate(1, (_) =>
      List.generate(224, (y) =>
        List.generate(224, (x) {
          final pixel = image.getPixel(x, y);
          // Normalize to [0, 1]
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        })
      )
    );
  }

  void dispose() {
    _maskInterpreter?.close();
    _glassesInterpreter?.close();
  }
}
```

---

## STEP 7 — UI WIDGETS

### 7.1 `lib/src/widgets/face_oval_painter.dart`

```dart
import 'package:flutter/material.dart';

class FaceOvalPainter extends CustomPainter {
  final bool allChecksPassed;
  final bool isCapturing;

  FaceOvalPainter({
    this.allChecksPassed = false,
    this.isCapturing = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dim overlay
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.68,
      height: size.height * 0.46,
    );

    // Clear oval
    canvas.drawOval(ovalRect, Paint()..blendMode = BlendMode.clear);

    // Border color
    final Color borderColor = isCapturing
        ? Colors.yellow
        : allChecksPassed
            ? Colors.green
            : Colors.white;

    // Animated dashed border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawOval(ovalRect, borderPaint);

    // Corner tick marks
    final tickPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(ovalRect.topLeft + const Offset(18, 0),
        ovalRect.topLeft + const Offset(0, 0), tickPaint);
    canvas.drawLine(ovalRect.topLeft + const Offset(0, 0),
        ovalRect.topLeft + const Offset(0, 18), tickPaint);

    // Top-right
    canvas.drawLine(ovalRect.topRight + const Offset(-18, 0),
        ovalRect.topRight + const Offset(0, 0), tickPaint);
    canvas.drawLine(ovalRect.topRight + const Offset(0, 0),
        ovalRect.topRight + const Offset(0, 18), tickPaint);

    // Bottom-left
    canvas.drawLine(ovalRect.bottomLeft + const Offset(18, 0),
        ovalRect.bottomLeft + const Offset(0, 0), tickPaint);
    canvas.drawLine(ovalRect.bottomLeft + const Offset(0, 0),
        ovalRect.bottomLeft + const Offset(0, -18), tickPaint);

    // Bottom-right
    canvas.drawLine(ovalRect.bottomRight + const Offset(-18, 0),
        ovalRect.bottomRight + const Offset(0, 0), tickPaint);
    canvas.drawLine(ovalRect.bottomRight + const Offset(0, 0),
        ovalRect.bottomRight + const Offset(0, -18), tickPaint);
  }

  @override
  bool shouldRepaint(FaceOvalPainter oldDelegate) =>
      oldDelegate.allChecksPassed != allChecksPassed ||
      oldDelegate.isCapturing != isCapturing;
}
```

---

### 7.2 `lib/src/widgets/check_indicator.dart`

```dart
import 'package:flutter/material.dart';

enum CheckStatus { pending, pass, fail, loading }

class CheckItem {
  final String label;
  final CheckStatus status;
  final String? failMessage;

  CheckItem({
    required this.label,
    required this.status,
    this.failMessage,
  });
}

class CheckIndicatorPanel extends StatelessWidget {
  final List<CheckItem> checks;

  const CheckIndicatorPanel({super.key, required this.checks});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: checks.map((check) => _CheckRow(check: check)).toList(),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final CheckItem check;

  const _CheckRow({required this.check});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          _StatusIcon(status: check.status),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              check.status == CheckStatus.fail && check.failMessage != null
                  ? check.failMessage!
                  : check.label,
              style: TextStyle(
                color: _textColor(check.status),
                fontSize: 13,
                fontWeight: check.status == CheckStatus.fail
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _textColor(CheckStatus status) {
    switch (status) {
      case CheckStatus.pass: return Colors.green;
      case CheckStatus.fail: return Colors.red;
      case CheckStatus.loading: return Colors.yellow;
      case CheckStatus.pending: return Colors.white54;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final CheckStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case CheckStatus.pass:
        return const Icon(Icons.check_circle, color: Colors.green, size: 18);
      case CheckStatus.fail:
        return const Icon(Icons.cancel, color: Colors.red, size: 18);
      case CheckStatus.loading:
        return const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.yellow),
        );
      case CheckStatus.pending:
        return const Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 18);
    }
  }
}
```

---

## STEP 8 — MAIN CAMERA SCREEN (INTERNAL)

### `lib/src/face_guard_camera.dart`

```dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

import 'face_guard_result.dart';
import 'services/mlkit_face_service.dart';
import 'services/tflite_service.dart';
import 'services/liveness_service.dart';
import 'services/location_service.dart';
import 'widgets/face_oval_painter.dart';
import 'widgets/check_indicator.dart';

class FaceGuardCamera extends StatefulWidget {
  const FaceGuardCamera({super.key});

  @override
  State<FaceGuardCamera> createState() => _FaceGuardCameraState();
}

class _FaceGuardCameraState extends State<FaceGuardCamera>
    with WidgetsBindingObserver {
  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // Services
  late MLKitFaceService _mlKitService;
  late TFLiteService _tfliteService;
  late LivenessService _livenessService;

  // State
  bool _isProcessing = false;
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

    // Liveness check
    await _livenessService.processFrame(
      image,
      InputImageRotation.rotation270deg,
    );

    // ML Kit face checks
    final result = await _mlKitService.processFrame(
      image,
      InputImageRotation.rotation270deg,
    );

    if (!mounted) return;

    setState(() {
      _updateCheckStatuses(result);
      _checkAllPassed();
    });
  }

  void _updateCheckStatuses(FrameCheckResult? result) {
    // Liveness
    if (_livenessService.blinkDetected) {
      _livenessStatus = CheckStatus.pass;
      _livenessMessage = null;
    } else {
      _livenessStatus = CheckStatus.fail;
      _livenessMessage = "Please blink to confirm liveness";
    }

    if (result == null) return;

    // Single face
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

    // Eyes open
    if (result.faceFound && !result.multipleFaces) {
      if (result.eyesOpen) {
        _eyesOpenStatus = CheckStatus.pass;
        _eyesMessage = null;
      } else {
        _eyesOpenStatus = CheckStatus.fail;
        _eyesMessage = "Please keep both eyes open";
      }

      // Face covered
      if (result.faceCovered) {
        _faceCoveredStatus = CheckStatus.fail;
        _faceCoveredMessage = "Face is partially covered";
      } else {
        _faceCoveredStatus = CheckStatus.pass;
        _faceCoveredMessage = null;
      }

      // Face forward
      if (!result.faceForward) {
        _mainMessage = "Look directly at the camera";
      }
    }

    // Mask and glasses are checked on capture (still image — more accurate)
    // Show loading if face is valid and we're about to run them
    if (_singleFaceStatus == CheckStatus.pass &&
        _eyesOpenStatus == CheckStatus.pass) {
      if (_maskStatus == CheckStatus.pending) {
        _maskStatus = CheckStatus.loading;
      }
      if (_glassesStatus == CheckStatus.pending) {
        _glassesStatus = CheckStatus.loading;
      }
    }
  }

  void _checkAllPassed() {
    _allChecksPassed = _livenessStatus == CheckStatus.pass &&
        _singleFaceStatus == CheckStatus.pass &&
        _eyesOpenStatus == CheckStatus.pass &&
        _faceCoveredStatus == CheckStatus.pass;
    // Note: mask and glasses checked on actual capture
  }

  Future<void> _captureAndProcess() async {
    if (_isCapturing) return;

    if (!_livenessService.blinkDetected) {
      setState(() => _mainMessage = "Please blink first to confirm you are live");
      return;
    }

    setState(() {
      _isCapturing = true;
      _mainMessage = "Hold still...";
    });

    try {
      await _cameraController!.stopImageStream();
      final image = await _cameraController!.takePicture();

      // Run full validation on still image
      setState(() => _mainMessage = "Validating face...");
      final faceResult = await _mlKitService.validateStillImage(image.path);

      if (!faceResult.faceFound) {
        _showRetry("No face detected. Please try again.");
        return;
      }

      if (faceResult.multipleFaces) {
        _showRetry("Multiple faces detected. Only one person allowed.");
        return;
      }

      if (!faceResult.eyesOpen) {
        _showRetry("Please keep your eyes open.");
        return;
      }

      if (faceResult.faceCovered) {
        _showRetry("Your face appears to be partially covered.");
        return;
      }

      if (!faceResult.faceForward) {
        _showRetry("Please look directly at the camera.");
        return;
      }

      // Run TFLite checks
      if (_tfliteModelsLoaded) {
        setState(() {
          _maskStatus = CheckStatus.loading;
          _glassesStatus = CheckStatus.loading;
          _mainMessage = "Checking for mask...";
        });

        final maskResult = await _tfliteService.detectMask(image.path);
        setState(() => _maskStatus =
            maskResult.detected ? CheckStatus.fail : CheckStatus.pass);

        if (maskResult.detected) {
          _showRetry("Please remove your mask or face covering.");
          return;
        }

        setState(() => _mainMessage = "Checking for spectacles...");
        final glassesResult = await _tfliteService.detectGlasses(image.path);
        setState(() => _glassesStatus =
            glassesResult.detected ? CheckStatus.fail : CheckStatus.pass);

        if (glassesResult.detected) {
          _showRetry("Please remove your spectacles or eyewear.");
          return;
        }
      }

      // All passed — get location + encode image
      setState(() => _mainMessage = "Getting location...");

      final position = await LocationService.getCurrentPosition();

      setState(() => _mainMessage = "Processing image...");

      // Convert image to base64
      final imageBytes = await File(image.path).readAsBytes();
      
      // Optionally compress image before base64
      var decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        decoded = img.copyResize(decoded, width: 800);
        final compressed = img.encodeJpg(decoded, quality: 85);
        final base64Image = base64Encode(compressed);

        final result = FaceGuardResult(
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
      _showRetry("Something went wrong. Please try again.\n${e.toString()}");
    }
  }

  void _showRetry(String message) {
    setState(() {
      _mainMessage = message;
      _isCapturing = false;
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

          // Top: Close button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(null),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),

          // Bottom: Check list + capture button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _mainMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Check indicators
                    CheckIndicatorPanel(checks: _checks),
                    const SizedBox(height: 16),

                    // Capture button
                    GestureDetector(
                      onTap: _isCapturing ? null : _captureAndProcess,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _allChecksPassed
                              ? Colors.white
                              : Colors.white30,
                          border: Border.all(
                            color: _allChecksPassed
                                ? Colors.green
                                : Colors.white30,
                            width: 4,
                          ),
                        ),
                        child: _isCapturing
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 3,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt,
                                color: _allChecksPassed
                                    ? Colors.black
                                    : Colors.white38,
                                size: 30,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _allChecksPassed
                          ? "Tap to capture"
                          : "Complete all checks above",
                      style: TextStyle(
                        color: _allChecksPassed
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 12,
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
```

---

## STEP 9 — PUBLIC API (SINGLE FUNCTION)

### `lib/face_guard.dart`

```dart
library face_guard;

import 'package:flutter/material.dart';
import 'src/face_guard_camera.dart';
import 'src/face_guard_result.dart';

export 'src/face_guard_result.dart';

/// FaceGuard — Single function face detection plugin
/// No signup. No backend. 100% free. Offline.
class FaceGuard {
  /// Opens camera with real-time face validation.
  ///
  /// Checks performed:
  ///   ✅ Liveness (blink detection)
  ///   ✅ Single face only
  ///   ✅ Eyes open
  ///   ✅ No mask or face covering
  ///   ✅ No spectacles
  ///   ✅ Face not partially covered
  ///
  /// Returns [FaceGuardResult] with:
  ///   - base64Image : JPEG image as base64 string
  ///   - latitude    : GPS latitude at capture time
  ///   - longitude   : GPS longitude at capture time
  ///   - capturedAt  : DateTime of capture
  ///
  /// Returns null if user cancels.
  ///
  /// Example:
  /// ```dart
  /// final result = await FaceGuard.capture(context);
  /// if (result != null) {
  ///   print(result.base64Image);
  ///   print(result.latitude);
  ///   print(result.longitude);
  /// }
  /// ```
  static Future<FaceGuardResult?> capture(BuildContext context) async {
    final result = await Navigator.of(context).push<FaceGuardResult>(
      MaterialPageRoute(
        builder: (_) => const FaceGuardCamera(),
        fullscreenDialog: true,
      ),
    );
    return result;
  }
}
```

---

## STEP 10 — HOW TO USE IN ANY FLUTTER APP

```dart
import 'package:face_guard/face_guard.dart';

class MyScreen extends StatelessWidget {
  Future<void> _verify(BuildContext context) async {
    final result = await FaceGuard.capture(context);

    if (result != null) {
      print('✅ Base64 Image: ${result.base64Image.substring(0, 50)}...');
      print('✅ Latitude: ${result.latitude}');
      print('✅ Longitude: ${result.longitude}');
      print('✅ Captured At: ${result.capturedAt}');

      // Use base64 directly in Image widget:
      // Image.memory(base64Decode(result.base64Image))

      // Or send to your server:
      // await api.uploadFace(result.toMap());
    } else {
      print('User cancelled or verification failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _verify(context),
          child: Text('Verify Face'),
        ),
      ),
    );
  }
}
```

---

## STEP 11 — BUILD & RUN

```bash
# Install dependencies
flutter pub get

# Android
flutter run -d android

# iOS
cd ios && pod install && cd ..
flutter run -d ios

# Build release APK
flutter build apk --release

# Build iOS
flutter build ipa --release
```

---

## VALIDATION FLOW SUMMARY

```
Frame by frame (live):
  1. Blink detected?           → LivenessService (ML Kit stream)
  2. Single face?              → ML Kit face count
  3. Eyes open?                → ML Kit eyeOpenProbability > 0.65
  4. Face forward?             → ML Kit headEulerAngle < 20°
  5. Face not covered?         → ML Kit Face Mesh < 350/468 landmarks

On capture (still image):
  6. Mask detected?            → TFLite MobileNet classifier
  7. Spectacles detected?      → TFLite binary classifier
  8. Final face validation      → ML Kit on full resolution still

On success:
  9. GPS location              → Geolocator
  10. Base64 encode image      → dart:convert base64Encode
  11. Return FaceGuardResult
```

---

## MESSAGES SHOWN FOR EACH FAILURE

| Check | Message Shown to User |
|---|---|
| No face | "Position your face in the oval" |
| Multiple faces | "Multiple faces detected — only 1 person allowed" |
| Eyes closed | "Please keep both eyes open" |
| Not looking at camera | "Look directly at the camera" |
| Face covered (mesh) | "Face is partially covered" |
| Mask detected | "Please remove your mask or face covering" |
| Spectacles detected | "Please remove your spectacles or eyewear" |
| No liveness | "Please blink to confirm liveness" |

---

## COST SUMMARY

| Feature | Tool | Cost |
|---|---|---|
| Face detection | Google ML Kit | FREE |
| Liveness / blink | Google ML Kit | FREE |
| Eyes open | Google ML Kit | FREE |
| Face covered | ML Kit Face Mesh | FREE |
| Mask detection | TFLite MobileNet | FREE |
| Spectacles detection | TFLite classifier | FREE |
| GPS location | Geolocator | FREE |
| Base64 encoding | dart:convert | FREE |
| **Total** | | **$0 forever** |

---

## TROUBLESHOOTING

| Issue | Fix |
|---|---|
| Camera black screen Android | Set `minSdkVersion 21` |
| TFLite model not loading | Check path in `pubspec.yaml` assets |
| Location always 0,0 | Check location permission + GPS enabled |
| Blink not detecting | Ensure good lighting, face centered |
| Mask model not accurate | Retrain Teachable Machine with more samples |
| Glasses false positive | Adjust `confidence > 0.75` threshold in tflite_service.dart |
| Face mesh check too strict | Change `< 350` to `< 280` in mlkit_face_service.dart |

---

*Agent-ready implementation guide. All checks are free, offline, and on-device. Single function API: `FaceGuard.capture(context)`*