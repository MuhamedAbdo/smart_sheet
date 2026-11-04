// lib/utils/device_manager.dart
//
// إدارة هوية الجهاز الدائمة (Device Identity)
//
// يُولَّد UUID عشوائي مرة واحدة عند أول تشغيل ويُخزَّن في صندوق [pairing_vault]
// الدائم بدلاً من صندوق [settings]، لضمان عدم فقدانه عند:
//   • تسجيل الخروج العادي
//   • forceLogout() من نظام Kill Switch
//   • تحديث التطبيق (APK/EXE)
//
// لا يتغير device_id إلا عند: (1) Uninstall كامل + مسح البيانات، (2) طلب صريح.

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';

class DeviceManager {
  static Future<String> getDeviceId() async {
    // 1. فحص SharedPreferences أولاً (الطبقة الأكثر ثباتاً عبر التحديثات)
    String? deviceId;
    try {
      final prefs = await SharedPreferences.getInstance();
      deviceId = prefs.getString('device_id');
    } catch (_) {}

    // 2. فتح صندوق pairing_vault الدائم
    final Box box;
    if (Hive.isBoxOpen(SafeSecureStorage.pairingVaultBoxName)) {
      box = Hive.box(SafeSecureStorage.pairingVaultBoxName);
    } else {
      box = await Hive.openBox(SafeSecureStorage.pairingVaultBoxName);
    }

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = box.get('device_id')?.toString();
    }

    // ─── Legacy Migration: نقل device_id القديم من settings إذا وُجد ─────────
    if ((deviceId == null || deviceId.isEmpty) && Hive.isBoxOpen('settings')) {
      final legacyId = Hive.box('settings').get('device_id')?.toString();
      if (legacyId != null && legacyId.isNotEmpty) {
        deviceId = legacyId;
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

    final String resolvedDeviceId = (deviceId != null && deviceId.isNotEmpty)
        ? deviceId
        : const Uuid().v4();

    // مزامنة وتثبيت device_id في جميع الطبقات الدائمة
    await box.put('device_id', resolvedDeviceId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_id', resolvedDeviceId);
    } catch (_) {}

    return resolvedDeviceId;
  }
}
