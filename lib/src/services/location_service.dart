import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Get current GPS position with proper permission handling
  static Future<Position?> getCurrentPosition() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('[Location] Location services are disabled');
      return null;
    }

    // Check and request permission using Geolocator's own API
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('[Location] Location permission denied');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('[Location] Location permission denied forever');
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      print(
          '[Location] Got position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('[Location] Error getting position: $e');
      // Fallback to last known position
      return await Geolocator.getLastKnownPosition();
    }
  }
}
