// removed library name

import 'package:flutter/material.dart';
import 'src/trust_core_camera.dart';
import 'src/trust_core_result.dart';

export 'src/trust_core_result.dart';

/// TrustCore — Single function face detection library
/// No signup. No backend. 100% free. Offline.
class TrustCore {
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
  /// Returns [TrustCoreResult] with:
  ///   - base64Image : JPEG image as base64 string
  ///   - latitude    : GPS latitude at capture time
  ///   - longitude   : GPS longitude at capture time
  ///   - capturedAt  : DateTime of capture
  ///
  /// Returns null if user cancels.
  ///
  /// Example:
  /// ```dart
  /// final result = await TrustCore.capture(context);
  /// if (result != null) {
  ///   print(result.base64Image);
  ///   print(result.latitude);
  ///   print(result.longitude);
  /// }
  /// ```
  static Future<TrustCoreResult?> capture(BuildContext context) async {
    final result = await Navigator.of(context).push<TrustCoreResult>(
      MaterialPageRoute(
        builder: (_) => const TrustCoreCamera(),
        fullscreenDialog: true,
      ),
    );
    return result;
  }
}
