# FaceVerify Flutter Library — Complete Development Guide
## Reusable Package for On-Device Face Registration & Verification

---

## AGENT INSTRUCTIONS

You are an expert Flutter developer. Your task is to build a **reusable Flutter package** for face verification using **Google ML Kit only** (no paid APIs). Follow every step precisely. Generate all files listed. Do not skip any section.

---

## LIBRARY OVERVIEW

**Package Name:** face_verify  
**Platform:** Flutter (Android + iOS)  
**Face Detection:** Google ML Kit (on-device, free, offline)  
**Face Matching:** ML Kit contour coordinates + cosine similarity  
**Storage:** SQLite (sqflite) + local file system  
**No backend required. No paid API required.**

### Two Modes
| Mode | Description |
|------|-------------|
| **Signup** | Opens camera → validates face → stores locally → returns base64 image + transaction ID |
| **Verification** | Host sends base64 reference image → opens camera → captures live photo → compares → returns pass/fail + match % |

### Public API Summary
```dart
final fv = FaceVerify();

// Signup
final result = await fv.signup(context: context, userId: 'user_123');
// result.success, result.imageBase64, result.transactionId

// Verify
final result = await fv.verify(
  context: context, userId: 'user_123',
  referenceImageBase64: base64FromServer,
);
// result.passed, result.matchPercent, result.verdict, result.capturedBase64, result.transactionId
```

---

## STEP 1 — CREATE FLUTTER PACKAGE

```bash
flutter create --template=package face_verify
cd face_verify
```

### 1.1 pubspec.yaml

Replace the entire `pubspec.yaml` with:

```yaml
name: face_verify
description: On-device face registration & verification library using Google ML Kit.
version: 1.0.0

environment:
  sdk: ^3.6.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  camera: ^0.11.1
  google_mlkit_face_detection: ^0.12.0
  sqflite: ^2.4.2
  path_provider: ^2.1.5
  path: ^1.9.1
  permission_handler: ^11.4.0
  image: ^4.5.3
  vector_math: ^2.1.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

Run:
```bash
flutter pub get
```

---

## STEP 2 — DIRECTORY STRUCTURE

Create the following directory structure inside `lib/`:

```
lib/
  face_verify_lib.dart          ← barrel export (public API)
  src/
    face_verify.dart            ← main FaceVerify class
    config.dart                 ← FaceVerifyConfig
    models/
      face_verify_error.dart
      signup_result.dart
      verify_result.dart
      match_result.dart
      face_record.dart
      face_validation_result.dart
    services/
      face_detection_service.dart
      face_matcher_service.dart
      face_storage_service.dart
      liveness_service.dart
      base64_service.dart
      transaction_service.dart
    ui/
      signup_screen.dart
      lib_verify_screen.dart
      widgets/
        face_oval_painter.dart
        status_banner.dart
    utils/
      vector_utils.dart
      image_utils.dart
example/
  lib/main.dart                 ← demo app
```

Create all directories:
```bash
mkdir -p lib/src/models lib/src/services lib/src/ui/widgets lib/src/utils example/lib
```

---

## STEP 3 — MODELS

### 3.1 `lib/src/models/face_verify_error.dart`

```dart
/// Error types returned by FaceVerify operations.
enum FaceVerifyError {
  noFaceDetected,
  multipleFaces,
  eyesClosed,
  notLookingAtCamera,
  tooFarFromCamera,
  livenessCheckFailed,
  livenessTimeout,
  cameraPermissionDenied,
  userCancelled,
  noReferenceImage,
  invalidReferenceImage,
  internalError,
}
```

### 3.2 `lib/src/models/signup_result.dart`

```dart
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
      success: true, transactionId: transactionId,
      imageBase64: imageBase64, message: message,
      timestamp: DateTime.now().toUtc(),
    );
  }

  factory SignupResult.failure({
    required String transactionId,
    required String message,
    required FaceVerifyError error,
  }) {
    return SignupResult(
      success: false, transactionId: transactionId,
      message: message, timestamp: DateTime.now().toUtc(), error: error,
    );
  }
}
```

### 3.3 `lib/src/models/verify_result.dart`

```dart
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
      passed: passed, transactionId: transactionId,
      matchPercent: matchPercent, verdict: verdict,
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
      passed: false, transactionId: transactionId,
      matchPercent: 0.0, verdict: 'Error',
      message: message, timestamp: DateTime.now().toUtc(), error: error,
    );
  }
}
```

### 3.4 `lib/src/models/match_result.dart`

```dart
class MatchResult {
  final double similarityPercent;
  final bool isMatch;
  final String verdict;

