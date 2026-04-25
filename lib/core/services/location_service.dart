import 'package:geolocator/geolocator.dart';
import '../utils/logger.dart';

class LocationService {
  // ── Get Current Position ───────────────────────────────────────
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location services are disabled');
        return null;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.warning('Location permission permanently denied');
        return null;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      AppLogger.success(
        'Location: ${position.latitude}, ${position.longitude}',
        tag: 'GPS',
      );

      return position;
    } catch (e) {
      AppLogger.error('Location error', tag: 'GPS', error: e);
      return null;
    }
  }

  // ── Format for SOS message ─────────────────────────────────────
  static String formatLocationForSOS(Position position) {
    final lat = position.latitude.toStringAsFixed(6);
    final lng = position.longitude.toStringAsFixed(6);
    final mapsLink = 'https://maps.google.com/?q=$lat,$lng';
    return 'LAT: $lat, LNG: $lng\n$mapsLink';
  }

  // ── Format short version ───────────────────────────────────────
  static String formatShort(Position position) {
    final lat = position.latitude.toStringAsFixed(4);
    final lng = position.longitude.toStringAsFixed(4);
    return '$lat, $lng';
  }
}