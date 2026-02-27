import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:ui';

class TFLiteClassifierResult {
  final bool detected;
  final double confidence;

  TFLiteClassifierResult({required this.detected, required this.confidence});
}

class TFLiteService {
  ImageLabeler? _labeler;
  bool _modelsLoaded = false;

  Future<void> loadModels() async {
    _labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.2),
    );
    _modelsLoaded = true;
  }

  bool get modelsLoaded => _modelsLoaded;

  Future<TFLiteClassifierResult> detectMask(String imagePath,
      {Rect? faceRect}) async {
    return _detectAccessory(
      imagePath,
      faceRect: faceRect,
      label: 'mask',
      keywords: ['mask', 'respirator', 'face shield', 'face covering'],
    );
  }

  Future<TFLiteClassifierResult> detectGlasses(String imagePath,
      {Rect? faceRect}) async {
    return _detectAccessory(
      imagePath,
      faceRect: faceRect,
      label: 'glasses',
      keywords: ['glass', 'spectacle', 'eyewear', 'sunglass', 'goggle'],
    );
  }

  Future<TFLiteClassifierResult> _detectAccessory(
    String imagePath, {
    Rect? faceRect,
    required String label,
    required List<String> keywords,
  }) async {
    if (_labeler == null) {
      return TFLiteClassifierResult(detected: false, confidence: 0.0);
    }

    try {
      String processPath = imagePath;
      File? tempFile;

      if (faceRect != null) {
        final bytes = await File(imagePath).readAsBytes();
        var image = img.decodeImage(bytes);
        if (image != null) {
          image = img.copyCrop(
            image,
            x: faceRect.left.toInt(),
            y: faceRect.top.toInt(),
            width: faceRect.width.toInt(),
            height: faceRect.height.toInt(),
          );
          tempFile = File(
            '${Directory.systemTemp.path}/face_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await tempFile.writeAsBytes(img.encodeJpg(image));
          processPath = tempFile.path;
        }
      }

      final inputImage = InputImage.fromFilePath(processPath);
      final labels = await _labeler!.processImage(inputImage);

      if (tempFile != null) await tempFile.delete();

      double maxConfidence = 0.0;
      bool detected = false;

      for (final l in labels) {
        print('[MLKit] $label check — ${l.label}: ${l.confidence}');
        final name = l.label.toLowerCase();
        if (keywords.any((k) => name.contains(k))) {
          detected = true;
          if (l.confidence > maxConfidence) maxConfidence = l.confidence;
        }
      }

      return TFLiteClassifierResult(
          detected: detected, confidence: maxConfidence);
    } catch (e) {
      print('[MLKit] Error detecting $label: $e');
      return TFLiteClassifierResult(detected: false, confidence: 0.0);
    }
  }

  void dispose() {
    _labeler?.close();
  }
}
