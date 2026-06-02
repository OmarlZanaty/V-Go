import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  CacheHelper._();

  static late SharedPreferences _sharedPreferences;

  static AndroidOptions _getAndroidOptions() =>
      const AndroidOptions(encryptedSharedPreferences: true);

  static final FlutterSecureStorage _flutterSecureStorage =
      FlutterSecureStorage(aOptions: _getAndroidOptions());

  static Future<void> init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  // ---------- SharedPreferences (non-secret) ----------
  static Future<void> setData({
    required String key,
    required dynamic value,
  }) async {
    if (value is bool) {
      await _sharedPreferences.setBool(key, value);
    } else if (value is String) {
      await _sharedPreferences.setString(key, value);
    } else if (value is int) {
      await _sharedPreferences.setInt(key, value);
    } else if (value is double) {
      await _sharedPreferences.setDouble(key, value);
    } else if (value is List<String>) {
      await _sharedPreferences.setStringList(key, value);
    } else {
      throw ArgumentError('Unsupported type');
    }
  }

  static String getString(String key) =>
      _sharedPreferences.getString(key) ?? '';

  static bool getBool(String key) => _sharedPreferences.getBool(key) ?? false;

  static Future<bool> removeData({required String key}) async {
    return _sharedPreferences.remove(key);
  }

  // ---------- Secure storage (tokens) ----------
  static Future<void> setSecuredString(String key, String value) async {
    await _flutterSecureStorage.write(key: key, value: value);
  }

  static Future<String> getSecuredString(String key) async {
    return await _flutterSecureStorage.read(key: key) ?? '';
  }

  static Future<void> removeSecuredString(String key) async {
    await _flutterSecureStorage.delete(key: key);
  }

  static Future<void> clearAllSecuredData() async {
    if (kDebugMode) {
      debugPrint('FlutterSecureStorage: all data cleared');
    }
    await _flutterSecureStorage.deleteAll(
      iOptions: const IOSOptions(),
      aOptions: const AndroidOptions(resetOnError: true),
    );
  }
}
