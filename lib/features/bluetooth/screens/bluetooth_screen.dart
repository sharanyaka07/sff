import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../controllers/bluetooth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/permissions.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        context.read<BluetoothController>().startScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothController>(
      builder: (context, bt, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Bluetooth Devices'),
            actions: [
              IconButton(
                icon: Icon(bt.isScanning ? Icons.stop : Icons.refresh),
                onPressed: bt.isScanning
                    ? () => bt.stopScan()
                    : () => bt.startScan(),
                tooltip: bt.isScanning ? 'Stop scan' : 'Scan again',
              ),
            ],
          ),
          body: Column(
            children: [
              _buildStatusBanner(bt),
              if (bt.isScanning) _buildScanningIndicator(),
              if (bt.state == BtConnectionState.off)
                _buildFixPermissionsButton(),
              _buildConnectedSection(bt),
              _buildAvailableSection(bt),
            ],
          ),
        );
      },
    );
  }

  // ── Status Banner ──────────────────────────────────────────────
  Widget _buildStatusBanner(BluetoothController bt) {
    Color color;
    String text;
    IconData icon;

    switch (bt.state) {
      case BtConnectionState.scanning:
        color = AppColors.bluetoothActive;
        text = 'Scanning for Safe Connect devices...';
        icon = Icons.bluetooth_searching;
        break;
      case BtConnectionState.connected:
        color = AppColors.success;
        text = 'Connected to ${bt.connectedDevices.length} device(s)';
        icon = Icons.bluetooth_connected;
        break;
      case BtConnectionState.off:
        color = AppColors.danger;
        text = 'Bluetooth is OFF or permissions denied';
        icon = Icons.bluetooth_disabled;
        break;
      case BtConnectionState.connecting:
        color = AppColors.warning;
        text = 'Connecting...';
        icon = Icons.bluetooth_searching;
        break;
      default:
        color = AppColors.textSecondary;
        text = 'Ready to scan';
        icon = Icons.bluetooth;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scanning Indicator ─────────────────────────────────────────
  Widget _buildScanningIndicator() {
    return const LinearProgressIndicator(
      backgroundColor: Color(0xFFE3F2FD),
      valueColor: AlwaysStoppedAnimation<Color>(AppColors.bluetoothActive),
    );
  }

  // ── Fix Permissions Button ─────────────────────────────────────
  Widget _buildFixPermissionsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () async {
          await AppPermissions.showPermissionDialog(context);
          if (mounted) {
            context.read<BluetoothController>().startScan();
          }
        },
        icon: const Icon(Icons.settings),
        label: const Text('Fix Bluetooth Permissions'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  // ── Connected Section ──────────────────────────────────────────
  Widget _buildConnectedSection(BluetoothController bt) {
    if (bt.connectedDevices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'CONNECTED',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...bt.connectedDevices.map(
          (device) => _DeviceTile(
            name: device.platformName.isEmpty
                ? 'Unknown Device'
                : device.platformName,
            subtitle: device.remoteId.str,
            isConnected: true,
            signalStrength: null,
            onTap: () => _showDisconnectDialog(context, device, bt),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  // ── Available Section ──────────────────────────────────────────
  Widget _buildAvailableSection(BluetoothController bt) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'NEARBY DEVICES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${bt.scanResults.length} found',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: bt.scanResults.isEmpty
                ? _buildEmptyState(bt)
                : ListView.builder(
                    itemCount: bt.scanResults.length,
                    itemBuilder: (context, index) {
                      final result = bt.scanResults[index];
                      final isAlreadyConnected = bt.connectedDevices.any(
                        (d) => d.remoteId == result.device.remoteId,
                      );
                      return _DeviceTile(
                        name: result.device.platformName.isEmpty
                            ? 'Unknown Device'
                            : result.device.platformName,
                        subtitle: result.device.remoteId.str,
                        isConnected: isAlreadyConnected,
                        signalStrength: result.rssi,
                        onTap: isAlreadyConnected
                            ? null
                            : () => _connectToDevice(
                                  context,
                                  result.device,
                                  bt,
                                ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────
  Widget _buildEmptyState(BluetoothController bt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              bt.isScanning
                  ? Icons.bluetooth_searching
                  : Icons.bluetooth_disabled,
              size: 80,
              color: bt.isScanning
                  ? AppColors.bluetoothActive
                  : AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              bt.isScanning
                  ? 'Scanning for nearby devices...'
                  : 'No devices found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bt.isScanning
                  ? 'Make sure other devices have\nSafe Connect open'
                  : 'Make sure:\n'
                      '• Bluetooth is ON\n'
                      '• Location is ON\n'
                      '• Other device has app open',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (!bt.isScanning)
              ElevatedButton.icon(
                onPressed: bt.startScan,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Connect to Device ──────────────────────────────────────────
  Future<void> _connectToDevice(
    BuildContext context,
    BluetoothDevice device,
    BluetoothController bt,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Connecting to ${device.platformName}...'),
        backgroundColor: AppColors.bluetooth,
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await bt.connectToDevice(device);

    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Connected to ${device.platformName}'
                : '❌ Failed to connect',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Disconnect Dialog ──────────────────────────────────────────
  Future<void> _showDisconnectDialog(
    BuildContext context,
    BluetoothDevice device,
    BluetoothController bt,
  ) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect?'),
        content: Text('Disconnect from ${device.platformName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              bt.disconnectDevice(device);
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}

// ── Device Tile Widget ─────────────────────────────────────────────
class _DeviceTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isConnected;
  final int? signalStrength;
  final VoidCallback? onTap;

  const _DeviceTile({
    required this.name,
    required this.subtitle,
    required this.isConnected,
    required this.signalStrength,
    this.onTap,
  });

  IconData _signalIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_wifi_4_bar;
    if (rssi >= -75) return Icons.network_wifi_3_bar;
    if (rssi >= -85) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isConnected
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.bluetooth.withValues(alpha: 0.1),
        child: Icon(
          isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: isConnected ? AppColors.success : AppColors.bluetooth,
          size: 20,
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        isConnected ? '✅ Connected' : subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isConnected ? AppColors.success : AppColors.textHint,
        ),
      ),
      trailing: signalStrength != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _signalIcon(signalStrength!),
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                Text(
                  '$signalStrength dBm',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            )
          : null,
      onTap: onTap,
    );
  }
}