  MatchResult({
    required this.similarityPercent,
    required this.isMatch,
    required this.verdict,
  });

  static String _getVerdict(double percent) {
    if (percent >= 90) return "Strong Match";
    if (percent >= 80) return "Good Match";
    if (percent >= 70) return "Weak Match";
    return "No Match";
  }

  factory MatchResult.fromSimilarity(double percent) {
    return MatchResult(
      similarityPercent: percent,
      isMatch: percent >= 75.0,
      verdict: _getVerdict(percent),
    );
  }
}
```

### 3.5 `lib/src/models/face_record.dart`

```dart
class FaceRecord {
  final int? id;
  final String userId;
  final String imagePath;
  final List<double> embedding;
  final DateTime registeredAt;

  FaceRecord({
    this.id,
    required this.userId,
    required this.imagePath,
    required this.embedding,
    required this.registeredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'image_path': imagePath,
      'embedding': embedding.join(','),
      'registered_at': registeredAt.toIso8601String(),
    };
  }

  factory FaceRecord.fromMap(Map<String, dynamic> map) {
    return FaceRecord(
      id: map['id'],
      userId: map['user_id'],
      imagePath: map['image_path'],
      embedding: (map['embedding'] as String).split(',').map(double.parse).toList(),
      registeredAt: DateTime.parse(map['registered_at']),
    );
  }
}
```

### 3.6 `lib/src/models/face_validation_result.dart`

```dart
enum ValidationError {
  noFace, multipleFaces, eyesClosed, lookingAway,
  tooFar, tooClose, eyewearDetected, fakeFace, none,
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
    this.leftEyeOpenProb, this.rightEyeOpenProb,
    this.headEulerY, this.headEulerZ, this.embedding,
  });

  factory FaceValidationResult.invalid(String message, ValidationError error) {
    return FaceValidationResult(isValid: false, message: message, error: error);
  }
}
```

---

## STEP 4 — UTILITIES

### 4.1 `lib/src/utils/vector_utils.dart`

```dart
import 'dart:math';

