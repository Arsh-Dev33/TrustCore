import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:ui';

// Class index that means "detected" for each model.
// If glasses always pass even when wearing them, flip _glassesPositiveClass to 0.
// Check [TFLite] logs: if class0 > class1 when glasses are worn → set to 0.
const int _maskPositiveClass    = 1; // mask_detector:    class0=no_mask, class1=mask
const int _glassesPositiveClass = 1; // glasses_detector: class0=no_glasses, class1=glasses

class TFLiteClassifierResult {
  final bool detected; // true = mask/glasses found
  final double confidence; // 0.0 to 1.0

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
  Future<TFLiteClassifierResult> detectMask(String imagePath,
      {Rect? faceRect}) async {
    return _runClassifier(_maskInterpreter, imagePath,
        label: 'mask', positiveClassIndex: _maskPositiveClass, faceRect: faceRect);
  }

  /// Detect if glasses/spectacles are present
  Future<TFLiteClassifierResult> detectGlasses(String imagePath,
      {Rect? faceRect}) async {
    return _runClassifier(_glassesInterpreter, imagePath,
        label: 'glasses', positiveClassIndex: _glassesPositiveClass, faceRect: faceRect);
  }

  Future<TFLiteClassifierResult> _runClassifier(
    Interpreter? interpreter,
    String imagePath, {
    required String label,
    required int positiveClassIndex,
    Rect? faceRect,
  }) async {
    if (interpreter == null) {
      return TFLiteClassifierResult(detected: false, confidence: 0.0);
    }

    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) {
        return TFLiteClassifierResult(detected: false, confidence: 0.0);
      }

      // Crop to face if provided
      if (faceRect != null) {
        image = img.copyCrop(
          image,
          x: faceRect.left.toInt(),
          y: faceRect.top.toInt(),
          width: faceRect.width.toInt(),
          height: faceRect.height.toInt(),
        );
      }

      // Resize to 224x224 (MobileNet standard input size)
      image = img.copyResize(image, width: 224, height: 224);

      // Convert to float32 input tensor [1, 224, 224, 3]
      final input = _imageToFloat32(image);

      // Output tensor [1, 2] → [no_mask_prob, mask_prob]
      final output = List.generate(1, (_) => List.filled(2, 0.0));

      interpreter.run(input, output);

      final c0 = output[0][0];
      final c1 = output[0][1];

      // Debug: if glasses always pass when worn, flip _glassesPositiveClass to 0
      print('[TFLite] $label: class0=$c0, class1=$c1 (positiveClass=$positiveClassIndex)');

      final negativeClassIndex = 1 - positiveClassIndex;
      final detected = output[0][positiveClassIndex] > output[0][negativeClassIndex];

      return TFLiteClassifierResult(
        detected: detected,
        confidence: output[0][positiveClassIndex],
      );
    } catch (e) {
      print('[TFLite] Error: $e');
      return TFLiteClassifierResult(detected: false, confidence: 0.0);
    }
  }

  List<List<List<List<double>>>> _imageToFloat32(img.Image image) {
    return List.generate(
        1,
        (_) => List.generate(
            224,
            (y) => List.generate(224, (x) {
                  final pixel = image.getPixel(x, y);
                  // Normalize to [0, 1]
                  return [
                    pixel.r / 255.0,
                    pixel.g / 255.0,
                    pixel.b / 255.0,
                  ];
                })));
  }

  void dispose() {
    _maskInterpreter?.close();
    _glassesInterpreter?.close();
  }
}
