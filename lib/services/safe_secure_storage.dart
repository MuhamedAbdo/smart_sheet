// lib/services/safe_secure_storage.dart
//
// Safe, platform-robust wrapper for secure storage.
// Falls back to Hive on Windows/Web or when FlutterSecureStorage throws an error.
//
// ─── عزل بيانات الارتباط (Pairing Vault) ────────────────────────────────────
// المفاتيح الحيوية التالية تُخزَّن حصرياً في صندوق [pairing_vault] المنفصل:
//   • is_device_unlocked  ← حالة بوابة الجهاز (Gatekeeper)
//   • device_id           ← هوية الجهاز الدائمة (UUID)
//   • factory_id          ← ارتباط الجهاز بالمصنع
//   • linked_worker_id    ← معرّف العامل المرتبط
//   • is_suspended        ← حالة الإيقاف المؤقت
//   • user_role           ← دور المستخدم (admin / employee)
//
// هذا الصندوق لا تمسه forceLogout() أو تسجيل الخروج العادي إطلاقاً.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SafeSecureStorage {
  static const _secureStorage = FlutterSecureStorage();
  static const _settingsBoxName = 'settings';

  /// اسم صندوق بيانات الارتباط الدائم
  static const String pairingVaultBoxName = 'pairing_vault';

  /// المفاتيح الحيوية التي تُوجَّه لـ pairing_vault بدلاً من settings
  static const Set<String> _pairingVaultKeys = {
    'is_device_unlocked',
    'has_valid_code',
    'is_device_linked',
    'device_id',
    'factory_id',
    'linked_worker_id',
    'is_suspended',
    'user_role',
  };

  const SafeSecureStorage();

  // ─── فتح الصناديق ─────────────────────────────────────────────────────────

  Future<Box> _getSettingsBox() async {
    if (Hive.isBoxOpen(_settingsBoxName)) return Hive.box(_settingsBoxName);
    return await Hive.openBox(_settingsBoxName);
  }

  Future<Box> _getPairingVaultBox() async {
    if (Hive.isBoxOpen(pairingVaultBoxName)) return Hive.box(pairingVaultBoxName);
    return await Hive.openBox(pairingVaultBoxName);
  }

  bool _isPairingKey(String key) => _pairingVaultKeys.contains(key);

  // ─── القراءة ──────────────────────────────────────────────────────────────

  Future<String?> read({required String key}) async {
    if (kIsWeb || Platform.isWindows) {
      return await _readFallback(key);
    }
    try {
      final secureVal = await _secureStorage.read(key: key);
      if (secureVal != null && secureVal.isNotEmpty) {
        return secureVal;
      }
      return await _readFallback(key);
    } catch (e) {
      debugPrint('⚠️ SafeSecureStorage.read ($key) failed: $e. Falling back to SharedPreferences/Hive...');
      return await _readFallback(key);
    }
  }

  // ─── الكتابة ──────────────────────────────────────────────────────────────

  Future<void> write({required String key, required String value}) async {
    // 1. مزامنة فورية في SharedPreferences (الطبقة الأكثر ثباتاً عبر التحديثات)
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key == 'is_device_unlocked' || key == 'has_valid_code' || key == 'is_device_linked') {
        await prefs.setBool(key, value.toLowerCase() == 'true');
      } else {
        await prefs.setString(key, value);
      }
    } catch (e) {
      debugPrint('⚠️ SafeSecureStorage write to prefs error ($key): $e');
    }

    // 2. كتابة في Hive
    await _writeFallback(key, value);

    // 3. كتابة في SecureStorage على الموبايل
    if (!kIsWeb && !Platform.isWindows) {
      try {
        await _secureStorage.write(key: key, value: value);
      } catch (e) {
        debugPrint('⚠️ SafeSecureStorage.write ($key) failed: $e. Saved to Hive and Prefs.');
      }
    }
  }

  // ─── الحذف ────────────────────────────────────────────────────────────────

  Future<void> delete({required String key}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}

    await _deleteFallback(key);

    if (!kIsWeb && !Platform.isWindows) {
      try {
        await _secureStorage.delete(key: key);
      } catch (e) {
        debugPrint('⚠️ SafeSecureStorage.delete ($key) failed: $e');
      }
    }
  }

  // ─── Fallback: القراءة من SharedPreferences و Hive ─────────────────────────

  Future<String?> _readFallback(String key) async {
    try {
      if (_isPairingKey(key)) {
        // أولاً: pairing_vault (الصندوق الدائم)
        final vaultBox = await _getPairingVaultBox();
        final vaultVal = vaultBox.get(key)?.toString();
        if (vaultVal != null && vaultVal.isNotEmpty) return vaultVal;

        // ثانياً: SharedPreferences (الطبقة الأكثر صموداً عبر تحديثات التطبيق)
        try {
          final prefs = await SharedPreferences.getInstance();
          if (key == 'is_device_unlocked' || key == 'has_valid_code' || key == 'is_device_linked') {
            final bool? bVal = prefs.getBool(key);
            if (bVal != null) {
              await vaultBox.put(key, bVal);
              return bVal.toString();
            }
          } else {
            final String? sVal = prefs.getString(key);
            if (sVal != null && sVal.isNotEmpty) {
              await vaultBox.put(key, sVal);
              return sVal;
            }
          }
        } catch (_) {}

        // ثالثاً: legacy migration — قراءة من settings ونقلها للـ vault
        final settingsBox = await _getSettingsBox();
        final legacyVal = settingsBox.get(key)?.toString();
        if (legacyVal != null && legacyVal.isNotEmpty) {
          debugPrint('🔄 SafeSecureStorage: ترحيل "$key" من settings إلى pairing_vault');
          await vaultBox.put(key, legacyVal);
          return legacyVal;
        }
        return null;
      } else {
        final box = await _getSettingsBox();
        final val = box.get(key)?.toString();
        if (val != null && val.isNotEmpty) return val;

        try {
          final prefs = await SharedPreferences.getInstance();
          return prefs.get(key)?.toString();
        } catch (_) {
          return null;
        }
      }
    } catch (e) {
      debugPrint('❌ SafeSecureStorage fallback read error ($key): $e');
      return null;
    }
  }

  // ─── Fallback: الكتابة إلى Hive ──────────────────────────────────────────

  Future<void> _writeFallback(String key, String value) async {
    try {
      if (_isPairingKey(key)) {
        final vaultBox = await _getPairingVaultBox();
        if (key == 'is_device_unlocked' || key == 'has_valid_code' || key == 'is_device_linked') {
          await vaultBox.put(key, value.toLowerCase() == 'true');
        } else {
          await vaultBox.put(key, value);
        }
      } else {
        final box = await _getSettingsBox();
        if (key == 'is_device_unlocked' || key == 'has_valid_code' || key == 'is_device_linked') {
          await box.put(key, value.toLowerCase() == 'true');
        } else {
          await box.put(key, value);
        }
      }
    } catch (e) {
      debugPrint('❌ SafeSecureStorage fallback write error ($key): $e');
    }
  }

  // ─── Fallback: الحذف من Hive ─────────────────────────────────────────────

  Future<void> _deleteFallback(String key) async {
    try {
      if (_isPairingKey(key)) {
        final vaultBox = await _getPairingVaultBox();
        await vaultBox.delete(key);
      } else {
        final box = await _getSettingsBox();
        await box.delete(key);
      }
    } catch (e) {
      debugPrint('❌ SafeSecureStorage fallback delete error ($key): $e');
    }
  }
}
