import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/services/connectivity_service.dart';
import 'core/utils/logger.dart';
import 'core/utils/permissions.dart';
import 'data/remote/firebase/fcm_service.dart';
import 'data/remote/firebase/firestore_service.dart';
import 'features/bluetooth/controllers/bluetooth_controller.dart';
import 'features/chat/controllers/chat_controller.dart';
import 'features/sos/controllers/sos_controller.dart';
import 'features/home/screens/main_shell.dart';
import 'core/services/encryption_service.dart';
import 'features/home/controllers/home_controller.dart';
import 'core/services/notification_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  try {
    // ── FIXED: pass FirebaseOptions explicitly so it works on Android ──
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyC4SQ2DnpejlwdRJs4VEbNUo-Dt7NqH_FM',
        appId: '1:1078415121786:android:4849356f161ddecc514ac3',
        messagingSenderId: '1078415121786',
        projectId: 'safe-connect-6d7ed',
        storageBucket: 'safe-connect-6d7ed.firebasestorage.app',
      ),
    );
    AppLogger.success('Firebase initialized ✅', tag: 'main');

    // Anonymous auth for Firestore security rules
    await FirestoreService.signInAnonymously();
  } catch (e) {
    AppLogger.error('Firebase init failed', tag: 'main', error: e);
  }

  EncryptionService.initialize();

  if (!kIsWeb) {
    await NotificationService.initialize();
  }

  if (!kIsWeb) {
    FlutterNativeSplash.remove();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<ConnectivityService>(
          create: (_) => ConnectivityService(),
          dispose: (_, s) => s.dispose(),
        ),
        ChangeNotifierProvider<BluetoothController>(
          create: (_) => BluetoothController(),
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
        ChangeNotifierProxyProvider2<BluetoothController, FcmService,
            SosController>(
          create: (context) {
            final ctrl = SosController(
              bluetoothController: context.read<BluetoothController>(),
              fcmService: context.read<FcmService>(),
            );
            ctrl.startMonitoring();
            return ctrl;
          },
          update: (_, bluetooth, fcm, previous) =>
              previous ??
              SosController(
                bluetoothController: bluetooth,
                fcmService: fcm,
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

class SafeConnectApp extends StatefulWidget {
  const SafeConnectApp({super.key});

  @override
  State<SafeConnectApp> createState() => _SafeConnectAppState();
}

class _SafeConnectAppState extends State<SafeConnectApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Step 1 — request permissions (mobile only)
      if (!kIsWeb) {
        await AppPermissions.requestAll(context);
      }

      if (!mounted) return;

      // Step 2 — initialize BluetoothController (mobile only)
      if (!kIsWeb) {
        await context.read<BluetoothController>().initialize();
      }

      if (!mounted) return;

      // Step 3 — initialize FCM
      final bt = context.read<BluetoothController>();
      await context.read<FcmService>().initialize(
            deviceId: bt.deviceId,
            deviceName: bt.deviceName,
          );

      if (!mounted) return;

      // Step 4 — save FCM token to Firestore
      if (!kIsWeb) {
        final fcmToken = context.read<FcmService>().fcmToken;
        if (fcmToken != null) {
          await FirestoreService.saveFcmToken(
            deviceId: bt.deviceId,
            deviceName: bt.deviceName,
            fcmToken: fcmToken,
          );
          AppLogger.success(
            'FCM token registered in Firestore ✅',
            tag: 'main',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const MainShell(),
    );
  }
}