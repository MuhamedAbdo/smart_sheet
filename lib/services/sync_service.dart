// lib/services/sync_service.dart
//
// نظام المزامنة المركزي – Offline-First + Supabase Real-time
//
// الجداول المُزامَنة:
//   customers          ↔ savedSheetSizes        (Box)          → [CustomerSync]
//   customer_products  ↔ finished_products       (Box)          → [CustomerSync]
//   production_reports ↔ inkReports              (Box)          → [ProductionSync]
//   live_sessions      ↔ flexo_live_sessions     (Box)          → [ProductionSync]
//   workers            ↔ workers_flexo           (Box<Worker>)  → هنا
//   machines           ↔ flexo_machines          (Box<FlexoMachine>) → هنا
//   worker_actions     ↔ worker_actions          (Box<WorkerAction>) → هنا
//   machine_reports    ↔ maintenance_records_main (Box)         → هنا
//
// المعمارية:
//   SyncServiceBase (abstract) ← الحقول المشتركة بين الـ Mixins
//   mixin CustomerSync  on SyncServiceBase  ← lib/services/sync/customer_sync.dart
//   mixin ProductionSync on SyncServiceBase ← lib/services/sync/production_sync.dart
//   class SyncService extends SyncServiceBase with CustomerSync, ProductionSync

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/models/maintenance_record_model.dart';
import 'package:smart_sheet/models/day_schedule.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:uuid/uuid.dart';

// 🔑 part files — جزء من نفس الـ library، ترى جميع التعريفات الـ private.
part 'sync/customer_sync.dart';
part 'sync/production_sync.dart';
part 'sync/machines_sync.dart';
part 'sync/workers_sync.dart';
part 'sync/factory_sync.dart';

// ==============================================================
// SyncServiceBase — الحقول المشتركة بين Mixins و SyncService
// ==============================================================
// يُمكِّن الـ Mixins من الوصول لـ _supabase و _scheduleReconnect
// و _reconnectAttempts دون circular dependency.

abstract class SyncServiceBase {
  /// عميل Supabase المشترك بين جميع الـ Mixins
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── Auto-Reconnect State ─────────────────────────────────────
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 6;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  String? _currentFactoryId;

  /// جدولة إعادة الاتصال — يُنفَّذ في SyncService
  void _scheduleReconnect();
}

// ==============================================================
// SyncService — نقطة الدخول المركزية للتطبيق
// ==============================================================

class SyncService extends SyncServiceBase with CustomerSync, ProductionSync, MachinesSync, WorkersSync, FactorySync {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  // ─── قنوات الميزات المتبقية ────────────────────────────────────
  // (Machines / MachineReports)
  // مرشحة للعزل في Mixins مستقبلية تدريجياً
  RealtimeChannel? _machineReportsChannel;

  // ─── ThemeProvider Reference ──────────────────────────────────
  // يُسجَّل من main.dart عند بناء SmartSheetApp لتمرير الـ ref
  // للـ FactorySync mixin دون كسر signature الـ initialize().
  ThemeProvider? _themeProvider;

  void setThemeProvider(ThemeProvider tp) {
    final bool isFirstTime = _themeProvider == null;
    _themeProvider = tp;

    if (isFirstTime && _currentFactoryId != null) {
      debugPrint('⚡ SyncService: تم تسجيل ThemeProvider بعد التهيئة. بدء مزامنة المصنع...');
      _initFactorySettings(_currentFactoryId!, tp);
      _setupFactoryChannel(_currentFactoryId!, tp);
    }
  }

  Box? _queueBox;
  bool _isProcessingQueue = false;

  /// يضمن أن _queueBox مفتوح دائماً — يُعيد فتحه إن أُغلق.
  Future<Box> _ensureQueueBox() async {
    if (_queueBox != null && _queueBox!.isOpen) return _queueBox!;
    _queueBox = Hive.isBoxOpen('sync_queue')
        ? Hive.box('sync_queue')
        : await Hive.openBox('sync_queue');
    return _queueBox!;
  }

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

      // 1. تنزيل الجلسات الحية النشطة [ProductionSync]
      await _initLiveSessions(factoryId);

      // 2. المزامنة المبدئية لـ customers [CustomerSync]
      await _initCustomers(factoryId);

      // 3. المزامنة المبدئية لـ workers
      await _initWorkers(factoryId);

      // 4. المزامنة المبدئية لـ production_reports [ProductionSync]
      await _initProductionReports(factoryId);

