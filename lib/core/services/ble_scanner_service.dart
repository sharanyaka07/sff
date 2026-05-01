import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/logger.dart';
import 'notification_service.dart';

class BleScannerService {
  static const String _sosBroadcastUUID =
      'dead0000-beef-1234-5678-abcdef000001';

  static StreamSubscription? _scanSubscription;
  static bool _isListening = false;

  // ── Start passively scanning for SOS broadcasts ───────────────────
  static Future<void> startListeningForSOS() async {
    if (_isListening) return;

    try {
      AppLogger.bluetooth('Starting passive SOS scan...');

      await FlutterBluePlus.startScan(
        withServices: [],
        androidUsesFineLocation: true,
        continuousUpdates: true,
        removeIfGone: const Duration(seconds: 10),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          _checkForSOS(result);
        }
      });

      _isListening = true;
      AppLogger.bluetooth('Passive SOS scan active ✅');
    } catch (e) {
      AppLogger.error('Failed to start passive scan', error: e);
    }
  }

  // ── Check if a scan result is an SOS broadcast ────────────────────
  static void _checkForSOS(ScanResult result) {
    try {
      final serviceUuids = result.advertisementData.serviceUuids
          .map((u) => u.toString().toLowerCase())
          .toList();

      // ── Use _sosBroadcastUUID field for the check ─────────────────
      final sosPrefix = _sosBroadcastUUID.substring(0, 8); // 'dead0000'
      if (serviceUuids.any((u) => u.contains(sosPrefix))) {
        final manufacturerData =
            result.advertisementData.manufacturerData;

        if (manufacturerData.isNotEmpty) {
          final data = manufacturerData.values.first;

          // Check SOS marker bytes (0x53 0x4F 0x53 = 'SOS')
          if (data.length >= 3 &&
              data[0] == 0x53 &&
              data[1] == 0x4F &&
              data[2] == 0x53) {
            final deviceName =
                result.advertisementData.advName.isNotEmpty
                    ? result.advertisementData.advName
                    : result.device.remoteId.str;

            AppLogger.sos('🆘 SOS detected from: $deviceName');

            // Decode location if available
            String location = 'Unknown location';
            if (data.length >= 11) {
              final lat = _decodeInt(data, 3) / 10000.0;
              final lng = _decodeInt(data, 7) / 10000.0;
              location = '$lat, $lng';
            }

            // Show alert notification
            NotificationService.showSosAlert(
              senderName: deviceName,
              location: location,
            );
          }
        }
      }
    } catch (e) {
      // Ignore parsing errors for non-SOS packets
    }
  }

  // ── Decode 4-byte big-endian integer ──────────────────────────────
  static int _decodeInt(List<int> data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  // ── Stop listening ────────────────────────────────────────────────
  static Future<void> stopListening() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    _isListening = false;
    AppLogger.bluetooth('Passive SOS scan stopped');
  }

  static bool get isListening => _isListening;
}