import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[ℹ️ INFO${tag != null ? ' | $tag' : ''}] $message');
    }
  }

  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[✅ SUCCESS${tag != null ? ' | $tag' : ''}] $message');
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[⚠️ WARNING${tag != null ? ' | $tag' : ''}] $message');
    }
  }

  static void error(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      debugPrint('[❌ ERROR${tag != null ? ' | $tag' : ''}] $message');
      if (error != null) debugPrint('   → $error');
    }
  }

  static void bluetooth(String message) {
    if (kDebugMode) {
      debugPrint('[🔵 BLUETOOTH] $message');
    }
  }

  static void sos(String message) {
    if (kDebugMode) {
      debugPrint('[🆘 SOS] $message');
    }
  }
}