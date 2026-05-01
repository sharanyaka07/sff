import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/services/connectivity_service.dart';
import 'core/utils/logger.dart';
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
  WidgetsFlutterBinding.ensureInitialized();

  // Correct
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

  // Initialize encryption
EncryptionService.initialize();

// Initialize notifications
await NotificationService.initialize();

// Start listening for SOS broadcasts from nearby devices
await BleScannerService.startListeningForSOS();

// Remove splash screen
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
        ChangeNotifierProxyProvider3<ConnectivityService, BluetoothController,
            FcmService, ChatController>(
          create: (context) => ChatController(
            connectivityService: context.read<ConnectivityService>(),
            bluetoothController: context.read<BluetoothController>(),
            fcmService: context.read<FcmService>(),
          ),
          update: (_, connectivity, bluetooth, fcm, previous) =>
              previous ??
              ChatController(
                connectivityService: connectivity,
                bluetoothController: bluetooth,
                fcmService: fcm,
              ),
        ),
        ChangeNotifierProxyProvider2<BluetoothController, ChatController,
            SosController>(
          create: (context) => SosController(
            bluetoothController: context.read<BluetoothController>(),
            chatController: context.read<ChatController>(),
          ),
          update: (_, bluetooth, chat, previous) =>
              previous ??
              SosController(
                bluetoothController: bluetooth,
                chatController: chat,
              ),
        ),
        ChangeNotifierProvider<HomeController>(
          create: (_) => HomeController(),
        ),
      ],
      child: const SafeConnectApp(),
    ),
  );
}

class SafeConnectApp extends StatelessWidget {
  const SafeConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bt = context.read<BluetoothController>();
      context.read<FcmService>().initialize(
            deviceId: bt.deviceId,
            deviceName: bt.deviceName,
          );
    });

    return MaterialApp(
      title: 'Safe Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainShell(),
    );
  }
}