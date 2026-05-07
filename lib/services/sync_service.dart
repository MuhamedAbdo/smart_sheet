// lib/services/sync_service.dart
//
// نظام المزامنة المركزي – Offline-First + Supabase Real-time
//
// الجداول المُزامَنة:
//   customers          ↔ savedSheetSizes  (Box)
//   production_reports ↔ inkReports       (Box)
//   workers            ↔ workers_flexo    (Box<Worker>)

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:uuid/uuid.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _customersChannel;
  RealtimeChannel? _productionChannel;
  RealtimeChannel? _workersChannel;

  Box? _queueBox;
  bool _isProcessingQueue = false;

  // ==============================================================
  // Public API
  // ==============================================================

  Future<void> initialize() async {
    try {
      _queueBox = Hive.isBoxOpen('sync_queue')
          ? Hive.box('sync_queue')
          : await Hive.openBox('sync_queue');

      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) {
        debugPrint('⏳ SyncService: لا يوجد factory_id، ينتظر تسجيل الدخول.');
        return;
      }

      await _tearDownChannels();
      _setupChannels(factoryId);
      unawaited(_processQueue());

      debugPrint('✅ SyncService: تم التهيئة للمصنع: $factoryId');
    } catch (e) {
      debugPrint('❌ SyncService.initialize: $e');
    }
  }

  Future<void> dispose() async {
    await _tearDownChannels();
    debugPrint('🔄 SyncService: تم الإغلاق.');
  }

  /// مسح جميع عناصر الـ sync_queue (للتنظيف بعد الترحيل إلى UUID)
  Future<void> clearSyncQueue() async {
    try {
      _queueBox ??= Hive.isBoxOpen('sync_queue')
          ? Hive.box('sync_queue')
          : await Hive.openBox('sync_queue');
      final count = _queueBox!.length;
      await _queueBox!.clear();
      debugPrint('🧹 SyncService: تم مسح $count عنصر من sync_queue.');
    } catch (e) {
      debugPrint('❌ SyncService.clearSyncQueue: $e');
    }
  }

  Future<void> pushToQueue(
    String table,
    Map<String, dynamic> data, {
    String operation = 'upsert',
  }) async {
    try {
      _queueBox ??= Hive.isBoxOpen('sync_queue')
          ? Hive.box('sync_queue')
          : await Hive.openBox('sync_queue');

      await _queueBox!.add({
        'table': table,
        'data': Map<String, dynamic>.from(data),
        'operation': operation,
        'timestamp': DateTime.now().toIso8601String(),
        'retries': 0,
      });

      debugPrint('📤 Queue → $table [$operation]');
      unawaited(_processQueue());
    } catch (e) {
      debugPrint('❌ SyncService.pushToQueue: $e');
    }
  }

  // ==============================================================
  // Real-time Channel Setup
  // ==============================================================

  void _setupChannels(String factoryId) {
    debugPrint('📡 SyncService: إعداد الـ channels لـ factory: $factoryId');

    // ─── 1. customers ────────────────────────────────────────────
    _customersChannel = _supabase
        .channel('rt_customers_${factoryId}_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'customers',
          callback: (payload) {
            debugPrint(
              '📥 [customers] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onCustomerChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → customers (factory: $factoryId)');
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → customers: $error');
          } else {
            debugPrint('📡 customers: $status ${error ?? ""}');
          }
        });

    // ─── 2. production_reports ───────────────────────────────────
    _productionChannel = _supabase
        .channel('rt_production_reports_${factoryId}_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'production_reports',
          callback: (payload) {
            debugPrint(
              '📥 [production_reports] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onProductionReportChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → production_reports (factory: $factoryId)');
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → production_reports: $error');
          } else {
            debugPrint('📡 production_reports: $status ${error ?? ""}');
          }
        });

    // ─── 3. workers ──────────────────────────────────────────────
    _workersChannel = _supabase
        .channel('rt_workers_${factoryId}_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'workers',
          callback: (payload) {
            debugPrint(
              '📥 [workers] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onWorkerChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → workers (factory: $factoryId)');
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → workers: $error');
          } else {
            debugPrint('📡 workers: $status ${error ?? ""}');
          }
        });
  }

  Future<void> _tearDownChannels() async {
    try {
      if (_customersChannel != null) {
        await _supabase.removeChannel(_customersChannel!);
        _customersChannel = null;
      }
      if (_productionChannel != null) {
        await _supabase.removeChannel(_productionChannel!);
        _productionChannel = null;
      }
      if (_workersChannel != null) {
        await _supabase.removeChannel(_workersChannel!);
        _workersChannel = null;
      }
      debugPrint('🔄 SyncService: تم إغلاق الـ channels.');
    } catch (e) {
      debugPrint('❌ _tearDownChannels: $e');
    }
  }

  // ==============================================================
  // Real-time Callbacks
  // ==============================================================

  // ─── customers → savedSheetSizes ─────────────────────────────
  void _onCustomerChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;

      if (record.isEmpty) {
        debugPrint('⚠️ [customers] payload فارغ! تحقق من Replica Identity في Supabase.');
        return;
      }

      // فلترة factory_id داخل الـ callback (أكثر موثوقية من channel filter)
      final recordFactoryId = record['factory_id']?.toString();
      if (recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [customers] تجاهل: factory مختلف ($recordFactoryId)');
        return;
      }

      if (!Hive.isBoxOpen('savedSheetSizes')) {
        debugPrint('⚠️ [customers] Box savedSheetSizes مغلق!');
        return;
      }
      final box = Hive.box('savedSheetSizes');

      if (isDelete) {
        final clientName = record['client_name']?.toString() ?? '';
        final syncId = record['sync_id']?.toString() ?? record['id']?.toString();
        debugPrint('🗑️ [customers] وصل طلب حذف: $clientName');
        if (syncId != null) {
          await _deleteFromBoxBySyncId(box, syncId);
        } else {
          await _deleteFromBoxByClientName(box, clientName);
        }
        debugPrint('🗑️ [customers] حُذف محلياً: $clientName');
      } else {
        final clientName = record['client_name']?.toString() ?? '';
        // FIX: sync_id اختياري — نولِّد fallback إذا لم يكن عمود sync_id موجوداً
        final rawSyncId = record['sync_id']?.toString() ?? record['id']?.toString();
        final syncId = rawSyncId ??
            '${clientName}_${myFactoryId}_${record['product_code'] ?? ''}';

        // DEBUG: الرسالة المطلوبة
        debugPrint('🌟 وصلت بيانات جديدة: $clientName (factory: $recordFactoryId) key=$syncId');

        final hiveRecord = _customerToHive(record);
        hiveRecord['sync_id'] = syncId; // ضمان وجود sync_id دائماً

        // FIX: box.put(key) بدلاً من box.add() — يمنع التكرار ويُطلق ValueListenable
        await box.put(syncId, hiveRecord);
        debugPrint('✅ [customers] تم حفظ محلياً: $clientName');
      }
    } catch (e) {
      debugPrint('❌ _onCustomerChange: $e');
    }
  }

  // ─── production_reports → inkReports ─────────────────────────
  void _onProductionReportChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;

      if (record.isEmpty) {
        debugPrint('⚠️ [production_reports] payload فارغ! تحقق من Replica Identity.');
        return;
      }

      final recordFactoryId = record['factory_id']?.toString();
      if (recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [production_reports] تجاهل: factory مختلف');
        return;
      }

      if (!Hive.isBoxOpen('inkReports')) {
        debugPrint('⚠️ [production_reports] Box inkReports مغلق!');
        return;
      }
      final box = Hive.box('inkReports');

      if (isDelete) {
        final id = record['id']?.toString();
        if (id == null) return;
        await _deleteFromBoxById(box, id);
        debugPrint('🗑️ [production_reports] حُذف محلياً: $id');
      } else {
        final id = record['id']?.toString();
        if (id == null) {
          debugPrint('⚠️ [production_reports] لا يوجد id!');
          return;
        }

        final clientName = record['client_name'] ?? record['clientName'] ?? '';
        debugPrint('🌟 وصلت بيانات جديدة [production_reports]: $clientName (id: $id)');

        // FIX: box.put(id) كـ key ثابت — يمنع التكرار
        await box.put(id, Map<String, dynamic>.from(record));
        debugPrint('✅ [production_reports] تم حفظ محلياً: $id');
      }
    } catch (e) {
      debugPrint('❌ _onProductionReportChange: $e');
    }
  }

  // ─── workers → workers_flexo ─────────────────────────────────
  void _onWorkerChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;

      if (record.isEmpty) {
        debugPrint('⚠️ [workers] payload فارغ! تحقق من Replica Identity.');
        return;
      }

      final recordFactoryId = record['factory_id']?.toString();
      if (recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [workers] تجاهل: factory مختلف');
        return;
      }

      if (!Hive.isBoxOpen('workers_flexo')) {
        debugPrint('⚠️ [workers] Box workers_flexo مغلق!');
        return;
      }
      final box = Hive.box<Worker>('workers_flexo');
      final workerName = record['name']?.toString() ?? '';

      if (isDelete) {
        await _deleteWorkerFromBox(box, workerName, myFactoryId);
        debugPrint('🗑️ [workers] حُذف محلياً: $workerName');
      } else {
        debugPrint('🌟 وصلت بيانات جديدة [workers]: $workerName');

        try {
          final worker = Worker.fromJson(Map<String, dynamic>.from(record));

          // FIX: استخدام مفتاح ثابت = sync_id من Supabase أو name+factoryId كـ fallback
          // هذا يمنع تكرار العامل مع كل تحديث Real-time
          final stableKey = record['sync_id']?.toString() ??
              record['id']?.toString() ??
              '${workerName}_$myFactoryId';

          await box.put(stableKey, worker);
          debugPrint('✅ [workers] تم حفظ/تحديث محلياً بمفتاح ثابت: $workerName ($stableKey)');
        } catch (workerError) {
          debugPrint('❌ [workers] فشل تحويل payload إلى Worker: $workerError');
        }
      }
    } catch (e) {
      debugPrint('❌ _onWorkerChange: $e');
    }
  }

  // ==============================================================
  // Offline Queue Processing
  // ==============================================================

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    if (_queueBox == null || _queueBox!.isEmpty) return;

    final hasInternet = await _checkInternet();
    if (!hasInternet) {
      debugPrint('📴 Queue: لا إنترنت، تأجيل المعالجة.');
      return;
    }

    _isProcessingQueue = true;
    debugPrint('🔄 Queue: معالجة ${_queueBox!.length} عنصر...');

    final keysToDelete = <dynamic>[];

    for (int i = 0; i < _queueBox!.length; i++) {
      final key = _queueBox!.keyAt(i);
      final item = _queueBox!.getAt(i);
      if (item is! Map) continue;

      final table = item['table']?.toString();
      final rawData = item['data'];
      final operation = item['operation']?.toString() ?? 'upsert';
      final retries = (item['retries'] as int?) ?? 0;

      if (table == null || rawData is! Map) continue;
      if (retries >= 5) {
        debugPrint('⚠️ Queue: تجاوز الحد → $table [$operation]');
        keysToDelete.add(key);
        continue;
      }

      try {
        final factoryId = await SupabaseManager.getFactoryId();
        if (factoryId == null) break;

        final payload = Map<String, dynamic>.from(rawData);
        payload['factory_id'] = factoryId;

        // FIX 22P02: تنظيف الـ payload من القيم الفارغة والأرقام الخاطئة
        final cleanPayload = _sanitizePayload(payload);

        if (operation == 'delete') {
          final id = cleanPayload['id'] ?? cleanPayload['sync_id'];
          if (id != null) {
            await _supabase.from(table).delete().eq('sync_id', id.toString());
            debugPrint('✅ Queue: حذف من $table [sync_id=$id]');
          }
        } else {
          await _supabase.from(table).upsert(cleanPayload);
          debugPrint('✅ Queue: رُفع إلى $table');
        }

        keysToDelete.add(key);
      } catch (e) {
        debugPrint('❌ Queue: فشل → $table [$operation]: $e');
        final updated = Map<String, dynamic>.from(item);
        updated['retries'] = retries + 1;
        await _queueBox!.put(key, updated);
      }
    }

    for (final key in keysToDelete) {
      await _queueBox!.delete(key);
    }

    _isProcessingQueue = false;
    debugPrint('✅ Queue: اكتملت. متبقي: ${_queueBox!.length}');
  }

  // ==============================================================
  // Helpers
  // ==============================================================

  Future<bool> _checkInternet() async {
    try {
      final socket = await Socket.connect(
        'supabase.com', 443,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteFromBoxById(Box box, String id) async {
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map && v['id']?.toString() == id) {
        await box.deleteAt(i);
        return;
      }
    }
  }

  Future<void> _deleteFromBoxBySyncId(Box box, String syncId) async {
    // FIX: sync_id هو مفتاح الـ box مباشرةً → O(1) بدلاً من O(n)
    if (box.containsKey(syncId)) {
      await box.delete(syncId);
      debugPrint('🗑️ [box] حُذف السجل بالمفتاح: $syncId');
    } else {
      // fallback: بحث خطي للسجلات القديمة التي قد تكون حُفظت بـ add()
      for (int i = 0; i < box.length; i++) {
        final v = box.getAt(i);
        if (v is Map && v['sync_id']?.toString() == syncId) {
          await box.deleteAt(i);
          debugPrint('🗑️ [box] حُذف السجل القديم (fallback) بـ sync_id: $syncId');
          return;
        }
      }
      debugPrint('⚠️ [box] لم يُعثر على sync_id للحذف: $syncId');
    }
  }

  Future<void> _deleteFromBoxByClientName(Box box, String clientName) async {
    final keysToDelete = [];
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map &&
          (v['clientName']?.toString().trim() ?? '') == clientName.trim()) {
        keysToDelete.add(box.keyAt(i));
      }
    }
    for (final k in keysToDelete) {
      await box.delete(k);
    }
  }

  Future<void> _deleteWorkerFromBox(
    Box<Worker> box,
    String name,
    String factoryId,
  ) async {
    for (int i = 0; i < box.length; i++) {
      final w = box.getAt(i);
      if (w?.name == name && w?.factoryId == factoryId) {
        await box.deleteAt(i);
        return;
      }
    }
  }

  Map<String, dynamic> _customerToHive(Map<String, dynamic> r) {
    return {
      'sync_id': r['sync_id'],
      'processType': r['process_type'] ?? 'تفصيل',
      'clientName': r['client_name'] ?? '',
      'productName': r['product_name'] ?? '',
      'productCode': r['product_code'] ?? '',
      'length': r['length']?.toString() ?? '',
      'width': r['width']?.toString() ?? '',
      'height': r['height']?.toString() ?? '',
      'isSheet': r['is_sheet'] ?? false,
      'date': r['date'] ?? DateTime.now().toIso8601String(),
      'factory_id': r['factory_id'],
      'imagePaths': r['image_paths'] ?? [],
      'isClientRecord': r['is_client_record'] ?? false,
    };
  }

  // ==============================================================
  // Payload Sanitizer — يمنع خطأ 22P02 (invalid input syntax)
  // ==============================================================

  /// يُنظف الـ payload قبل إرساله لـ Supabase:
  ///  - الحقول الرقمية الفارغة "" → null
  ///  - sync_id الفارغ → UUID جديد
  ///  - إزالة المفاتيح ذات القيمة null للحقول غير المطلوبة
  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> raw) {
    const numericFields = {
      'length', 'width', 'height',
      'sheet_length', 'sheet_width',
    };
    const uuidFields = {'sync_id', 'id', 'factory_id'};

    final result = <String, dynamic>{};

    raw.forEach((key, value) {
      if (numericFields.contains(key)) {
        // نص فارغ أو null → null (Supabase يقبل null لحقول double nullable)
        if (value == null || value.toString().trim().isEmpty) {
          result[key] = null;
        } else {
          // نحاول التحويل لـ double، وإذا فشل نرسل null
          final parsed = double.tryParse(value.toString().trim());
          result[key] = parsed; // قد يكون null إذا فشل الـ parse
        }
      } else if (uuidFields.contains(key)) {
        final strVal = value?.toString().trim() ?? '';
        if (strVal.isEmpty) {
          // sync_id فارغ → نولّد UUID جديداً
          result[key] = const Uuid().v4();
          debugPrint('⚠️ [sanitize] $key كان فارغاً، تم توليد UUID جديد: ${result[key]}');
        } else {
          result[key] = strVal;
        }
      } else {
        result[key] = value;
      }
    });

    return result;
  }
}
