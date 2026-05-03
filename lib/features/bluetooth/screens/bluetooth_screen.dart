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
  // Track which device is currently being connected to
  String? _connectingDeviceId;

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
              // Show advertising icon
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Tooltip(
                  message: bt.isAdvertising
                      ? 'Broadcasting — visible to nearby devices'
                      : 'Not broadcasting',
                  child: Icon(
                    Icons.broadcast_on_personal,
                    color: bt.isAdvertising ? Colors.white : Colors.white38,
                    size: 20,
                  ),
                ),
              ),
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
              _buildAdvertisingBanner(bt),
              // ── Connected devices section ──────────────────────────
              if (bt.connectedDevices.isNotEmpty)
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
        text = 'Scanning for nearby devices...';
        icon = Icons.bluetooth_searching;
        break;
      case BtConnectionState.connecting:
        color = AppColors.warning;
        text = 'Connecting...';
        icon = Icons.bluetooth_searching;
        break;
      case BtConnectionState.connected:
        final count = bt.connectedDevices.length;
        color = AppColors.success;
        text = 'Connected to $count device${count > 1 ? 's' : ''}';
        icon = Icons.bluetooth_connected;
        break;
      case BtConnectionState.off:
        color = AppColors.danger;
        text = 'Bluetooth is OFF or permissions denied';
        icon = Icons.bluetooth_disabled;
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

  // ── Advertising Banner ─────────────────────────────────────────
  Widget _buildAdvertisingBanner(BluetoothController bt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: bt.isAdvertising
          ? AppColors.success.withValues(alpha: 0.08)
          : AppColors.textHint.withValues(alpha: 0.05),
      child: Row(
        children: [
          Icon(
            bt.isAdvertising
                ? Icons.broadcast_on_personal
                : Icons.broadcast_on_personal_outlined,
            size: 16,
            color:
                bt.isAdvertising ? AppColors.success : AppColors.textHint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bt.isAdvertising
                  ? '📡 Broadcasting — nearby Safe Connect devices can find you'
                  : 'Not broadcasting',
              style: TextStyle(
                fontSize: 12,
                color: bt.isAdvertising
                    ? AppColors.success
                    : AppColors.textHint,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
      valueColor:
          AlwaysStoppedAnimation<Color>(AppColors.bluetoothActive),
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

  // ── Connected Devices Section ──────────────────────────────────
  Widget _buildConnectedSection(BluetoothController bt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.link, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              const Text(
                'CONNECTED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${bt.connectedDevices.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...bt.connectedDevices.map((device) {
          final name = device.platformName.isNotEmpty
              ? device.platformName
              : device.remoteId.str;
          return _ConnectedDeviceTile(
            name: name,
            address: device.remoteId.str,
            onDisconnect: () async {
              await bt.disconnectDevice(device);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Disconnected from $name'),
                    backgroundColor: AppColors.textSecondary,
                  ),
                );
              }
            },
          );
        }),
        const Divider(height: 1),
      ],
    );
  }

  // ── Helper: Check if device is likely a non-phone ─────────────
  bool _isLikelyNonPhone(String deviceName) {
    final name = deviceName.toLowerCase();
    
    // List of keywords that indicate NON-PHONE devices
    return name.contains('watch') ||      // Smartwatches
           name.contains('band') ||       // Fitness bands
           name.contains('tv') ||         // Smart TVs
           name.contains('stb') ||        // Set-top boxes
           name.contains('buds') ||       // Earbuds
           name.contains('speaker') ||    // Bluetooth speakers
           name.contains('headphone') ||  // Headphones
           name.contains('headset') ||    // Headsets
           name.contains('airpod') ||     // AirPods
           name.contains('jbl') ||        // JBL speakers
           name.contains('bose') ||       // Bose audio
           name.contains('sony wh') ||    // Sony headphones
           name.contains('beats') ||      // Beats headphones
           name.contains('soundbar') ||   // Soundbars
           name.contains('laptop') ||     // Laptops
           name.contains('macbook') ||    // MacBooks
           name.contains('pc') ||         // PCs
           name.contains('printer') ||    // Printers
           name.contains('mouse') ||      // Bluetooth mice
           name.contains('keyboard') ||   // Bluetooth keyboards
           name.contains('car') ||        // Car Bluetooth
           name.contains('audio');        // Generic audio devices
  }

  // ── Available/Nearby Section ───────────────────────────────────
  Widget _buildAvailableSection(BluetoothController bt) {
    // Filter: Show all devices EXCEPT obvious non-phones
    // This allows custom names like "J's device", "Sharanya", "Ravi's phone"
    final phoneDevices = bt.namedScanResults.where((result) {
      final deviceName = result.device.platformName;
      
      // Skip devices without names (show only named devices)
      if (deviceName.isEmpty) return false;
      
      // Filter out obvious non-phone devices
      return !_isLikelyNonPhone(deviceName);
    }).toList();

    // All phone devices are treated as Safe Connect candidates
    // UUID verification happens at connect time in connectToDevice()
    final safeConnectResults = phoneDevices;
    final otherResults = <ScanResult>[];

    return Expanded(
      child: phoneDevices.isEmpty
          ? _buildEmptyState(bt)
          : ListView(
              children: [
                // ── Nearby Devices (phones and custom names) ───────
                if (safeConnectResults.isNotEmpty) ...[
                  _buildSectionHeader(
                    '✅ NEARBY DEVICES',
                    '${safeConnectResults.length} found',
                    AppColors.success,
                  ),
                  ...safeConnectResults.map((result) {
                    final devId = result.device.remoteId.str;
                    final isAlreadyConnected = bt.connectedDevices
                        .any((d) => d.remoteId == result.device.remoteId);
                    final isConnecting = _connectingDeviceId == devId;

                    return _DeviceTile(
                      name: bt.getDisplayName(result),
                      subtitle: isAlreadyConnected
                          ? 'Connected — go to Chat to message'
                          : isConnecting
                              ? 'Connecting...'
                              : 'Tap to connect',
                      isConnected: isAlreadyConnected,
                      isConnecting: isConnecting,
                      isSafeConnect: true,
                      signalStrength: result.rssi,
                      onTap: () => _onSafeConnectDeviceTap(
                        context,
                        result,
                        bt,
                        isAlreadyConnected,
                      ),
                    );
                  }),
                ],

                // ── Other nearby devices (hidden - filtered out) ───
                if (otherResults.isNotEmpty) ...[
                  _buildSectionHeader(
                    'OTHER NEARBY DEVICES',
                    '${otherResults.length} found',
                    AppColors.textSecondary,
                  ),
                  ...otherResults.map((result) => _DeviceTile(
                        name: bt.getDisplayName(result),
                        subtitle: 'No Safe Connect — SOS only',
                        isConnected: false,
                        isConnecting: false,
                        isSafeConnect: false,
                        signalStrength: result.rssi,
                        onTap: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              '📱 ${bt.getDisplayName(result)} does not have Safe Connect — '
                              'SOS broadcasts will still reach them.',
                            ),
                            backgroundColor: AppColors.warning,
                            duration: const Duration(seconds: 3),
                          ),
                        ),
                      )),
                ],
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            count,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
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
                  : Icons.devices,
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
                      '• Other device has Safe Connect open',
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

  // ── Safe Connect device tap → GATT connect ────────────────────
  Future<void> _onSafeConnectDeviceTap(
    BuildContext context,
    ScanResult result,
    BluetoothController bt,
    bool isAlreadyConnected,
  ) async {
    final name = bt.getDisplayName(result);

    if (isAlreadyConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Already connected to $name — go to Chat!'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }

    setState(() => _connectingDeviceId = result.device.remoteId.str);

    // Store messenger reference BEFORE async gap
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text('Connecting to $name...'),
          ],
        ),
        duration: const Duration(seconds: 10),
        backgroundColor: AppColors.bluetoothActive,
      ),
    );

    final success = await bt.connectToDevice(result.device);

    if (mounted) {
      setState(() => _connectingDeviceId = null);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Connected to $name! Go to Chat to message them.'
                : '❌ Failed to connect to $name. Try again.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

// ── Connected Device Tile ──────────────────────────────────────────
class _ConnectedDeviceTile extends StatelessWidget {
  final String name;
  final String address;
  final VoidCallback onDisconnect;

  const _ConnectedDeviceTile({
    required this.name,
    required this.address,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.success.withValues(alpha: 0.15),
        child: const Icon(
          Icons.bluetooth_connected,
          color: AppColors.success,
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
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const Text(
            'Connected',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: TextButton.icon(
        onPressed: onDisconnect,
        icon: const Icon(Icons.link_off, size: 16),
        label: const Text('Disconnect'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.danger,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}

// ── Device Tile Widget ─────────────────────────────────────────────
class _DeviceTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isConnected;
  final bool isConnecting;
  final bool isSafeConnect;
  final int? signalStrength;
  final VoidCallback? onTap;

  const _DeviceTile({
    required this.name,
    required this.subtitle,
    required this.isConnected,
    required this.isConnecting,
    required this.isSafeConnect,
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
            : isSafeConnect
                ? AppColors.success.withValues(alpha: 0.08)
                : AppColors.bluetooth.withValues(alpha: 0.1),
        child: isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.bluetoothActive,
                ),
              )
            : Icon(
                isConnected
                    ? Icons.bluetooth_connected
                    : isSafeConnect
                        ? Icons.smartphone
                        : Icons.bluetooth,
                color: isConnected
                    ? AppColors.success
                    : isSafeConnect
                        ? AppColors.success
                        : AppColors.bluetooth,
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
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isConnected
              ? AppColors.success
              : isSafeConnect
                  ? AppColors.success.withValues(alpha: 0.8)
                  : AppColors.textHint,
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
      onTap: isConnecting ? null : onTap,
    );
  }
}