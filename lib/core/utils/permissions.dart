import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

class AppPermissions {
  static Future<bool> requestBluetoothPermissions() async {
    AppLogger.bluetooth('Requesting Bluetooth permissions...');

    // Step 1: Request location first (required for BLE)
    final locationStatus = await Permission.locationWhenInUse.request();
    AppLogger.bluetooth('Location: $locationStatus');

    // Step 2: Request Bluetooth permissions
    final bluetoothScan = await Permission.bluetoothScan.request();
    AppLogger.bluetooth('BluetoothScan: $bluetoothScan');

    final bluetoothConnect = await Permission.bluetoothConnect.request();
    AppLogger.bluetooth('BluetoothConnect: $bluetoothConnect');

    final bluetoothAdvertise = await Permission.bluetoothAdvertise.request();
    AppLogger.bluetooth('BluetoothAdvertise: $bluetoothAdvertise');

    // Check results
    final locationOk = locationStatus.isGranted;
    final scanOk = bluetoothScan.isGranted;
    final connectOk = bluetoothConnect.isGranted;

    AppLogger.bluetooth(
      'Results → Location: $locationOk, '
      'Scan: $scanOk, Connect: $connectOk',
    );

    // If permanently denied, guide user to settings
    if (bluetoothScan.isPermanentlyDenied ||
        bluetoothConnect.isPermanentlyDenied ||
        locationStatus.isPermanentlyDenied) {
      AppLogger.warning('Permissions permanently denied — open settings');
      return false;
    }

    return locationOk && scanOk && connectOk;
  }

  static Future<void> showPermissionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth, color: Colors.blue),
            SizedBox(width: 8),
            Text('Permissions Needed'),
          ],
        ),
        content: const Text(
          'Safe Connect needs these permissions:\n\n'
          '📍 Location — to scan for nearby devices\n'
          '📶 Nearby Devices — to connect via Bluetooth\n\n'
          'Please tap "Open Settings" and allow both.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}