import sys
import re

with open('d:/projects/smart_sheet/lib/services/sync_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
content = content.replace(
    "import 'package:smart_sheet/models/flexo_machine.dart';",
    "import 'package:smart_sheet/models/flexo_machine.dart';\nimport 'package:smart_sheet/models/finished_product_model.dart';\nimport 'package:smart_sheet/models/maintenance_record_model.dart';"
)

# 2. Channel variables
content = content.replace(
    "RealtimeChannel? _attendanceLogsChannel;",
    "RealtimeChannel? _attendanceLogsChannel;\n  RealtimeChannel? _customerProductsChannel;\n  RealtimeChannel? _machineReportsChannel;"
)

# 3. initialize() method
init_str = """      // 6. المزامنة المبدئية لـ worker_actions (= attendance_logs)
      // FIX: نمسح الـ box أولاً ونعيد بناءه من Supabase بمفاتيح ثابتة (Supabase id)
      // هذا يحل مشكلة الإجراءات المحلية ذات الـ id المختلف التي تسبب التكرار
      try {
        final res = await _supabase.from('worker_actions').select().eq('factory_id', factoryId);
        final box = Hive.isBoxOpen('worker_actions')
            ? Hive.box<WorkerAction>('worker_actions')
            : await Hive.openBox<WorkerAction>('worker_actions');

        // مسح الـ box وإعادة بنائه بمفاتيح ثابتة من Supabase لإزالة أي إدخالات محلية بـ id مختلف
        await box.clear();
        for (final r in res) {
          final stableKey = r['id']?.toString();
          if (stableKey == null) continue;
          final action = WorkerAction.fromJson(Map<String, dynamic>.from(r));
          await box.put(stableKey, action);
        }

        // ربط الإجراءات بـ HiveList العمال في جميع boxes
        final allWorkerBoxNames = ['workers_flexo', 'workers_production', 'workers_staple', 'workers'];
        for (final boxName in allWorkerBoxNames) {
          if (!Hive.isBoxOpen(boxName)) continue;
          final workerBox = Hive.box<Worker>(boxName);
          for (var i = 0; i < workerBox.length; i++) {
            final w = workerBox.getAt(i);
            if (w == null) continue;
            try {
              w.actions.clear();
              for (final r in res) {
                if (r['worker_name']?.toString() != w.name) continue;
                final stableKey = r['id']?.toString();
                if (stableKey == null) continue;
                final savedAction = box.get(stableKey);
                if (savedAction != null) w.actions.add(savedAction);
              }
              await w.save();
            } catch (e) {
              debugPrint('⚠️ SyncService.init: خطأ عند ربط إجراءات العامل ${w.name}: $e');
            }
          }
        }
        debugPrint('✅ SyncService: تم استرجاع ${res.length} worker_actions وربطها بالعمال.');
      } catch (e) { debugPrint('❌ SyncService.initialize(worker_actions): $e'); }

      // 7. المزامنة المبدئية لـ customer_products
      try {
        final res = await _supabase.from('customer_products').select().eq('factory_id', factoryId);
        final box = Hive.isBoxOpen('finished_products') 
            ? Hive.box<FinishedProduct>('finished_products') 
            : await Hive.openBox<FinishedProduct>('finished_products');
        
        await box.clear();
        for (final r in res) {
          final product = FinishedProduct.fromJson(r);
          await box.put(product.id, product);
        }
        debugPrint('✅ SyncService: تم استرجاع ${res.length} customer_products.');
      } catch (e) { debugPrint('❌ SyncService.initialize(customer_products): $e'); }

      // 8. المزامنة المبدئية لـ machine_reports
      try {
        final res = await _supabase.from('machine_reports').select().eq('factory_id', factoryId);
        final box = Hive.isBoxOpen('maintenance_records_main') 
            ? Hive.box<MaintenanceRecord>('maintenance_records_main') 
            : await Hive.openBox<MaintenanceRecord>('maintenance_records_main');
        
        await box.clear();
        for (final r in res) {
          final record = MaintenanceRecord.fromJson(r);
          await box.put(record.id, record);
        }
        debugPrint('✅ SyncService: تم استرجاع ${res.length} machine_reports.');
      } catch (e) { debugPrint('❌ SyncService.initialize(machine_reports): $e'); }"""

# find start and end of section 6
idx1 = content.find("      // 6. المزامنة المبدئية لـ worker_actions (= attendance_logs)")
idx2 = content.find("      // إعداد قنوات Real-time بعد التحميل المبدئي بنجاح", idx1)
content = content[:idx1] + init_str + "\n\n" + content[idx2:]

# 4. Filter addition in setup channels
setup_channels_start = content.find("  void _setupChannels(String factoryId) {")
setup_channels_end = content.find("  Future<void> _tearDownChannels() async {")

setup_channels_code = content[setup_channels_start:setup_channels_end]

# Inject filter declaration
filter_decl = """    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'factory_id',
      value: factoryId,
    );

"""
setup_channels_code = setup_channels_code.replace("    // ─── 1. customers", filter_decl + "    // ─── 1. customers")

# Add filter: filter, to all onPostgresChanges
setup_channels_code = re.sub(
    r"(table:\s*'[^']+',)",
    r"\\1\n          filter: filter,",
    setup_channels_code
)

# Append new channels
new_channels = """
    // ─── 7. customer_products ─────────────────────────────────────
    _customerProductsChannel = _supabase
        .channel('rt_customer_products_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'customer_products',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [customer_products] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onCustomerProductChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → customer_products (factory: $factoryId)');
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → customer_products — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → customer_products: $error');
            _scheduleReconnect();
          }
        });

    // ─── 8. machine_reports ───────────────────────────────────────
    _machineReportsChannel = _supabase
        .channel('rt_machine_reports_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'machine_reports',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [machine_reports] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onMachineReportChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → machine_reports (factory: $factoryId)');
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → machine_reports — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → machine_reports: $error');
            _scheduleReconnect();
          }
        });
"""

setup_channels_code = setup_channels_code.rstrip() + new_channels + "\n\n"

content = content[:setup_channels_start] + setup_channels_code + content[setup_channels_end:]


# 5. Tear down channels
teardown_search = """      if (_attendanceLogsChannel != null) {
        await _supabase.removeChannel(_attendanceLogsChannel!);
        _attendanceLogsChannel = null;
      }"""
teardown_replace = teardown_search + """
      if (_customerProductsChannel != null) {
        await _supabase.removeChannel(_customerProductsChannel!);
        _customerProductsChannel = null;
      }
      if (_machineReportsChannel != null) {
        await _supabase.removeChannel(_machineReportsChannel!);
        _machineReportsChannel = null;
      }"""
content = content.replace(teardown_search, teardown_replace)

# 6. Callbacks
callbacks = """
  // ─── customer_products → finished_products ─────────────────────
  void _onCustomerProductChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;

      if (record.isEmpty) return;

      if (!Hive.isBoxOpen('finished_products')) {
        await Hive.openBox<FinishedProduct>('finished_products');
      }
      final box = Hive.box<FinishedProduct>('finished_products');
      
      final stableKey = record['sync_id']?.toString() ?? record['id']?.toString();
      if (stableKey == null) return;

      if (isDelete) {
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }
        if (existingKey != null) {
          await box.delete(existingKey);
        } else if (box.containsKey(stableKey)) {
          await box.delete(stableKey);
        }
        debugPrint('🗑️ [customer_products] حُذف محلياً: $stableKey');
      } else {
        final product = FinishedProduct.fromJson(record);
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }
        await box.put(existingKey, product);
        debugPrint('✅ [customer_products] تم حفظ/تحديث محلياً: $stableKey');
      }
    } catch (e) {
      debugPrint('❌ _onCustomerProductChange: $e');
    }
  }

  // ─── machine_reports → maintenance_records_main ────────────────
  void _onMachineReportChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;

      if (record.isEmpty) return;

      if (!Hive.isBoxOpen('maintenance_records_main')) {
        await Hive.openBox<MaintenanceRecord>('maintenance_records_main');
      }
      final box = Hive.box<MaintenanceRecord>('maintenance_records_main');
      
      final stableKey = record['id']?.toString();
      if (stableKey == null) return;

      if (isDelete) {
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }
        if (existingKey != null) {
          await box.delete(existingKey);
        } else if (box.containsKey(stableKey)) {
          await box.delete(stableKey);
        }
        debugPrint('🗑️ [machine_reports] حُذف محلياً: $stableKey');
      } else {
        final maintenanceRecord = MaintenanceRecord.fromJson(record);
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }
        await box.put(existingKey, maintenanceRecord);
        debugPrint('✅ [machine_reports] تم حفظ/تحديث محلياً: $stableKey');
      }
    } catch (e) {
      debugPrint('❌ _onMachineReportChange: $e');
    }
  }
"""

# inject before // ==============================================================
#                 // Offline Queue Processing
idx = content.find("  // ==============================================================\n  // Offline Queue Processing")
content = content[:idx] + callbacks + "\n" + content[idx:]

with open('d:/projects/smart_sheet/lib/services/sync_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
