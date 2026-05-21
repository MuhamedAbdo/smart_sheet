// lib/services/safe_secure_storage.dart
//
// Safe, platform-robust wrapper for secure storage.
// Falls back to Hive 'settings' box on Windows/Web or when FlutterSecureStorage throws an error.
//

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SafeSecureStorage {
  static const _secureStorage = FlutterSecureStorage();
  static const _fallbackBoxName = 'settings';

  const SafeSecureStorage();

  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_fallbackBoxName)) {
      return Hive.box(_fallbackBoxName);
    } else {
      return await Hive.openBox(_fallbackBoxName);
    }
  }

  Future<String?> read({required String key}) async {
    if (kIsWeb || Platform.isWindows) {
      return await _readFallback(key);
    }
    
    try {
      final val = await _secureStorage.read(key: key);
      return val;
    } catch (e) {
      debugPrint('⚠️ SafeSecureStorage.read ($key) failed: $e. Falling back to Hive...');
      return await _readFallback(key);
    }
  }

  Future<void> write({required String key, required String value}) async {
    if (kIsWeb || Platform.isWindows) {
      await _writeFallback(key, value);
      return;
    }

    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      debugPrint('⚠️ SafeSecureStorage.write ($key) failed: $e. Falling back to Hive...');
      await _writeFallback(key, value);
    }
  }

  Future<void> delete({required String key}) async {
    if (kIsWeb || Platform.isWindows) {
      await _deleteFallback(key);
      return;
    }

    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      debugPrint('⚠️ SafeSecureStorage.delete ($key) failed: $e. Falling back to Hive...');
      await _deleteFallback(key);
    }
  }

  Future<String?> _readFallback(String key) async {
    try {
      final box = await _getBox();
      return box.get(key)?.toString();
    } catch (e) {
      debugPrint('❌ SafeSecureStorage fallback read error: $e');
      return null;
    }
  }

  Future<void> _writeFallback(String key, String value) async {
    try {
      final box = await _getBox();
      await box.put(key, value);
    } catch (e) {
      debugPrint('❌ SafeSecureStorage fallback write error: $e');
    }
  }

  Future<void> _deleteFallback(String key) async {
    try {
      final box = await _getBox();
      await box.delete(key);
    } catch (e) {
      debugPrint('❌ SafeSecureStorage fallback delete error: $e');
    }
  }
}
