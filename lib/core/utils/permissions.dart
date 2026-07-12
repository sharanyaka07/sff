import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

class AppPermissions {
  /// Request ALL permissions at app startup
  static Future<void> requestAll(BuildContext context) async {
    AppLogger.info('Requesting all permissions...', tag: 'Permissions');

    // ── Step 1: Request non-sensitive permissions first ──────────
    final statuses = await [
      Permission.locationWhenInUse,
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.contacts,
      Permission.notification,
    ].request();

    // ── Step 2: Request SMS separately — non-blocking ────────────
    // SMS is restricted on sideloaded APKs on some devices.
    // We catch any error so the app never crashes due to SMS denial.
    try {
      final smsStatus = await Permission.sms.request();
      AppLogger.info('Permission.sms: $smsStatus', tag: 'Permissions');
    } catch (e) {
      AppLogger.warning(
        'SMS permission blocked by device — SOS SMS disabled',
        tag: 'Permissions',
      );
    }

    // Log all results
    statuses.forEach((permission, status) {
      AppLogger.info('$permission: $status', tag: 'Permissions');
    });

    // ── Step 3: Check only CRITICAL permissions (not SMS) ────────
    final criticalPermissions = [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    final permanentlyDenied = statuses.entries
        .where((e) =>
            criticalPermissions.contains(e.key) && e.value.isPermanentlyDenied)
        .map((e) => e.key)
        .toList();

    final denied = statuses.entries
        .where((e) =>
            criticalPermissions.contains(e.key) && !e.value.isGranted)
        .map((e) => e.key)
        .toList();

    if (permanentlyDenied.isNotEmpty && context.mounted) {
      _showPermanentlyDeniedDialog(context);
    } else if (denied.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '⚠️ Some permissions denied. SOS & Bluetooth may not work fully.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Fix',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    } else {
      AppLogger.success('All permissions granted ✅', tag: 'Permissions');
    }
  }

  /// Keep existing method for bluetooth screen
  static Future<bool> requestBluetoothPermissions() async {
    AppLogger.bluetooth('Requesting Bluetooth permissions...');

    final locationStatus = await Permission.locationWhenInUse.request();
    AppLogger.bluetooth('Location: $locationStatus');

    final bluetoothScan = await Permission.bluetoothScan.request();
    AppLogger.bluetooth('BluetoothScan: $bluetoothScan');

    final bluetoothConnect = await Permission.bluetoothConnect.request();
    AppLogger.bluetooth('BluetoothConnect: $bluetoothConnect');

    final bluetoothAdvertise = await Permission.bluetoothAdvertise.request();
    AppLogger.bluetooth('BluetoothAdvertise: $bluetoothAdvertise');

    final locationOk = locationStatus.isGranted;
    final scanOk = bluetoothScan.isGranted;
    final connectOk = bluetoothConnect.isGranted;

    AppLogger.bluetooth(
      'Results → Location: $locationOk, '
      'Scan: $scanOk, Connect: $connectOk',
    );

    if (bluetoothScan.isPermanentlyDenied ||
        bluetoothConnect.isPermanentlyDenied ||
        locationStatus.isPermanentlyDenied) {
      AppLogger.warning('Permissions permanently denied — open settings');
      return false;
    }

    return locationOk && scanOk && connectOk;
  }

  /// Keep existing method for bluetooth screen
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

  /// Show dialog when permissions are permanently denied
  static Future<void> _showPermanentlyDeniedDialog(
      BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Permissions Required'),
          ],
        ),
        content: const Text(
          'Safe Connect needs these permissions to work:\n\n'
          '📍 Location — for Bluetooth scanning\n'
          '📶 Nearby Devices — for Bluetooth chat\n'
          '💬 SMS — for emergency alerts\n'
          '👥 Contacts — for emergency contacts\n'
          '🔔 Notifications — for SOS alerts\n\n'
          'Please open Settings and allow all permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
