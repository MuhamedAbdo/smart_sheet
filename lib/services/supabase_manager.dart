import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SupabaseManager {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const _storage = FlutterSecureStorage();

  /// جلب الـ factory_id من التخزين الآمن
  static Future<String?> getFactoryId() async {
    return await _storage.read(key: 'factory_id');
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

      final data = await _supabase
          .from(table)
          .select()
          .eq('factory_id', factoryId);
          
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Error fetching data from $table: $e');
      return null;
    }
  }

  /// الاستماع المباشر (Real-time) للتغييرات في جدول بناءً على factory_id
  static Future<Stream<List<Map<String, dynamic>>>?> streamData(String table, {required List<String> primaryKey}) async {
    final factoryId = await getFactoryId();
    if (factoryId == null) {
      debugPrint('❌ Error: factory_id is missing for stream!');
      return null;
    }

    return _supabase
        .from(table)
        .stream(primaryKey: primaryKey)
        .eq('factory_id', factoryId);
  }
}
