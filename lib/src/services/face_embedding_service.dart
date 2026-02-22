import 'dart:io';
import 'dart:math';
import 'dart:ui';
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

  /// Initialize the TFLite interpreter from the bundled asset.
  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset('mobilefacenet.tflite');
  }

  /// Generate a face embedding from an image file and the detected face bounding box.
  ///
  /// [imagePath] — path to the full camera image
  /// [faceBoundingBox] — bounding box from ML Kit face detection
  ///
  /// Returns a normalized 192-d embedding vector.
  Future<List<double>> getEmbedding(
      String imagePath, Rect faceBoundingBox) async {
    if (_interpreter == null) {
      throw StateError(
          'FaceEmbeddingService not initialized. Call initialize() first.');
    }

    // Read the image
    final imageBytes = await File(imagePath).readAsBytes();
    final fullImage = img.decodeImage(imageBytes);
    if (fullImage == null) {
      throw Exception('Failed to decode image at $imagePath');
    }

    // Crop the face region with some padding
    final croppedFace = _cropFace(fullImage, faceBoundingBox);

    // Resize to 112×112
    final resizedFace =
        img.copyResize(croppedFace, width: _inputSize, height: _inputSize);

    // Prepare input tensor: [1, 112, 112, 3] with pixel values in [-1, 1]
    final input = _prepareInputTensor(resizedFace);

    // Run inference
    final output = List.filled(_outputSize, 0.0).reshape([1, _outputSize]);
    _interpreter!.run(input, output);

    // Extract and normalize the embedding
    final embedding = List<double>.from(output[0] as List);
    return _l2Normalize(embedding);
  }

  /// Crop the face from the full image using the ML Kit bounding box.
  /// Adds 10% padding around the face for better recognition.
  img.Image _cropFace(img.Image fullImage, Rect box) {
    final padX = (box.width * 0.1).toInt();
    final padY = (box.height * 0.1).toInt();

    final x = (box.left.toInt() - padX).clamp(0, fullImage.width - 1);
    final y = (box.top.toInt() - padY).clamp(0, fullImage.height - 1);
    final w = (box.width.toInt() + 2 * padX).clamp(1, fullImage.width - x);
    final h = (box.height.toInt() + 2 * padY).clamp(1, fullImage.height - y);

    return img.copyCrop(fullImage, x: x, y: y, width: w, height: h);
  }

  /// Convert the resized face image to a [1, 112, 112, 3] float tensor
  /// with pixel values normalized to [-1, 1].
  List _prepareInputTensor(img.Image image) {
    final input = List.generate(
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
    return input;
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
