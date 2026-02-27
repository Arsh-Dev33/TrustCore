// removed unused import

class TrustCoreResult {
  /// Base64 encoded JPEG image string
  final String base64Image;

  /// Latitude at time of capture
  final double latitude;

  /// Longitude at time of capture
  final double longitude;

  /// Timestamp of capture
  final DateTime capturedAt;

  TrustCoreResult({
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
    return 'TrustCoreResult('
        'latitude: $latitude, '
        'longitude: $longitude, '
        'capturedAt: $capturedAt, '
        'base64Image: [${base64Image.length} chars])';
  }
}
