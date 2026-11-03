import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sheet/models/flexo_production_report.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/die_cutting_form.dart';
import 'package:smart_sheet/models/maintenance_record_model.dart';
import 'package:smart_sheet/services/sync_service.dart';

class DataNormalizationHelper {
  /// يقوم بتنظيف وتوحيد البيانات الموجودة في الصناديق المحلية غير النمطية
  /// لضمان خلوها من أي مفاتيح قديمة وتحويلها لـ snake_case
  static Future<void> normalizeUntypedBoxes() async {
    try {
      debugPrint('🧹 DataNormalizationHelper: Starting normalization of local boxes...');
      
      // 1. Normalize sync_queue
      if (Hive.isBoxOpen('sync_queue')) {
        final box = Hive.box('sync_queue');
        int updatedCount = 0;
        int loopIndex = 0;
        
        for (var key in box.keys.toList()) {
          if (loopIndex % 20 == 0) await Future.delayed(Duration.zero);
          loopIndex++;
          final entry = box.get(key);
          if (entry != null && entry is Map) {
            final String? table = entry['table']?.toString();
            final payload = entry['payload'];
            
            if (table != null && payload is Map) {
              final Map<String, dynamic> rawPayload = Map<String, dynamic>.from(payload);
              Map<String, dynamic> cleanPayload = rawPayload;
              
              try {
                switch (table) {
                  case 'flexo_production_reports':
                  case 'line_production_reports':
                    cleanPayload = FlexoProductionReport.fromJson(rawPayload).toJson();
                    break;
                  case 'die_cutting_production_reports':
                    cleanPayload = DieCuttingProductionReport.fromJson(rawPayload).toJson();
                    break;
                  case 'flexo_live_sessions':
                    cleanPayload = LiveSession.fromJson(rawPayload).toJson();
                    break;
                  case 'finished_products':
                    cleanPayload = FinishedProduct.fromJson(rawPayload).toJson();
                    break;
                  case 'workers_flexo':
                  case 'workers_crushing':
                  case 'workers_production_line':
                    cleanPayload = Worker.fromJson(rawPayload).toJson();
                    break;
                  case 'worker_actions':
                    cleanPayload = WorkerAction.fromJson(rawPayload).toJson();
                    break;
                  case 'flexo_machines':
                    cleanPayload = FlexoMachine.fromJson(rawPayload).toJson();
                    break;
                  case 'die_cutting_forms':
                    cleanPayload = DieCuttingForm.fromJson(rawPayload).toJson();
                    break;
                  case 'maintenance_records_main':
                    cleanPayload = MaintenanceRecord.fromJson(rawPayload).toJson();
                    break;
                }
                
                // If it was changed or just to be safe, update the entry
                entry['payload'] = cleanPayload;
                await box.put(key, entry);
                updatedCount++;
              } catch (e) {
                debugPrint('⚠️ DataNormalizationHelper: Failed to normalize payload for $table - $e');
              }
            }
          }
        }
        debugPrint('🧹 DataNormalizationHelper: Normalized $updatedCount entries in sync_queue.');
      }
      
      // 2. Normalize Archive Boxes (if they hold raw Maps)
      await _normalizeArchiveBox('flexoArchive', (map) => FlexoProductionReport.fromJson(map).toJson());
      await _normalizeArchiveBox('crushingArchive', (map) => DieCuttingProductionReport.fromJson(map).toJson());
      await _normalizeArchiveBox('lineArchive', (map) => FlexoProductionReport.fromJson(map).toJson());
      
      debugPrint('✅ DataNormalizationHelper: Normalization completed successfully.');
    } catch (e) {
      debugPrint('❌ DataNormalizationHelper: Error during normalization: $e');
    }
  }

