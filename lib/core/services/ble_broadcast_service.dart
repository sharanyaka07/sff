import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import '../utils/logger.dart';

class BleBroadcastService {
  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  static bool _isAdvertising = false;

// ignore: unused_field
static const String _sosBroadcastUUID =
    'dead0000-beef-1234-5678-abcdef000001';

  static Future<bool> broadcastSOS({
    required String userName,
    required double? latitude,
    required double? longitude,
  }) async {
    try {
      final isSupported = await _peripheral.isSupported;
      if (!isSupported) {
        AppLogger.warning('BLE advertising not supported on this device');
        return false;
      }

      if (_isAdvertising) await stopBroadcast();

      final Uint8List manufacturerData = _encodeSosData(
        latitude: latitude,
        longitude: longitude,
      );

      final advertiseData = AdvertiseData(
  serviceUuid: 'DEAD0000-BEEF-1234-5678-ABCDEF000001',
        manufacturerId: 0x5053,
        manufacturerData: manufacturerData,
        includeDeviceName: true,
        includePowerLevel: false,
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: false,
        timeout: 30000,
      );

      await _peripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      _isAdvertising = true;
      AppLogger.sos('SOS BLE broadcast started ✅');
      return true;
    } catch (e) {
      AppLogger.error('BLE broadcast failed', error: e);
      return false;
    }
  }

  static Future<void> stopBroadcast() async {
    try {
      await _peripheral.stop();
      _isAdvertising = false;
      AppLogger.bluetooth('BLE broadcast stopped');
    } catch (e) {
      AppLogger.error('Failed to stop BLE broadcast', error: e);
    }
  }

  static bool get isAdvertising => _isAdvertising;

  static Uint8List _encodeSosData({
    required double? latitude,
    required double? longitude,
  }) {
    final List<int> raw = [0x53, 0x4F, 0x53]; // 'SOS' in ASCII

    if (latitude != null && longitude != null) {
      final lat = (latitude * 10000).toInt();
      final lng = (longitude * 10000).toInt();

      raw.add((lat >> 24) & 0xFF);
      raw.add((lat >> 16) & 0xFF);
      raw.add((lat >> 8) & 0xFF);
      raw.add(lat & 0xFF);

      raw.add((lng >> 24) & 0xFF);
      raw.add((lng >> 16) & 0xFF);
      raw.add((lng >> 8) & 0xFF);
      raw.add(lng & 0xFF);
    }

    final trimmed = raw.length > 20 ? raw.sublist(0, 20) : raw;
    return Uint8List.fromList(trimmed);
  }
}