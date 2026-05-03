import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/services/connectivity_service.dart';
import 'core/utils/logger.dart';
import 'core/utils/permissions.dart';
import 'data/remote/firebase/fcm_service.dart';
import 'features/bluetooth/controllers/bluetooth_controller.dart';
import 'features/chat/controllers/chat_controller.dart';
import 'features/sos/controllers/sos_controller.dart';
import 'features/home/screens/main_shell.dart';
import 'core/services/encryption_service.dart';
import 'features/home/controllers/home_controller.dart';
import 'core/services/notification_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/services/ble_scanner_service.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp();
    AppLogger.success('Firebase initialized ✅', tag: 'main');
  } catch (e) {
    AppLogger.error('Firebase init failed', tag: 'main', error: e);
  }

  EncryptionService.initialize();
  await NotificationService.initialize();
  await BleScannerService.startListeningForSOS();

  FlutterNativeSplash.remove();

  runApp(
    MultiProvider(
      providers: [
        Provider<ConnectivityService>(
          create: (_) => ConnectivityService(),
          dispose: (_, s) => s.dispose(),
        ),
        ChangeNotifierProvider<BluetoothController>(
          create: (_) => BluetoothController()..initialize(),
        ),
        ChangeNotifierProvider<FcmService>(
          create: (_) => FcmService(),
        ),
        ChangeNotifierProxyProvider<BluetoothController, ChatController>(
          create: (context) => ChatController(
            bluetoothController: context.read<BluetoothController>(),
          ),
          update: (_, bluetooth, previous) =>
              previous ?? ChatController(bluetoothController: bluetooth),
        ),
        ChangeNotifierProxyProvider<BluetoothController, SosController>(
          create: (context) {
            final ctrl = SosController(
              bluetoothController: context.read<BluetoothController>(),
            );
            ctrl.startMonitoring();
            return ctrl;
          },
          update: (_, bluetooth, previous) =>
              previous ?? SosController(bluetoothController: bluetooth),
        ),
        ChangeNotifierProvider<HomeController>(
          create: (_) => HomeController(),
        ),
      ],
      child: const SafeConnectApp(),
    ),
  );
}

class SafeConnectApp extends StatefulWidget {
  const SafeConnectApp({super.key});

  @override
  State<SafeConnectApp> createState() => _SafeConnectAppState();
}

class _SafeConnectAppState extends State<SafeConnectApp> {
  @override
  void initState() {
    super.initState();
    // Request all permissions as soon as app starts
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // First request all permissions
      await AppPermissions.requestAll(context);

      // Then initialize FCM after permissions granted
      if (mounted) {
        final bt = context.read<BluetoothController>();
        context.read<FcmService>().initialize(
              deviceId: bt.deviceId,
              deviceName: bt.deviceName,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainShell(),
    );
  }
}