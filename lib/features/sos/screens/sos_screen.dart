import 'emergency_contacts_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/user_preferences.dart';
import '../controllers/sos_controller.dart';
import 'sos_history_screen.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadSavedContact();
  }

  Future<void> _loadSavedContact() async {
    final contact = await UserPreferences.getEmergencyContact();
    final name = await UserPreferences.getUserName();
    if (mounted) {
      _contactController.text = contact ?? '';
      _nameController.text = name;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _contactController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SosController>(
      builder: (context, sos, _) {
        return Scaffold(
          backgroundColor: _getBackgroundColor(sos.state),
          appBar: AppBar(
          backgroundColor: AppColors.danger,
          title: const Text('SOS Emergency'),
          actions: [
          // History button
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
              context,
                  MaterialPageRoute(
                    builder: (_) => const SosHistoryScreen(),
                  ),
                ),
                tooltip: 'SOS History',
              ),
              // Contacts button
              IconButton(
                icon: const Icon(Icons.contacts),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmergencyContactsScreen(),
                  ),
                ),
                tooltip: 'Emergency Contacts',
              ),
              // Settings button
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettingsDialog(context),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildStatusBanner(sos),
                const SizedBox(height: 32),
                _buildSOSButton(context, sos),
                const SizedBox(height: 32),
                if (sos.state == SosState.active) _buildSentChannels(sos),
                if (sos.state == SosState.active) _buildResetButton(sos),
                if (sos.state == SosState.idle) _buildInfoCards(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Background Color by State ────────────────────────────────────
  Color _getBackgroundColor(SosState state) {
    switch (state) {
      case SosState.countdown:
        return const Color(0xFFFFEBEE);
      case SosState.sending:
        return const Color(0xFFFFEBEE);
      case SosState.active:
        return const Color(0xFFFFCDD2);
      case SosState.cancelled:
        return const Color(0xFFF5F5F5);
      default:
        return const Color(0xFFFFF5F5);
    }
  }

  // ── Status Banner ────────────────────────────────────────────────
  Widget _buildStatusBanner(SosController sos) {
    Color color;
    IconData icon;

    switch (sos.state) {
      case SosState.countdown:
        color = AppColors.danger;
        icon = Icons.timer;
        break;
      case SosState.sending:
        color = AppColors.warning;
        icon = Icons.send;
        break;
      case SosState.active:
        color = AppColors.danger;
        icon = Icons.warning_amber_rounded;
        break;
      case SosState.cancelled:
        color = AppColors.success;
        icon = Icons.check_circle;
        break;
      default:
        color = AppColors.textSecondary;
        icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sos.statusMessage,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (sos.state == SosState.sending)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  // ── SOS Button ───────────────────────────────────────────────────
  Widget _buildSOSButton(BuildContext context, SosController sos) {
    return Center(
      child: Column(
        children: [
          // Countdown ring
          if (sos.state == SosState.countdown)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${sos.countdown}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: AppColors.danger,
                ),
              ),
            ),

          // Main SOS button
          ScaleTransition(
            scale: sos.state == SosState.idle ||
                    sos.state == SosState.countdown
                ? _pulseAnimation
                : const AlwaysStoppedAnimation(1.0),
            child: GestureDetector(
              onLongPressStart: (_) {
                if (sos.state == SosState.idle) {
                  sos.startCountdown();
                }
              },
              onTap: () {
                if (sos.state == SosState.countdown) {
                  sos.cancelSOS();
                }
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sos.state == SosState.active
                      ? AppColors.dangerDark
                      : AppColors.danger,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.5),
                      blurRadius: sos.state == SosState.countdown ? 40 : 20,
                      spreadRadius: sos.state == SosState.countdown ? 15 : 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      sos.state == SosState.countdown
                          ? Icons.cancel
                          : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sos.state == SosState.countdown
                          ? 'TAP TO\nCANCEL'
                          : sos.state == SosState.active
                              ? 'SOS\nACTIVE'
                              : 'SOS',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            sos.state == SosState.idle
                ? 'Hold button for 1 second to activate'
                : sos.state == SosState.countdown
                    ? 'Tap button to CANCEL'
                    : '',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sent Channels Status ─────────────────────────────────────────
  Widget _buildSentChannels(SosController sos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SOS SENT VIA:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildChannelStatus(
            icon: Icons.bluetooth,
            label: 'Bluetooth Broadcast',
            sent: sos.bluetoothSent,
          ),
          _buildChannelStatus(
            icon: Icons.wifi,
            label: 'Internet (Firebase)',
            sent: sos.onlineSent,
          ),
          _buildChannelStatus(
            icon: Icons.sms,
            label: 'SMS to Emergency Contact',
            sent: sos.smsSent,
          ),
          if (sos.lastPosition != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS: ${sos.lastPosition!.latitude.toStringAsFixed(4)}, '
                      '${sos.lastPosition!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelStatus({
    required IconData icon,
    required String label,
    required bool sent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: sent ? AppColors.success : AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: sent ? AppColors.textPrimary : AppColors.textHint,
              ),
            ),
          ),
          Icon(
            sent ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: sent ? AppColors.success : AppColors.textHint,
          ),
        ],
      ),
    );
  }

  // ── Reset Button ─────────────────────────────────────────────────
  Widget _buildResetButton(SosController sos) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ElevatedButton.icon(
        onPressed: sos.resetSOS,
        icon: const Icon(Icons.refresh),
        label: const Text('Reset SOS'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textSecondary,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  // ── Info Cards ───────────────────────────────────────────────────
  Widget _buildInfoCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildInfoCard(
            icon: Icons.bluetooth,
            title: 'Bluetooth Broadcast',
            subtitle: 'Alerts all nearby Safe Connect users',
            color: AppColors.bluetooth,
          ),
          const SizedBox(height: 8),
          _buildInfoCard(
            icon: Icons.wifi,
            title: 'Internet Alert',
            subtitle: 'Sends via Firebase when online',
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _buildInfoCard(
            icon: Icons.sms,
            title: 'SMS Fallback',
            subtitle: 'Texts your emergency contact with GPS',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings Dialog ──────────────────────────────────────────────
  Future<void> _showSettingsDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Emergency Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                prefixIcon: Icon(Icons.person),
                hintText: 'e.g. John Doe',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Number',
                prefixIcon: Icon(Icons.phone),
                hintText: 'e.g. +91 9876543210',
              ),
            ),
          ],
        ),
        actions: [
  IconButton(
    icon: const Icon(Icons.contacts),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EmergencyContactsScreen(),
      ),
    ),
    tooltip: 'Emergency Contacts',
  ),
  IconButton(
    icon: const Icon(Icons.settings),
    onPressed: () => _showSettingsDialog(context),
    tooltip: 'Settings',
  ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await UserPreferences.setUserName(_nameController.text.trim());
              await UserPreferences.setEmergencyContact(
                _contactController.text.trim(),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Emergency settings saved!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}