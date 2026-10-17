import 'package:geolocator/geolocator.dart';

import '../utils/error_messages.dart';

/// Location helpers for sharing current / live location in chats.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Whether the device can access location at all.
  Future<bool> isLocationEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (error) {
      debugLog('Location service check failed: $error');
      return false;
    }
  }

  /// Request location permission. Returns true when granted (while in use).
  Future<bool> requestPermission() async {
    try {
      final status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) return false;
      }
      if (status == LocationPermission.deniedForever ||
          await Geolocator.checkPermission() == LocationPermission.deniedForever) {
        return false;
      }
      final current = await Geolocator.checkPermission();
      return current == LocationPermission.whileInUse ||
          current == LocationPermission.always;
    } catch (error) {
      debugLog('Location permission request failed: $error');
      return false;
    }
  }

  /// Get the device's current position.
  Future<Position> currentPosition({LocationAccuracy accuracy = LocationAccuracy.high}) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw const LocationException('Location permission not granted.');
    }
    final enabled = await isLocationEnabled();
    if (!enabled) {
      throw const LocationException('Location services are turned off.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy),
    );
  }

  /// Stream of position updates for live location sharing.
  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}
