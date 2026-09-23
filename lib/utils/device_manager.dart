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

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';

class DeviceManager {
  static Future<String> getDeviceId() async {
    // فتح صندوق pairing_vault الدائم
    final Box box;
    if (Hive.isBoxOpen(SafeSecureStorage.pairingVaultBoxName)) {
      box = Hive.box(SafeSecureStorage.pairingVaultBoxName);
    } else {
      box = await Hive.openBox(SafeSecureStorage.pairingVaultBoxName);
    }

    String? deviceId = box.get('device_id')?.toString();

    // ─── Legacy Migration: نقل device_id القديم من settings إذا وُجد ─────────
    if (deviceId == null && Hive.isBoxOpen('settings')) {
      final legacyId = Hive.box('settings').get('device_id')?.toString();
      if (legacyId != null && legacyId.isNotEmpty) {
        deviceId = legacyId;
        await box.put('device_id', deviceId);
        // حذفه من settings حتى لا يُربك عمليات القراءة المستقبلية
        await Hive.box('settings').delete('device_id');
        debugPrint('🔄 DeviceManager: device_id مُرحَّل من settings إلى pairing_vault');
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await box.put('device_id', deviceId);
      debugPrint('🆔 DeviceManager: تم توليد device_id جديد: $deviceId');
    }

    return deviceId;
  }
}
