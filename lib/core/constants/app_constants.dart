class AppConstants {
  // App Info
  static const String appName = 'Safe Connect';
  static const String appVersion = '1.0.0';

  // Bluetooth
  static const String serviceUUID = 'safe-connect-service-001';
  static const int bluetoothScanTimeout = 30; // seconds

  // SOS
  static const String sosMessage =
      '🆘 EMERGENCY! I need help. My location: ';
  static const int sosCountdownSeconds = 5;

  // Database
  static const String dbName = 'safe_connect.db';
  static const int dbVersion = 1;
  static const String messagesTable = 'messages';
  static const String sosLogsTable = 'sos_logs';

  // SharedPreferences Keys
  static const String keyUserName = 'user_name';
  static const String keyUserPhone = 'user_phone';
  static const String keyEmergencyContact = 'emergency_contact';
  static const String keyOnboardingDone = 'onboarding_done';

  // Connectivity
  static const int connectivityCheckInterval = 5; // seconds
}