import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

enum TFLiteLabel { positive, negative }

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
      if (image == null) {
        return TFLiteClassifierResult(detected: false, confidence: 0.0);
      }

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
