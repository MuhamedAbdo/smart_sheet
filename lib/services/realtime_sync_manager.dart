import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/production_report.dart';

/// مدير المزامنة الفورية (Real-time Sync Manager)
/// مسؤول عن الاستماع لتغييرات Supabase وتحديث صناديق Hive محلياً.
class RealtimeSyncManager {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String factoryId;

  final List<RealtimeChannel> _channels = [];

  RealtimeSyncManager({required this.factoryId});

  /// تهيئة جميع القنوات (Channels)
  void initialize() {
    debugPrint('📡 RealtimeSyncManager: إعداد القنوات للمصنع: $factoryId');
    
    _setupChannel('production_reports', _onProductionReportChange);
    _setupChannel('workers', _onWorkerChange);
    _setupChannel('worker_actions', _onWorkerActionChange);
    _setupChannel('machines', _onMachineChange);
    _setupChannel('customers', _onCustomerChange);
  }

  /// إغلاق جميع القنوات
  Future<void> dispose() async {
    for (final channel in _channels) {
      await _supabase.removeChannel(channel);
    }
    _channels.clear();
    debugPrint('🔄 RealtimeSyncManager: تم إغلاق جميع القنوات.');
  }

  void _setupChannel(String table, Function(PostgresChangePayload) callback) {
    final channel = _supabase
        .channel('public:$table:$factoryId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) => callback(payload),
        )
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('✅ RT: مشترك في جدول $table');
      } else if (error != null) {
        debugPrint('❌ RT Error ($table): $error');
      }
    });
    _channels.add(channel);
  }

  // ==============================================================
  // Callbacks
  // ==============================================================

  /// معالجة تغييرات تقارير الإنتاج
  void _onProductionReportChange(PostgresChangePayload payload) async {
    await _handleGenericChange(
      payload: payload,
      boxName: 'inkReports',
      tableName: 'production_reports',
      idMapper: (record) => record['id']?.toString(),
      dataMapper: (record) => Map<String, dynamic>.from(record),
    );
  }

  /// معالجة تغييرات العمال
  void _onWorkerChange(PostgresChangePayload payload) async {
    await _handleGenericChange<Worker>(
      payload: payload,
      boxName: 'workers',
      tableName: 'workers',
      idMapper: (record) => record['id']?.toString() ?? record['sync_id']?.toString(),
      dataMapper: (record) => Worker.fromJson(Map<String, dynamic>.from(record)),
      usePutAtIfPossible: true,
    );
  }

  /// معالجة تغييرات حركات العمال
  void _onWorkerActionChange(PostgresChangePayload payload) async {
    await _handleGenericChange<WorkerAction>(
      payload: payload,
      boxName: 'worker_actions',
      tableName: 'worker_actions',
      idMapper: (record) =>
          record['id']?.toString() ?? record['sync_id']?.toString(),
      dataMapper: (record) =>
          WorkerAction.fromJson(Map<String, dynamic>.from(record)),
      usePutAtIfPossible: true,
      onAfterSave: (action) async {
        final workerId = action.workerId;
        if (workerId == null) return;

        // ربط الحركة بالعامل في صندوق العمال
        if (Hive.isBoxOpen('workers')) {
          final workersBox = Hive.box<Worker>('workers');
          Worker? worker;
          for (var w in workersBox.values) {
            if (w.id == workerId) {
              worker = w;
              break;
            }
          }

          if (worker != null) {
            // إضافة الحركة لـ HiveList إذا لم تكن موجودة
            if (!worker.actions.contains(action)) {
              worker.actions.add(action);
              await worker.save();
              debugPrint(
                  '🔗 RT: تم ربط الحركة ${action.id} بالعامل ${worker.name}');
            }
          }
        }
      },
    );
  }

  /// معالجة تغييرات الماكينات
  void _onMachineChange(PostgresChangePayload payload) async {
    await _handleGenericChange<FlexoMachine>(
      payload: payload,
      boxName: 'flexo_machines',
      tableName: 'machines',
      idMapper: (record) => record['id']?.toString(),
      dataMapper: (record) => FlexoMachine.fromJson(Map<String, dynamic>.from(record)),
      usePutAtIfPossible: true,
    );
  }

  /// معالجة تغييرات العملاء (Saved Sheet Sizes)
  void _onCustomerChange(PostgresChangePayload payload) async {
    await _handleGenericChange(
      payload: payload,
      boxName: 'savedSheetSizes',
      tableName: 'customers',
      idMapper: (record) => record['sync_id']?.toString() ?? record['id']?.toString(),
      dataMapper: (record) => _customerToHive(record),
    );
  }

  // ==============================================================
  // Core Logic (The Golden Rule)
  // ==============================================================

  /// المنطق الموحد لمعالجة التغييرات (Insert, Update, Delete)
  Future<void> _handleGenericChange<T>({
    required PostgresChangePayload payload,
    required String boxName,
    required String tableName,
    required String? Function(Map<String, dynamic>) idMapper,
    required dynamic Function(Map<String, dynamic>) dataMapper,
    bool usePutAtIfPossible = false,
    Future<void> Function(T)? onAfterSave,
  }) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;

      // 1. فلترة المصنع (Security Check)
      final recordFactoryId = record['factory_id']?.toString();
      if (recordFactoryId != null && recordFactoryId != factoryId) {
        return; // ليس لهذا المصنع
      }

      if (!Hive.isBoxOpen(boxName)) {
        debugPrint('⚠️ RT [$tableName]: Box $boxName is closed!');
        return;
      }
      final box = Hive.box<T>(boxName);

      // 2. معالجة الحذف (القاعدة الذهبية)
      if (isDelete) {
        final id = idMapper(payload.oldRecord);
        if (id == null) {
          debugPrint('⚠️ RT [$tableName]: Delete event received but no ID found in oldRecord');
          return;
        }

        debugPrint('🗑️ RT [$tableName]: الحذف من Hive للمعرف: $id');
        await _deleteFromBoxById(box, id);
        return; // انتهى الأمر، لا نحتاج لعمل fetch
      }

      // 3. معالجة الإضافة أو التحديث
      final id = idMapper(record);
      if (id == null) return;

      final data = dataMapper(record);
      if (data == null) return;

      debugPrint('✨ RT [$tableName]: تحديث محلي للمعرف: $id');
      
      if (usePutAtIfPossible) {
        // للـ Type-Safe Boxes التي تستخدم index
        int? existingIndex;
        for (int i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item is Worker && item.id == id) {
            existingIndex = i;
            break;
          } else if (item is FlexoMachine && item.id == id) {
            existingIndex = i;
            break;
          } else if (item is WorkerAction && item.id == id) {
            existingIndex = i;
            break;
          }
        }

        if (existingIndex != null) {
          await box.putAt(existingIndex, data as T);
        } else {
          await box.add(data as T);
        }
      } else {
        // للصناديق التي تستخدم Key-Value مباشرة (مثل Maps)
        await box.put(id, data);
      }

      if (onAfterSave != null) {
        await onAfterSave(data as T);
      }
    } catch (e) {
      debugPrint('❌ RT Generic Error [$tableName]: $e');
    }
  }

  // ==============================================================
  // Helpers
  // ==============================================================

  Future<void> _deleteFromBoxById(Box box, String id) async {
    // محاولة الحذف بالـ Key أولاً (O(1))
    if (box.containsKey(id)) {
      await box.delete(id);
      return;
    }

    // بحث خطي كـ Fallback (O(n))
    final keysToDelete = [];
    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      String? itemId;
      
      if (item is Map) {
        itemId = item['id']?.toString() ?? item['sync_id']?.toString();
      } else if (item is Worker) {
        itemId = item.id;
      } else if (item is FlexoMachine) {
        itemId = item.id;
      } else if (item is ProductionReport) {
        itemId = item.id;
      }

      if (itemId == id) {
        keysToDelete.add(box.keyAt(i));
      }
    }

    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }

  Map<String, dynamic> _customerToHive(Map<String, dynamic> r) {
    return {
      'sync_id': r['sync_id'] ?? r['id'],
      'processType': r['process_type'] ?? 'تفصيل',
      'clientName': r['client_name'] ?? '',
      'productName': r['product_name'] ?? '',
      'productCode': r['product_code'] ?? '',
      'length': r['length']?.toString() ?? '',
      'width': r['width']?.toString() ?? '',
      'height': r['height']?.toString() ?? '',
      'is_sheet': r['is_sheet'] ?? false,
      'date': r['date'] ?? DateTime.now().toIso8601String(),
      'factory_id': r['factory_id'],
      'image_paths': r['image_paths'] ?? [],
      'is_client_record': r['is_client_record'] ?? false,
    };
  }
}
