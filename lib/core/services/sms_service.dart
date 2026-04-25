import 'package:flutter/services.dart';
import '../utils/logger.dart';

class SmsService {
  static const MethodChannel _channel =
      MethodChannel('com.safeconnect.sms/send');

  static Future<bool> sendSos({
    required String phoneNumber,
    required String userName,
    required String locationText,
  }) async {
    final message =
        '🆘 EMERGENCY ALERT!\n'
        '$userName needs help!\n\n'
        '📍 Location:\n$locationText\n\n'
        'Sent via Safe Connect Emergency App';

    return sendSms(phoneNumber: phoneNumber, message: message);
  }

  static Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      AppLogger.success('SMS sent to $phoneNumber ✅', tag: 'SMS');
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('SMS failed: ${e.message}', tag: 'SMS');
      return false;
    } catch (e) {
      AppLogger.error('SMS error', tag: 'SMS', error: e);
      return false;
    }
  }
}