  /// هجرة هجومية (Aggressive Migration) لحالة المنتج للأصناف القديمة لتصبح "مطبوع"
  /// تعمل بالقوة لمرة واحدة عبر تخطي شرط v1 القديم، ثم تعيد تفعيل الشرط على المفتاح الجديد
  static Future<void> migrateProductStateToPrinted({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // حذف المفتاح القديم v1 لضمان عدم حجب الهجرة السابقة المعلقة
      await prefs.remove('migrated_product_state_to_printed_v1');

      // مفتاح جديد للتحكم بعد الهجرة الهجومية
      const migrationKey = 'migrated_product_state_force_v2';
      final bool alreadyRun = prefs.getBool(migrationKey) ?? false;
      if (!force && alreadyRun) {
        return; // تم الترحيل بالقوة مسبقاً
      }

      debugPrint('⚡ [DataMigration] تشغيل الهجرة الهجومية لـ product_state على savedSheetSizes...');

      final box = Hive.isBoxOpen('savedSheetSizes')
          ? Hive.box('savedSheetSizes')
          : await Hive.openBox('savedSheetSizes');

      int updatedCount = 0;
      final int totalCount = box.length;

      for (int i = 0; i < totalCount; i++) {
        final dynamic key = box.keyAt(i);
        final dynamic rawEntry = box.getAt(i);

        if (rawEntry != null && rawEntry is Map) {
          final Map<String, dynamic> item = Map<String, dynamic>.from(rawEntry);

          final String? p1 = item['product_state']?.toString().trim();
          final String? p2 = item['productState']?.toString().trim();

          // أي صنف ليس "مطبوع" صراحة في كلا المفتاحين يتم تحديثه فوراً
          final bool isAlreadyPrinted = (p1 == 'مطبوع' && p2 == 'مطبوع');

          if (!isAlreadyPrinted) {
            // 1. تحديث المفتاحين معاً للاحتياط
            item['product_state'] = 'مطبوع';
            item['productState'] = 'مطبوع';

            // 2. تحديث الحقول المتداخلة إذا وجدت
            if (item['dimensions'] is Map) {
              final d = Map<String, dynamic>.from(item['dimensions'] as Map);
              d['product_state'] = 'مطبوع';
              d['productState'] = 'مطبوع';
              item['dimensions'] = d;
            }
            if (item['sheet_details'] is Map) {
              final sd = Map<String, dynamic>.from(item['sheet_details'] as Map);
              sd['product_state'] = 'مطبوع';
              sd['productState'] = 'مطبوع';
              item['sheet_details'] = sd;
            }

            // 3. حفظ الكائن المعدل في الـ Hive بشكل صحيح باستخدام putAt و put
            await box.putAt(i, item);
            if (key != null) {
              await box.put(key, item);
            }

            // 4. إرسال تحديث المزامنة السحابية للاحتياط
            final syncId = (item['sync_id'] ?? item['id'] ?? key)?.toString();
            if (syncId != null && syncId.isNotEmpty && syncId != 'null') {
              try {
                SyncService.instance.pushToQueue(
                  'customers',
                  {
                    'sync_id': syncId,
                    'product_state': 'مطبوع',
                  },
                  operation: 'update',
                );
              } catch (_) {}
            }

            updatedCount++;
          }
        }
      }

      // كتابة وتفريغ البيانات فوراً على القرص لضمان استقرار Hive
      await box.flush();

      // تفعيل الشرط مجدداً للمستقبل حتى لا تعيد الدالة الكتابة فوق أي تعديل يدوي قادم
      await prefs.setBool(migrationKey, true);
      debugPrint('✅ [DataMigration] تمت الهجرة الهجومية بنجاح: تم تحديث $updatedCount صنف من إجمالي $totalCount في savedSheetSizes.');
    } catch (e, stack) {
      debugPrint('❌ [DataMigration] خطأ أثناء الهجرة الهجومية: $e\n$stack');
    }
  }

  static Future<void> _normalizeArchiveBox(String boxName, Map<String, dynamic> Function(Map<String, dynamic>) normalizer) async {
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box(boxName);
        int updatedCount = 0;
        int loopIndex = 0;
        for (var key in box.keys.toList()) {
          if (loopIndex % 20 == 0) await Future.delayed(Duration.zero);
          loopIndex++;
          final entry = box.get(key);
          if (entry != null && entry is Map) {
            try {
              final rawMap = Map<String, dynamic>.from(entry);
              if (rawMap.containsKey('data') && rawMap['data'] is Map) {
                final innerData = Map<String, dynamic>.from(rawMap['data']);
                rawMap['data'] = normalizer(innerData);
                await box.put(key, rawMap);
              } else {
                final cleanMap = normalizer(rawMap);
                await box.put(key, cleanMap);
              }
              updatedCount++;
            } catch (e) {
              debugPrint('❌ DataNormalizationHelper: Failed to normalize entry in $boxName - $e');
            }
          }
        }
        debugPrint('✅ DataNormalizationHelper: Normalized $updatedCount entries in $boxName.');
      }
    }
}
