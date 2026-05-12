import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_sheet/services/sync_service.dart';

class SupabaseManager {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      // encryptedSharedPreferences is deprecated and handled automatically by the library now
    ),
  );

  // ✅ مفاتيح التخزين (متزامنة مع AuthService)
  static const _kFactoryIdKey = 'factory_id_v2';
  static const _kFactoryIdKeyLegacy = 'factory_id';

  // Internal cache for factory_id
  static String? _cachedFactoryId;

  /// جلب الـ factory_id من التخزين الآمن
  static Future<String?> getFactoryId() async {
    // التحقق من حالة فك الارتباط في SyncService
    try {
      if (SyncService.isUnlinked) {
        debugPrint(
            '🚫 SupabaseManager: SyncService is unlinked, returning null');
        _cachedFactoryId = null;
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ Error checking SyncService unlink status: $e');
    }

    // استخدام الكاش أولاً
    if (_cachedFactoryId != null) {
      return _cachedFactoryId;
    }

    // ✅ قراءة المفتاح الجديد أولاً، مع تراجع للقديم
    final v2 = await _storage.read(key: _kFactoryIdKey);
    if (v2 != null) {
      _cachedFactoryId = v2;
      return v2;
    }
    final legacy = await _storage.read(key: _kFactoryIdKeyLegacy);
    _cachedFactoryId = legacy;
    return legacy;
  }

  /// مسح الكاش الداخلي
  static void clearCache() {
    _cachedFactoryId = null;
    debugPrint('🧹 SupabaseManager: Cache cleared');
  }

  /// مسح المتغيرات البرمجية بالكامل
  static void clearAllVariables() {
    _cachedFactoryId = null;
    debugPrint('🧹 SupabaseManager: All variables cleared');
  }

  /// حفظ factory_id مع مفتاح دوار (Key Rotation)
  static Future<void> saveFactoryIdWithRotation(String factoryId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final key = 'factory_id_${timestamp ~/ 1000}'; // Key with timestamp

    await _storage.write(key: key, value: factoryId);
    await _storage.write(key: 'current_factory_key', value: key);

    _cachedFactoryId = factoryId;

    debugPrint('💾 Saved factoryId with rotated key: $key');
  }

  /// جلب factory_id مع المفتاح الدوار
  static Future<String?> getFactoryIdWithRotation() async {
    try {
      final currentKey = await _storage.read(key: 'current_factory_key');
      if (currentKey != null) {
        final factoryId = await _storage.read(key: currentKey);
        _cachedFactoryId = factoryId;
        return factoryId;
      }
    } catch (e) {
      debugPrint('⚠️ Error reading rotated factoryId: $e');
    }

    // Fallback to original method
    return await getFactoryId();
  }

  /// رفع أو تحديث بيانات في جدول معين مع ضمان وجود factory_id
  static Future<bool> pushData(String table, Map<String, dynamic> data) async {
    try {
      final factoryId = await getFactoryId();
      if (factoryId == null) {
        debugPrint('❌ Error: factory_id is missing!');
        return false;
      }

      final payload = Map<String, dynamic>.from(data);
      payload['factory_id'] = factoryId;

      await _supabase.from(table).upsert(payload);
      debugPrint('✅ Data pushed successfully to $table');
      return true;
    } catch (e) {
      debugPrint('❌ Error pushing data to $table: $e');
      return false;
    }
  }

  /// جلب بيانات من جدول معين بناءً على factory_id
  static Future<List<Map<String, dynamic>>?> fetchData(String table) async {
    try {
      final factoryId = await getFactoryId();
      if (factoryId == null) {
        debugPrint('❌ Error: factory_id is missing!');
        return null;
      }

      final data =
          await _supabase.from(table).select().eq('factory_id', factoryId);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Error fetching data from $table: $e');
      return null;
    }
  }

  /// الاستماع المباشر (Real-time) للتغييرات في جدول بناءً على factory_id
  static Future<Stream<List<Map<String, dynamic>>>?> streamData(String table,
      {required List<String> primaryKey}) async {
    final factoryId = await getFactoryId();
    if (factoryId == null) {
      debugPrint('❌ Error: factory_id is missing for stream!');
      return null;
    }

    try {
      return _supabase
          .from(table)
          .stream(primaryKey: primaryKey)
          .eq('factory_id', factoryId)
          .handleError((error) {
        debugPrint('❌ Stream Error on $table: $error');
      });
    } catch (e) {
      debugPrint('❌ Critical Error setting up stream for $table: $e');
      return null;
    }
  }
}
