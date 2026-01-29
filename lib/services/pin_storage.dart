import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinStorage {
  static final _storage = FlutterSecureStorage();

  /// Save PIN for a user
  static Future<void> savePin(String userId, String pin) async {
    await _storage.write(key: 'user_pin_$userId', value: pin);
  }

  /// Get saved PIN for a user
  static Future<String?> getPin(String userId) async {
    return await _storage.read(key: 'user_pin_$userId');
  }

  /// Delete PIN for a user
  static Future<void> deletePin(String userId) async {
    await _storage.delete(key: 'user_pin_$userId');
  }
}
