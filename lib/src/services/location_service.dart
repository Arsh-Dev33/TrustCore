import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  /// Get current GPS position
  static Future<Position?> getCurrentPosition() async {
    // Request permission
    final status = await Permission.location.request();
    if (!status.isGranted) return null;

    // Check if location service enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      // Fallback to last known position
      return await Geolocator.getLastKnownPosition();
    }
  }
}
