import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service that generates 192-d face embeddings using MobileFaceNet TFLite model.
///
/// Pipeline:
/// 1. Crop the face region from the full image using ML Kit bounding box
/// 2. Resize to 112×112
/// 3. Normalize pixel values to [-1, 1]
/// 4. Run TFLite inference → 192-dimensional embedding vector
class FaceEmbeddingService {
  static const int _inputSize = 112;
  static const int _outputSize = 192;

  Interpreter? _interpreter;
  bool _initFailed = false;

  /// Initialize the TFLite interpreter from the bundled asset.
  Future<void> initialize() async {
    // Flutter plugins must use packages/<pkg>/ prefix for assets
    final assetPaths = [
      'packages/trust_core/assets/mobilefacenet.tflite',
      'assets/mobilefacenet.tflite',
      'mobilefacenet.tflite',
    ];

    for (final path in assetPaths) {
      try {
        _interpreter = await Interpreter.fromAsset(path);
        debugPrint('TrustCore: MobileFaceNet model loaded from: $path');
        return;
      } catch (e) {
        debugPrint('TrustCore: Failed to load model from $path: $e');
      }
    }

    debugPrint('TrustCore: All asset paths failed!');
    _initFailed = true;
  }

  /// Generate a face embedding from an image file and the detected face bounding box.
  Future<List<double>> getEmbedding(
      String imagePath, Rect faceBoundingBox) async {
    if (_interpreter == null) {
      if (_initFailed) {
        throw StateError(
            'TFLite model failed to load. Ensure mobilefacenet.tflite is in assets/');
      }
      // Model might still be loading, wait a bit
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_interpreter != null) break;
      }
      if (_interpreter == null) {
        throw StateError('TFLite model not ready. Please try again.');
      }
    }

    // Read and decode the image
    final imageBytes = await File(imagePath).readAsBytes();
    img.Image? fullImage = img.decodeImage(imageBytes);
    if (fullImage == null) {
      throw Exception('Failed to decode image');
    }

    // Apply EXIF orientation so pixel data matches ML Kit's bounding box
    fullImage = img.bakeOrientation(fullImage);

    debugPrint('TrustCore: Image size: ${fullImage.width}x${fullImage.height}');
    debugPrint(
        'TrustCore: Face box: L=${faceBoundingBox.left.toInt()}, T=${faceBoundingBox.top.toInt()}, '
        'W=${faceBoundingBox.width.toInt()}, H=${faceBoundingBox.height.toInt()}');

    // Crop the face region with some padding
    final croppedFace = _cropFace(fullImage, faceBoundingBox);

    // Resize to 112×112
    final resizedFace = img.copyResize(
      croppedFace,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Prepare input tensor: [1, 112, 112, 3] with pixel values in [-1, 1]
    final input = _prepareInputTensor(resizedFace);

    // Prepare output tensor: [1, 192]
    final output = List.generate(1, (_) => List.filled(_outputSize, 0.0));

    // Run inference
    _interpreter!.run(input, output);

    // Extract and normalize the embedding
    final embedding = List<double>.from(output[0]);
    return _l2Normalize(embedding);
  }

  /// Crop the face from the full image using the ML Kit bounding box.
  /// Adds 15% padding around the face for better recognition.
  img.Image _cropFace(img.Image fullImage, Rect box) {
    final padX = (box.width * 0.15).toInt();
    final padY = (box.height * 0.15).toInt();

    int x = (box.left.toInt() - padX).clamp(0, fullImage.width - 1);
    int y = (box.top.toInt() - padY).clamp(0, fullImage.height - 1);
    int w = (box.width.toInt() + 2 * padX).clamp(1, fullImage.width - x);
    int h = (box.height.toInt() + 2 * padY).clamp(1, fullImage.height - y);

    // Safety: ensure we don't exceed image bounds
    if (x + w > fullImage.width) w = fullImage.width - x;
    if (y + h > fullImage.height) h = fullImage.height - y;
    if (w < 1) w = 1;
    if (h < 1) h = 1;

    debugPrint('TrustCore: Cropping face at x=$x, y=$y, w=$w, h=$h');
    return img.copyCrop(fullImage, x: x, y: y, width: w, height: h);
  }

  /// Convert the resized face image to a [1, 112, 112, 3] float tensor
  /// with pixel values normalized to [-1, 1].
  List<List<List<List<double>>>> _prepareInputTensor(img.Image image) {
    return List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final pixel = image.getPixel(x, y);
            return [
              (pixel.r.toDouble() - 127.5) / 127.5,
              (pixel.g.toDouble() - 127.5) / 127.5,
              (pixel.b.toDouble() - 127.5) / 127.5,
            ];
          },
        ),
      ),
    );
  }

  /// L2-normalize the embedding vector.
  List<double> _l2Normalize(List<double> vector) {
    double norm = 0.0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm == 0.0) return vector;
    return vector.map((v) => v / norm).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