      // 5. المزامنة المبدئية لـ machines [MachinesSync]
      await _initMachines(factoryId);

      // 6. المزامنة المبدئية لـ worker_actions (= attendance_logs)
      await _initWorkerActions(factoryId);

      // 9. المزامنة المبدئية لأوقات الوردية [FactorySync]
      if (_themeProvider != null) {
        await _initFactorySettings(factoryId, _themeProvider!);
      }

      // 7. المزامنة المبدئية لـ customer_products [CustomerSync]
      await _initCustomerProducts(factoryId);

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
      } catch (e) { debugPrint('❌ SyncService.initialize(machine_reports): $e'); }

      // إعداد قنوات Real-time بعد التحميل المبدئي بنجاح
      _setupChannels(factoryId);
      unawaited(_processQueue());

      debugPrint('✅ SyncService: تم التهيئة للمصنع: $factoryId');
    } catch (e) {
      debugPrint('❌ SyncService.initialize: $e');
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _tearDownChannels();
    debugPrint('🔄 SyncService: تم الإغلاق.');
  }

  Future<void> clearSyncQueue() async {
    try {
      final box = await _ensureQueueBox();
      final count = box.length;
      await box.clear();
      debugPrint('🧹 SyncService: تم مسح $count عنصر من sync_queue.');
    } catch (e) {
      debugPrint('❌ SyncService.clearSyncQueue: $e');
    }
  }

  Future<String> forcePushAllLocalDataToServer() async {
    try {
      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) throw Exception('المصنع غير محدد');
      int addedCount = 0;

      final customersBox = Hive.isBoxOpen('savedSheetSizes')
          ? Hive.box('savedSheetSizes')
          : await Hive.openBox('savedSheetSizes');
      for (var key in customersBox.keys) {
        final data = customersBox.get(key);
        if (data is Map) {
          final Map<String, dynamic> mapData = Map<String, dynamic>.from(data);
          mapData['factory_id'] = factoryId;
          mapData.remove('sync_status');
          await pushToQueue('customers', mapData, operation: 'upsert');
          addedCount++;
        }
      }

      final workersBox = Hive.isBoxOpen('workers_flexo')
          ? Hive.box<Worker>('workers_flexo')
          : await Hive.openBox<Worker>('workers_flexo');
      for (var key in workersBox.keys) {
        final worker = workersBox.get(key);
        if (worker != null) {
          final mapData = worker.toJson();
          mapData['factory_id'] = factoryId;
          await pushToQueue('workers', mapData, operation: 'upsert');
          addedCount++;
        }
      }

      final reportsBox = Hive.isBoxOpen('inkReports')
          ? Hive.box('inkReports')
          : await Hive.openBox('inkReports');
      for (var key in reportsBox.keys) {
        final data = reportsBox.get(key);
        if (data is Map) {
          final Map<String, dynamic> mapData = Map<String, dynamic>.from(data);
          mapData['factory_id'] = factoryId;
          mapData.remove('sync_status');
          await pushToQueue('production_reports', mapData, operation: 'upsert');
          addedCount++;
        }
      }

      return '✅ تم إضافة $addedCount سجل إلى طابور المزامنة بنجاح. سيتم رفعها للسيرفر تباعاً.';
    } catch (e) {
      debugPrint('❌ forcePushAllLocalDataToServer error: $e');
      return '❌ فشل المزامنة الإجبارية: $e';
    }
  }

  Future<void> pushToQueue(
    String table,
    Map<String, dynamic> data, {
    String operation = 'upsert',
  }) async {
    try {
      final box = await _ensureQueueBox();

      await box.add({
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
  // Real-time Channel Setup (Orchestrator)
  // ==============================================================

  void _setupChannels(String factoryId) {
    if (_isDisposed) return;
    _currentFactoryId = factoryId;
    debugPrint('📡 SyncService: إعداد الـ channels لـ factory: $factoryId (محاولة #$_reconnectAttempts)');

    // ─── [CustomerSync]  customers + customer_products ─────────────
    _setupCustomerChannels(factoryId);

    // ─── [ProductionSync] production_reports + live_sessions ───────
    _setupProductionChannels(factoryId);

    // ─── [WorkersSync] workers + worker_actions ────────────────────
    _setupWorkersChannels(factoryId);

    // ─── [هنا] machines ────────────────────────────────────────────
    _setupMachinesChannel(factoryId);

    // ─── [FactorySync] factories (shift times) ──────────────────────
    if (_themeProvider != null) {
      _setupFactoryChannel(factoryId, _themeProvider!);
    }

    // ─── [هنا] machine_reports ─────────────────────────────────────
    _setupMachineReportsChannel(factoryId);
  }

  Future<void> _tearDownChannels() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await _tearDownCustomerChannels();
      await _tearDownProductionChannels();
      await _tearDownMachinesChannel();
      await _tearDownWorkersChannels();
      await _tearDownFactoryChannel();

      if (_machineReportsChannel != null) {
        await _supabase.removeChannel(_machineReportsChannel!);
        _machineReportsChannel = null;
      }
      debugPrint('🔄 SyncService: تم إغلاق الـ channels.');
    } catch (e) {
      debugPrint('❌ _tearDownChannels: $e');
    }
  }

  // ==============================================================
  // Channel Setup — Workers / Machines / Attendance / MachineReports
  // ==============================================================



  void _setupMachineReportsChannel(String factoryId) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'factory_id',
      value: factoryId,
    );
    _machineReportsChannel = _supabase
        .channel('rt_machine_reports_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'machine_reports',
          filter: filter,
          callback: (payload) {
            debugPrint('📥 [machine_reports] event=${payload.eventType} new=${payload.newRecord} old=${payload.oldRecord}');
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
          } else {
            debugPrint('📡 machine_reports: $status ${error ?? ""}');
          }
        });
  }

  // ==============================================================
  // Auto-Reconnect Logic — Exponential Backoff
  // ==============================================================

  /// جدولة إعادة الاتصال بعد انتهاء المهلة أو حدوث خطأ:
  /// #1 → 5ث | #2 → 10ث | #3 → 20ث | #4 → 40ث | #5 → 80ث | #6+ → توقف
  @override
  void _scheduleReconnect() {
    if (_isDisposed || _currentFactoryId == null) return;
    if (_reconnectTimer?.isActive == true) return;

    if (_reconnectAttempts >= SyncServiceBase._maxReconnectAttempts) {
      debugPrint(
        '⛔ SyncService: تجاوز الحد الأقصى (${SyncServiceBase._maxReconnectAttempts}). '
        'استخدم SyncService.instance.initialize() للإعادة يدوياً.',
      );
      return;
    }

    _reconnectAttempts++;
    final delaySeconds = (5 * (1 << (_reconnectAttempts - 1))).clamp(5, 80);
    final delay = Duration(seconds: delaySeconds);

    debugPrint('⏳ SyncService: إعادة محاولة #$_reconnectAttempts خلال ${delay.inSeconds}ث...');

    _reconnectTimer = Timer(delay, () async {
      if (_isDisposed || _currentFactoryId == null) return;
      debugPrint('🔄 SyncService: بدء إعادة الاتصال (محاولة #$_reconnectAttempts)...');
      await _tearDownChannels();
      _setupChannels(_currentFactoryId!);
    });
  }

  // ==============================================================
  // Real-time Callbacks — Workers / Machines / Attendance / MachineReports
  // ==============================================================



  void _onMachineReportChange(PostgresChangePayload payload, String myFactoryId) async {
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
          if (item != null && item.id == stableKey) { existingKey = box.keyAt(i); break; }
        }
        if (existingKey != null && box.containsKey(existingKey)) {
          await box.delete(existingKey);
        } else if (box.containsKey(stableKey)) {
          await box.delete(stableKey);
        }
        debugPrint('🗑️ [machine_reports] حُذف: $stableKey');
      } else {
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) { existingKey = box.keyAt(i); break; }
        }
        await box.put(existingKey, MaintenanceRecord.fromJson(record));
        debugPrint('✅ [machine_reports] تم حفظ/تحديث: $stableKey');
      }
    } catch (e) { debugPrint('❌ _onMachineReportChange: $e'); }
  }

  // ==============================================================
  // Offline Queue Processing
  // ==============================================================

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;

    // ✅ الحارس الأساسي: إعادة فتح الـ box إن أُغلق بعد restart أو teardown
    late Box queueBox;
    try {
      queueBox = await _ensureQueueBox();
    } catch (e) {
      debugPrint('❌ _processQueue: تعذّر فتح sync_queue: $e');
      return;
    }

    if (queueBox.isEmpty) {
      debugPrint('📱 Mobile Queue: القائمة فارغة.'); return;
    }

    debugPrint('📱 Mobile Queue: محاولة إرسال... (${queueBox.length} عنصر)');
    final hasInternet = await _checkInternet();
    if (!hasInternet) { debugPrint('📴 Queue: لا إنترنت.'); return; }

    _isProcessingQueue = true;
    debugPrint('🔄 Queue: معالجة ${queueBox.length} عنصر...');
    final keysToDelete = <dynamic>[];

    for (int i = 0; i < queueBox.length; i++) {
      // ✅ تحقق عند كل تكرار — قد يُغلق الـ box أثناء المعالجة
      if (!queueBox.isOpen) {
        debugPrint('⚠️ _processQueue: الـ box أُغلق أثناء المعالجة. توقف.');
        break;
      }

      final key = queueBox.keyAt(i);
      final item = queueBox.getAt(i);
      if (item is! Map) continue;

      final table = item['table']?.toString();
      final rawData = item['data'];
      final operation = item['operation']?.toString() ?? 'upsert';
      final retries = (item['retries'] as int?) ?? 0;
      if (table == null || rawData is! Map) continue;

      final syncId = rawData['sync_id']?.toString() ?? rawData['id']?.toString();
      if (syncId == null || syncId.trim().isEmpty) {
        debugPrint('🗑️ تقرير تالف (sync_id فارغ)'); keysToDelete.add(key); continue;
      }
      if (RegExp(r'[<>{}\[\]\*\&\^\%\$#@!]').hasMatch(syncId)) {
        debugPrint('🗑️ تقرير تالف (رموز غريبة: $syncId)'); keysToDelete.add(key); continue;
      }
      if (retries >= 5) {
        debugPrint('⚠️ Queue: تجاوز الحد → $table'); keysToDelete.add(key); continue;
      }

      try {
        final factoryId = await SupabaseManager.getFactoryId();
        if (factoryId == null) break;

        final payload = Map<String, dynamic>.from(rawData);
        payload['factory_id'] = factoryId;

        if (operation == 'delete') {
          final deleteSyncId = payload['sync_id']?.toString() ?? payload['id']?.toString();
          if (deleteSyncId != null && deleteSyncId.isNotEmpty) {
            await _supabase.from(table).delete().eq('sync_id', deleteSyncId);
            debugPrint('✅ Queue: حذف من $table [sync_id=$deleteSyncId]');
          } else {
            debugPrint('⚠️ Queue: تجاهل delete — لا sync_id في $table');
          }
        } else {
          final cleanPayload = _sanitizePayload(payload);
          if (table == 'customers' || table == 'production_reports' || table == 'workers') {
            await _supabase.from(table).upsert(cleanPayload, onConflict: 'sync_id');
          } else {
            await _supabase.from(table).upsert(cleanPayload);
          }
          debugPrint('✅ Queue: رُفع إلى $table');
        }
        keysToDelete.add(key);
      } catch (e) {
        debugPrint('❌ Queue: فشل → $table [$operation]: $e');
        if (queueBox.isOpen) {
          final updated = Map<String, dynamic>.from(item);
          updated['retries'] = retries + 1;
          await queueBox.put(key, updated);
        }
      }
    }

    if (queueBox.isOpen) {
      for (final key in keysToDelete) { await queueBox.delete(key); }
      debugPrint('✅ Queue: اكتملت. متبقي: ${queueBox.length}');
    }
    _isProcessingQueue = false;
  }



  // ==============================================================
  // Payload Sanitizer — يمنع خطأ 22P02
  // ==============================================================

  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> raw) {
    const numericFields = {'length', 'width', 'height', 'sheet_length', 'sheet_width'};
    const uuidFields = {'sync_id', 'id', 'factory_id'};
    final result = <String, dynamic>{};
    raw.forEach((key, value) {
      if (numericFields.contains(key)) {
        if (value == null || value.toString().trim().isEmpty) {
          result[key] = null;
        } else {
          result[key] = double.tryParse(value.toString().trim());
        }
      } else if (uuidFields.contains(key)) {
        final strVal = value?.toString().trim() ?? '';
        if (strVal.isEmpty) {
          result[key] = const Uuid().v4();
          debugPrint('⚠️ [sanitize] $key كان فارغاً، تم توليد UUID: ${result[key]}');
        } else {
          result[key] = strVal;
        }
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  // ==============================================================
  // Helpers — Connectivity
  // ==============================================================

  Future<bool> _checkInternet() async {
    try {
      final socket = await Socket.connect('supabase.com', 443, timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) { return false; }
  }
}
