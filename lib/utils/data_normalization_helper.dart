import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_sheet/models/flexo_production_report.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/die_cutting_form.dart';
import 'package:smart_sheet/models/maintenance_record_model.dart';

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
        
        for (var key in box.keys.toList()) {
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

  static Future<void> _normalizeArchiveBox(String boxName, Map<String, dynamic> Function(Map<String, dynamic>) normalizer) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box(boxName);
      int updatedCount = 0;
      for (var key in box.keys.toList()) {
        final entry = box.get(key);
        if (entry != null && entry is Map) {
          try {
            final rawMap = Map<String, dynamic>.from(entry);
            final cleanMap = normalizer(rawMap);
            await box.put(key, cleanMap);
            updatedCount++;
          } catch (e) {
            debugPrint('⚠️ DataNormalizationHelper: Failed to normalize entry in $boxName - $e');
          }
        }
      }
      debugPrint('🧹 DataNormalizationHelper: Normalized $updatedCount entries in $boxName.');
    }
  }
}