class VectorUtils {
  static double cosineSimilarity(List<double> a, List<double> b) {
    assert(a.length == b.length, 'Vectors must be same length');
    double dotProduct = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  static List<double> normalize(List<double> v) {
    double norm = sqrt(v.fold(0.0, (sum, x) => sum + x * x));
    if (norm == 0.0) return v;
    return v.map((x) => x / norm).toList();
  }

  static double similarityToPercent(double similarity) {
    return ((similarity + 1.0) / 2.0 * 100.0).clamp(0.0, 100.0);
  }

  static double euclideanDistance(List<double> a, List<double> b) {
    double sum = 0.0;
    for (int i = 0; i < a.length && i < b.length; i++) {
      sum += (a[i] - b[i]) * (a[i] - b[i]);
    }
    return sqrt(sum);
  }
}
```

### 4.2 `lib/src/utils/image_utils.dart`

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageUtils {
  static Future<String> saveImage(String sourcePath, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = path.join(dir.path, 'faces', fileName);
    await Directory(path.dirname(dest)).create(recursive: true);
    await File(sourcePath).copy(dest);
    return dest;
  }

  static Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }
}
```

---

## STEP 5 — SERVICES

### 5.1 `lib/src/services/face_detection_service.dart`

```dart
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
        "No face detected. Please center your face.", ValidationError.noFace);
    }
    if (faces.length > 1) {
      return FaceValidationResult.invalid(
        "Multiple faces detected. Only one person allowed.", ValidationError.multipleFaces);
    }

    final face = faces.first;
    final leftEye = face.leftEyeOpenProbability ?? 0.0;
    final rightEye = face.rightEyeOpenProbability ?? 0.0;
    if (leftEye < 0.65 || rightEye < 0.65) {
      return FaceValidationResult.invalid(
        "Please keep both eyes open.", ValidationError.eyesClosed);
    }

    final eulerY = face.headEulerAngleY ?? 0.0;
    final eulerZ = face.headEulerAngleZ ?? 0.0;
    if (eulerY.abs() > 20.0 || eulerZ.abs() > 20.0) {
      return FaceValidationResult.invalid(
        "Please look directly at the camera.", ValidationError.lookingAway);
    }

    final faceArea = face.boundingBox.width * face.boundingBox.height;
    if (faceArea < 10000) {
      return FaceValidationResult.invalid(
        "Move closer to the camera.", ValidationError.tooFar);
    }

    final embedding = _extractEmbedding(face);
    return FaceValidationResult(
      isValid: true, message: "Face validated successfully!",
      leftEyeOpenProb: leftEye, rightEyeOpenProb: rightEye,
      headEulerY: eulerY, headEulerZ: eulerZ, embedding: embedding,
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
      features.addAll([box.left, box.top, box.right, box.bottom, box.width, box.height]);
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

  void dispose() { _detector.close(); }
}
```

### 5.2 `lib/src/services/liveness_service.dart`

```dart
import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class LivenessService {
  final FaceDetector _detector;
  bool _blinkDetected = false;
  double _previousLeftEye = 1.0;
  double _previousRightEye = 1.0;
  int _frameCount = 0;

  LivenessService()
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

  Future<bool> processFrame(CameraImage cameraImage, InputImageRotation rotation) async {
    _frameCount++;
    if (_frameCount % 3 != 0) { return _blinkDetected; }

    final bytesBuilder = BytesBuilder();
    for (final Plane plane in cameraImage.planes) { bytesBuilder.add(plane.bytes); }
    final bytes = bytesBuilder.toBytes();

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      ),
    );

    try {
      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) return _blinkDetected;
      final face = faces.first;
      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;
      if (_previousLeftEye > 0.75 && _previousRightEye > 0.75) {
        if (leftEye < 0.3 && rightEye < 0.3) { _blinkDetected = true; }
      }
      _previousLeftEye = leftEye;
      _previousRightEye = rightEye;
    } catch (_) {}
    return _blinkDetected;
  }

  void reset() { _blinkDetected = false; _previousLeftEye = 1.0; _previousRightEye = 1.0; _frameCount = 0; }
  void dispose() { _detector.close(); }
}
```

### 5.3 `lib/src/services/face_matcher_service.dart`

```dart
import '../utils/vector_utils.dart';
import '../models/match_result.dart';

class FaceMatcherService {
  MatchResult compareFaces(List<double> storedEmbedding, List<double> newEmbedding) {
    if (storedEmbedding.isEmpty || newEmbedding.isEmpty) {
      return MatchResult.fromSimilarity(0.0);
    }
    final maxLen = storedEmbedding.length > newEmbedding.length
        ? storedEmbedding.length : newEmbedding.length;
    List<double> a = List<double>.from(storedEmbedding);
    List<double> b = List<double>.from(newEmbedding);
    while (a.length < maxLen) { a.add(0.0); }
    while (b.length < maxLen) { b.add(0.0); }
    a = VectorUtils.normalize(a);
    b = VectorUtils.normalize(b);
    final cosineSim = VectorUtils.cosineSimilarity(a, b);

    double percent;
    if (cosineSim >= 0.95) { percent = 95 + (cosineSim - 0.95) * 100; }
    else if (cosineSim >= 0.85) { percent = 80 + (cosineSim - 0.85) * 150; }
    else if (cosineSim >= 0.70) { percent = 60 + (cosineSim - 0.70) * 133; }
    else { percent = cosineSim * 85; }
    return MatchResult.fromSimilarity(percent.clamp(0.0, 100.0));
  }
}
```

### 5.4 `lib/src/services/face_storage_service.dart`

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/face_record.dart';

class FaceStorageService {
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, 'face_verify.db');
    return openDatabase(dbPath, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE faces (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT UNIQUE NOT NULL,
          image_path TEXT NOT NULL,
          embedding TEXT NOT NULL,
          registered_at TEXT NOT NULL
        )
      ''');
    });
  }

  Future<void> storeFace(FaceRecord record) async {
    final db = await database;
    await db.insert('faces', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<FaceRecord?> getFace(String userId) async {
    final db = await database;
    final result = await db.query('faces', where: 'user_id = ?', whereArgs: [userId]);
    if (result.isEmpty) return null;
    return FaceRecord.fromMap(result.first);
  }

  Future<bool> isRegistered(String userId) async {
    final record = await getFace(userId);
    if (record == null) return false;
    return File(record.imagePath).existsSync();
  }

  Future<void> deleteFace(String userId) async {
    final record = await getFace(userId);
    if (record != null) {
      final file = File(record.imagePath);
      if (await file.exists()) await file.delete();
    }
    final db = await database;
    await db.delete('faces', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<List<String>> getAllUsers() async {
    final db = await database;
    final result = await db.query('faces', columns: ['user_id']);
    return result.map((r) => r['user_id'] as String).toList();
  }
}
```

### 5.5 `lib/src/services/base64_service.dart`

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class Base64Service {
  static Future<String> imageFileToBase64(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  static Future<String> base64ToTempFile(String base64String) async {
    final bytes = base64Decode(base64String);
    final dir = await getTemporaryDirectory();
    final filePath = path.join(dir.path, 'fv_ref_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  static Future<void> cleanupTempFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }
}
```

### 5.6 `lib/src/services/transaction_service.dart`

```dart
import 'dart:math';

class TransactionService {
  static final _random = Random.secure();

  static String generateTransactionId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'txn_${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
```

---

## STEP 6 — WIDGETS

### 6.1 `lib/src/ui/widgets/face_oval_painter.dart`

```dart
import 'package:flutter/material.dart';

class FaceOvalPainter extends CustomPainter {
  final bool isValid;
  final bool isProcessing;

  FaceOvalPainter({this.isValid = false, this.isProcessing = false});

  @override
  void paint(Canvas canvas, Size size) {
    final Color color = isProcessing ? Colors.yellow : isValid ? Colors.green : Colors.white;

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.65, height: size.height * 0.48,
    );

    canvas.drawOval(ovalRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawOval(ovalRect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.0);

    final guidePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 4.0..strokeCap = StrokeCap.round;
    final guides = [
      [ovalRect.topLeft, ovalRect.topLeft + const Offset(20, 0)],
      [ovalRect.topLeft, ovalRect.topLeft + const Offset(0, 20)],
      [ovalRect.topRight, ovalRect.topRight + const Offset(-20, 0)],
      [ovalRect.topRight, ovalRect.topRight + const Offset(0, 20)],
    ];
    for (final g in guides) { canvas.drawLine(g[0], g[1], guidePaint); }
  }

  @override
  bool shouldRepaint(FaceOvalPainter oldDelegate) =>
      oldDelegate.isValid != isValid || oldDelegate.isProcessing != isProcessing;
}
```

### 6.2 `lib/src/ui/widgets/status_banner.dart`

```dart
import 'package:flutter/material.dart';
import '../../models/face_validation_result.dart';

class StatusBanner extends StatelessWidget {
  final String message;
  final ValidationError error;
  final bool isSuccess;

  const StatusBanner({super.key, required this.message, this.error = ValidationError.none, this.isSuccess = false});

  Color get _color {
    if (isSuccess) return Colors.green.shade700;
    if (error == ValidationError.none) return Colors.black87;
    return Colors.red.shade700;
  }

  IconData get _icon {
    if (isSuccess) return Icons.check_circle;
    switch (error) {
      case ValidationError.eyesClosed: return Icons.remove_red_eye;
      case ValidationError.noFace: return Icons.face;
      case ValidationError.multipleFaces: return Icons.group;
      case ValidationError.lookingAway: return Icons.rotate_left;
      default: return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(_icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14))),
      ]),
    );
  }
}
```

---

## STEP 7 — CONFIG

### `lib/src/config.dart`

```dart
import 'package:camera/camera.dart';

class FaceVerifyConfig {
  final double matchThreshold;
  final bool requireLiveness;
  final Duration livenessTimeout;
  final ResolutionPreset cameraResolution;

  const FaceVerifyConfig({
    this.matchThreshold = 75.0,
    this.requireLiveness = true,
    this.livenessTimeout = const Duration(seconds: 30),
    this.cameraResolution = ResolutionPreset.high,
  });
}
```

---

## STEP 8 — SCREENS

> **Note:** Screens are in `lib/src/ui/`. The full code for signup_screen.dart and lib_verify_screen.dart is extensive.  
> Copy them from the current app's `lib/screens/signup_screen.dart` and `lib/screens/lib_verify_screen.dart`.  
> The key differences from a normal app screen:
> - They accept `FaceVerifyConfig` as a parameter
> - They return results via `Navigator.pop(context, result)` instead of navigating
> - They handle user cancel via `PopScope` → returns failure result
> - They handle camera permission denied → returns failure result
> - They handle liveness timeout → returns failure result
> - Signup screen converts captured image to base64 before returning
> - Verify screen accepts `referenceImageBase64`, decodes it, extracts embedding, compares with live capture

**Import path adjustments:** Since code lives under `src/`, all imports change from `../services/` to `../../services/` relative to `src/ui/`.

---

## STEP 9 — MAIN FACEVERIFY CLASS

### `lib/src/face_verify.dart`

```dart
import 'package:flutter/material.dart';
import 'config.dart';
import 'models/signup_result.dart';
import 'models/verify_result.dart';
import 'models/face_verify_error.dart';
import 'services/face_storage_service.dart';
import 'services/transaction_service.dart';
import 'ui/signup_screen.dart';
import 'ui/lib_verify_screen.dart';

class FaceVerify {
  final FaceVerifyConfig config;
  final FaceStorageService _storage = FaceStorageService();

  FaceVerify({this.config = const FaceVerifyConfig()});

  Future<SignupResult> signup({required BuildContext context, required String userId}) async {
    final result = await Navigator.push<SignupResult>(
      context, MaterialPageRoute(builder: (_) => SignupScreen(userId: userId, config: config)),
    );
    return result ?? SignupResult.failure(
      transactionId: TransactionService.generateTransactionId(),
      message: 'User cancelled', error: FaceVerifyError.userCancelled,
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
        message: 'Reference image is empty', error: FaceVerifyError.noReferenceImage,
      );
    }
    final result = await Navigator.push<VerifyResult>(
      context, MaterialPageRoute(builder: (_) => LibVerifyScreen(
        userId: userId, referenceImageBase64: referenceImageBase64, config: config,
      )),
    );
    return result ?? VerifyResult.failure(
      transactionId: TransactionService.generateTransactionId(),
      message: 'User cancelled', error: FaceVerifyError.userCancelled,
    );
  }

  Future<bool> isRegistered(String userId) => _storage.isRegistered(userId);
  Future<void> deleteFace(String userId) => _storage.deleteFace(userId);
  Future<List<String>> getAllRegisteredUsers() => _storage.getAllUsers();
}
```

---

## STEP 10 — BARREL EXPORT

### `lib/face_verify_lib.dart`

```dart
library face_verify;

export 'src/face_verify.dart';
export 'src/config.dart';
export 'src/models/signup_result.dart';
export 'src/models/verify_result.dart';
export 'src/models/face_verify_error.dart';
```

---

## STEP 11 — HOST APP PLATFORM CONFIG

Host apps using this library must add to their platform configs:

### Android — `android/app/src/main/AndroidManifest.xml`

Add inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="true"/>
<uses-feature android:name="android.hardware.camera.front" android:required="true"/>
```

Add inside `<application>`:
```xml
<meta-data android:name="com.google.mlkit.vision.DEPENDENCIES" android:value="face"/>
```

Set `minSdk` to at least **21** in `android/app/build.gradle.kts`.

### iOS — `ios/Runner/Info.plist`

Add:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for face verification.</string>
```

---

## STEP 12 — EXAMPLE APP

### `example/lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:face_verify/face_verify_lib.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceVerify Example',
      theme: ThemeData.dark(),
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});
  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  final _fv = FaceVerify();
  String _result = 'Tap a button to start';
  String? _storedBase64;

  Future<void> _signup() async {
    final r = await _fv.signup(context: context, userId: 'demo_user');
    setState(() {
      if (r.success) {
        _storedBase64 = r.imageBase64;
        _result = '✅ Signup OK | txn: ${r.transactionId}';
      } else {
        _result = '❌ ${r.error} | ${r.message}';
      }
    });
  }

  Future<void> _verify() async {
    final r = await _fv.verify(
      context: context, userId: 'demo_user',
      referenceImageBase64: _storedBase64!,
    );
    setState(() {
      _result = r.passed
        ? '✅ ${r.matchPercent.toStringAsFixed(1)}% ${r.verdict} | txn: ${r.transactionId}'
        : '❌ ${r.matchPercent.toStringAsFixed(1)}% ${r.verdict} | ${r.error}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FaceVerify Example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(_result, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: _signup, child: const Text('Signup')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _storedBase64 != null ? _verify : null,
            child: const Text('Verify'),
          ),
        ]),
      ),
    );
  }
}
```

---

## STEP 13 — BUILD & VERIFY

```bash
flutter pub get
flutter analyze
```

Expected output: `No issues found!`

---

## TROUBLESHOOTING

| Issue | Fix |
|-------|-----|
| `minSdk` error | Set `minSdk = 21` in host app's `build.gradle.kts` |
| Camera black screen | Ensure `FaceOvalPainter` uses `canvas.saveLayer/restore` |
| `WriteBuffer` not found | Use `BytesBuilder` from `dart:typed_data` instead |
| Camera permission denied | Add permissions in `AndroidManifest.xml` and `Info.plist` |
| Liveness not triggering | Ensure `InputImageRotation.rotation270deg` for front camera |

---

## COST SUMMARY

| Component | Cost |
|-----------|------|
| ML Kit Face Detection | **Free** (on-device) |
| SQLite Storage | **Free** (local) |
| Face Matching | **Free** (cosine similarity) |
| **Total** | **$0** |
