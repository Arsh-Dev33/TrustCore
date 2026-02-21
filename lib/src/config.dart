import 'package:camera/camera.dart';

class TrustCoreConfig {
  final double matchThreshold;
  final bool requireLiveness;
  final Duration livenessTimeout;
  final ResolutionPreset cameraResolution;

  const TrustCoreConfig({
    this.matchThreshold = 75.0,
    this.requireLiveness = true,
    this.livenessTimeout = const Duration(seconds: 30),
    this.cameraResolution = ResolutionPreset.high,
  });
}
