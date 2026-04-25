import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import '../utils/logger.dart';

class EncryptionService {
  // ── Shared secret key for all Safe Connect devices ───────────────
  // In production this would be exchanged via QR code
  // For this project all devices share the same key
  static const String _sharedSecret = 'SafeConnect2024SecretKey12345678';
  static const String _sharedIV = 'SafeConnectIV123';

  static late final Key _key;
  static late final IV _iv;
  static late final Encrypter _encrypter;
  static bool _initialized = false;

  // ── Initialize ───────────────────────────────────────────────────
  static void initialize() {
    if (_initialized) return;

    try {
      // AES-256 requires exactly 32 bytes key
      final keyBytes = utf8.encode(_sharedSecret).sublist(0, 32);
      // AES CBC requires exactly 16 bytes IV
      final ivBytes = utf8.encode(_sharedIV).sublist(0, 16);

      _key = Key(Uint8List.fromList(keyBytes));
      _iv = IV(Uint8List.fromList(ivBytes));
      _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

      _initialized = true;
      AppLogger.success('Encryption initialized ✅', tag: 'CRYPTO');
    } catch (e) {
      AppLogger.error('Encryption init failed', tag: 'CRYPTO', error: e);
    }
  }

  // ── Encrypt a message ────────────────────────────────────────────
  static String encrypt(String plainText) {
    if (!_initialized) initialize();

    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      // Return base64 encoded string
      final result = encrypted.base64;
      AppLogger.info('Message encrypted ✅', tag: 'CRYPTO');
      return result;
    } catch (e) {
      AppLogger.error('Encryption failed', tag: 'CRYPTO', error: e);
      // Return original if encryption fails
      return plainText;
    }
  }

  // ── Decrypt a message ────────────────────────────────────────────
  static String decrypt(String encryptedBase64) {
    if (!_initialized) initialize();

    try {
      final encrypted = Encrypted.fromBase64(encryptedBase64);
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      AppLogger.info('Message decrypted ✅', tag: 'CRYPTO');
      return decrypted;
    } catch (e) {
      AppLogger.error('Decryption failed', tag: 'CRYPTO', error: e);
      // Return original if decryption fails
      return encryptedBase64;
    }
  }

  // ── Check if a string looks encrypted ───────────────────────────
  static bool isEncrypted(String text) {
    try {
      // Base64 encoded strings have specific characteristics
      final decoded = base64.decode(text);
      return decoded.length % 16 == 0 && decoded.length >= 16;
    } catch (_) {
      return false;
    }
  }

  // ── Generate a random key (for future QR sharing feature) ────────
  static String generateRandomKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(values);
  }
}