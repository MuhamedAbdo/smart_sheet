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

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/models/maintenance_record_model.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:uuid/uuid.dart';

// 🔑 part files — جزء من نفس الـ library، ترى جميع التعريفات الـ private.
part 'sync/customer_sync.dart';
part 'sync/production_sync.dart';

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

class SyncService extends SyncServiceBase with CustomerSync, ProductionSync {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  // ─── قنوات الميزات المتبقية ────────────────────────────────────
  // (Workers / Machines / Attendance / MachineReports)
  // مرشحة للعزل في Mixins مستقبلية تدريجياً
  RealtimeChannel? _workersChannel;
  RealtimeChannel? _machinesChannel;
  RealtimeChannel? _attendanceLogsChannel;
  RealtimeChannel? _machineReportsChannel;

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

      // 1. تنزيل الجلسات الحية النشطة [ProductionSync]
      await _initLiveSessions(factoryId);

      // 2. المزامنة المبدئية لـ customers [CustomerSync]
      await _initCustomers(factoryId);

      // 3. المزامنة المبدئية لـ workers
      try {
        final res = await _supabase.from('workers').select().eq('factory_id', factoryId);
        final box = Hive.isBoxOpen('workers_flexo')
            ? Hive.box<Worker>('workers_flexo')
            : await Hive.openBox<Worker>('workers_flexo');

        final Map<dynamic, Worker> workersMap = {};
        final actionsBox = Hive.isBoxOpen('worker_actions')
            ? Hive.box<WorkerAction>('worker_actions')
            : await Hive.openBox<WorkerAction>('worker_actions');

        for (final r in res) {
          final actionsList = r['actions'] as List? ?? [];
          final workerData = Map<String, dynamic>.from(r);
          workerData['actions'] = [];
          final worker = Worker.fromJson(workerData);
          for (final a in actionsList) {
            final action = WorkerAction.fromJson(Map<String, dynamic>.from(a));
            await actionsBox.add(action);
            worker.actions.add(action);
          }
          workersMap[r['sync_id'] ?? r['id']] = worker;
        }
        for (var key in workersMap.keys) {
          await box.put(key, workersMap[key]!);
        }

        final otherWorkerBoxNames = ['workers_production', 'workers_staple', 'workers'];
        for (final boxName in otherWorkerBoxNames) {
          try {
            final otherBox = Hive.isBoxOpen(boxName)
                ? Hive.box<Worker>(boxName)
                : await Hive.openBox<Worker>(boxName);
            for (var key in workersMap.keys) {
              final r = res.firstWhere(
                (item) => (item['sync_id'] ?? item['id']) == key,
                orElse: () => <String, dynamic>{},
              );
              if (r.isEmpty) continue;
              final dataCopy = Map<String, dynamic>.from(r);
              dataCopy['actions'] = [];
              await otherBox.put(key, Worker.fromJson(dataCopy));
            }
          } catch (e) {
            debugPrint('⚠️ SyncService.init: خطأ عند نسخ العمال لـ $boxName: $e');
          }
        }
        debugPrint('✅ SyncService: تم استرجاع ${res.length} workers ونشرهم في جميع boxes الأقسام.');
      } catch (e) { debugPrint('❌ SyncService.initialize(workers): $e'); }

      // 4. المزامنة المبدئية لـ production_reports [ProductionSync]
      await _initProductionReports(factoryId);

      // 5. المزامنة المبدئية لـ machines
      try {
        final res = await _supabase.from('machines').select().eq('factory_id', factoryId);
        final box = Hive.isBoxOpen('flexo_machines')
            ? Hive.box<FlexoMachine>('flexo_machines')
            : await Hive.openBox<FlexoMachine>('flexo_machines');

        for (final r in res) {
          final stableKey = r['sync_id']?.toString() ?? r['id']?.toString();
          if (stableKey == null) continue;
          dynamic existingKey = stableKey;
          for (var i = 0; i < box.length; i++) {
            final m = box.getAt(i);
            if (m != null && m.id == stableKey) {
              existingKey = box.keyAt(i);
              break;
            }
          }
          await box.put(existingKey, FlexoMachine(id: stableKey, name: r['name']?.toString() ?? ''));
        }
        debugPrint('✅ SyncService: تم استرجاع ${res.length} machines.');
      } catch (e) { debugPrint('❌ SyncService.initialize(machines): $e'); }

      // 6. المزامنة المبدئية لـ worker_actions (= attendance_logs)
      try {
        final res = await _supabase.from('worker_actions').select().eq('factory_id', factoryId);
        final box = Hive.isBoxOpen('worker_actions')
            ? Hive.box<WorkerAction>('worker_actions')
            : await Hive.openBox<WorkerAction>('worker_actions');

        await box.clear();
        for (final r in res) {
          final stableKey = r['id']?.toString();
          if (stableKey == null) continue;
          await box.put(stableKey, WorkerAction.fromJson(Map<String, dynamic>.from(r)));
        }

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

    // ─── [هنا] workers ─────────────────────────────────────────────
    _setupWorkersChannel(factoryId);

    // ─── [هنا] machines ────────────────────────────────────────────
    _setupMachinesChannel(factoryId);

    // ─── [هنا] worker_actions (attendance_logs) ────────────────────
    _setupAttendanceLogsChannel(factoryId);

    // ─── [هنا] machine_reports ─────────────────────────────────────
    _setupMachineReportsChannel(factoryId);
  }

  Future<void> _tearDownChannels() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await _tearDownCustomerChannels();
      await _tearDownProductionChannels();

      if (_workersChannel != null) {
        await _supabase.removeChannel(_workersChannel!);
        _workersChannel = null;
      }
      if (_machinesChannel != null) {
        await _supabase.removeChannel(_machinesChannel!);
        _machinesChannel = null;
      }
      if (_attendanceLogsChannel != null) {
        await _supabase.removeChannel(_attendanceLogsChannel!);
        _attendanceLogsChannel = null;
      }
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

  void _setupWorkersChannel(String factoryId) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'factory_id',
      value: factoryId,
    );
    _workersChannel = _supabase
        .channel('rt_workers_${factoryId}_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'workers',
          filter: filter,
          callback: (payload) {
            debugPrint('📥 [workers] event=${payload.eventType} new=${payload.newRecord} old=${payload.oldRecord}');
            _onWorkerChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → workers (factory: $factoryId)');
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → workers — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → workers: $error');
            _scheduleReconnect();
          } else {
            debugPrint('📡 workers: $status ${error ?? ""}');
          }
        });
  }

  void _setupMachinesChannel(String factoryId) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'factory_id',
      value: factoryId,
    );
    _machinesChannel = _supabase
        .channel('rt_machines_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'machines',
          filter: filter,
          callback: (payload) {
            debugPrint('📥 [machines] event=${payload.eventType} new=${payload.newRecord} old=${payload.oldRecord}');
            _onMachineChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → machines (factory: $factoryId)');
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → machines — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → machines: $error');
            _scheduleReconnect();
          } else {
            debugPrint('📡 machines: $status ${error ?? ""}');
          }
        });
  }

  void _setupAttendanceLogsChannel(String factoryId) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'factory_id',
      value: factoryId,
    );
    _attendanceLogsChannel = _supabase
        .channel('rt_worker_actions_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'worker_actions',
          filter: filter,
          callback: (payload) {
            debugPrint('📥 [worker_actions] event=${payload.eventType} new=${payload.newRecord} old=${payload.oldRecord}');
            _onAttendanceLogChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → worker_actions/attendance_logs (factory: $factoryId)');
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → worker_actions — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → worker_actions: $error');
            _scheduleReconnect();
          } else {
            debugPrint('📡 worker_actions: $status ${error ?? ""}');
          }
        });
  }

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

  void _onWorkerChange(PostgresChangePayload payload, String myFactoryId) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;
      if (record.isEmpty) { debugPrint('⚠️ [workers] payload فارغ!'); return; }

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [workers] تجاهل: factory مختلف'); return;
      }

      final allWorkerBoxNames = ['workers_flexo', 'workers_production', 'workers_staple', 'workers'];
      final List<Box<Worker>> allWorkerBoxes = allWorkerBoxNames
          .where((name) => Hive.isBoxOpen(name))
          .map((name) => Hive.box<Worker>(name))
          .toList();

      if (allWorkerBoxes.isEmpty) { debugPrint('⚠️ [workers] لا توجد boxes عمال مفتوحة!'); return; }
      final workerName = record['name']?.toString() ?? '';

      if (isDelete) {
        final syncId = record['sync_id']?.toString() ?? record['id']?.toString();
        if (syncId != null && syncId.isNotEmpty) {
          for (final b in allWorkerBoxes) { await _deleteWorkerBySyncId(b, syncId); }
          debugPrint('🗑️ [workers] حُذف من ${allWorkerBoxes.length} boxes (sync_id=$syncId)');
        } else {
          for (final b in allWorkerBoxes) { await _deleteWorkerFromBox(b, workerName, myFactoryId); }
          debugPrint('🗑️ [workers] حُذف من ${allWorkerBoxes.length} boxes بالاسم: $workerName');
        }
      } else {
        debugPrint('🌟 [workers] وصلت بيانات جديدة: $workerName → ${allWorkerBoxes.length} boxes');
        try {
          final actionsList = record['actions'] as List? ?? [];
          final stableKey = record['sync_id']?.toString() ?? record['id']?.toString() ?? '${workerName}_$myFactoryId';
          for (final workerBox in allWorkerBoxes) {
            try {
              final workerData = Map<String, dynamic>.from(record);
              workerData['actions'] = [];
              final worker = Worker.fromJson(workerData);
              if (Hive.isBoxOpen('worker_actions')) {
                final actionsBox = Hive.box<WorkerAction>('worker_actions');
                for (final a in actionsList) {
                  final action = WorkerAction.fromJson(Map<String, dynamic>.from(a));
                  await actionsBox.add(action);
                  worker.actions.add(action);
                }
              }
              dynamic existingKey = stableKey;
              for (var i = 0; i < workerBox.length; i++) {
                final item = workerBox.getAt(i);
                if (item != null && item.syncId == stableKey) { existingKey = workerBox.keyAt(i); break; }
              }
              await workerBox.put(existingKey, worker);
            } catch (e) { debugPrint('❌ [workers] خطأ في ${workerBox.name}: $e'); }
          }
          debugPrint('✅ [workers] تم حفظ $workerName في ${allWorkerBoxes.length} boxes');
        } catch (e) { debugPrint('❌ [workers] فشل تحويل payload: $e'); }
      }
    } catch (e) { debugPrint('❌ _onWorkerChange: $e'); }
  }

  void _onMachineChange(PostgresChangePayload payload, String myFactoryId) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;
      if (record.isEmpty) { debugPrint('⚠️ [machines] payload فارغ!'); return; }

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [machines] تجاهل: factory مختلف ($recordFactoryId)'); return;
      }

      if (!Hive.isBoxOpen('flexo_machines')) await Hive.openBox<FlexoMachine>('flexo_machines');
      final box = Hive.box<FlexoMachine>('flexo_machines');
      final stableKey = record['sync_id']?.toString() ?? record['id']?.toString();
      if (stableKey == null) { debugPrint('⚠️ [machines] لا يوجد sync_id أو id!'); return; }

      if (isDelete) {
        dynamic existingKey;
        for (var i = 0; i < box.length; i++) {
          final m = box.getAt(i);
          if (m != null && m.id == stableKey) { existingKey = box.keyAt(i); break; }
        }
        if (existingKey != null) {
          await box.delete(existingKey);
          debugPrint('🗑️ [machines] حُذفت محلياً: $stableKey');
        } else if (box.containsKey(stableKey)) {
          await box.delete(stableKey);
          debugPrint('🗑️ [machines] حُذفت بالمفتاح المباشر: $stableKey');
        } else {
          debugPrint('⚠️ [machines] لم يُعثر على الماكينة: $stableKey');
        }
      } else {
        final machineName = record['name']?.toString() ?? '';
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final m = box.getAt(i);
          if (m != null && m.id == stableKey) { existingKey = box.keyAt(i); break; }
        }
        await box.put(existingKey, FlexoMachine(id: stableKey, name: machineName));
        debugPrint('✅ [machines] تم حفظ/تحديث: $machineName (key=$existingKey)');
      }
    } catch (e) { debugPrint('❌ _onMachineChange: $e'); }
  }

  void _onAttendanceLogChange(PostgresChangePayload payload, String myFactoryId) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;
      if (record.isEmpty) { debugPrint('⚠️ [worker_actions] payload فارغ!'); return; }

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [worker_actions] تجاهل: factory مختلف ($recordFactoryId)'); return;
      }

      if (!Hive.isBoxOpen('worker_actions')) await Hive.openBox<WorkerAction>('worker_actions');
      final box = Hive.box<WorkerAction>('worker_actions');
      final stableKey = record['id']?.toString();
      if (stableKey == null) { debugPrint('⚠️ [worker_actions] لا يوجد id!'); return; }

      if (isDelete) {
        dynamic existingKey;
        for (var i = 0; i < box.length; i++) {
          final a = box.getAt(i);
          if (a != null && a.id == stableKey) { existingKey = box.keyAt(i); break; }
        }
        if (existingKey != null) {
          await box.delete(existingKey);
        } else if (box.containsKey(stableKey)) {
          await box.delete(stableKey);
        } else {
          debugPrint('⚠️ [worker_actions] لم يُعثر على السجل: $stableKey');
        }
        debugPrint('🗑️ [worker_actions] حُذف: $stableKey');
      } else {
        final workerName = record['worker_name']?.toString() ?? '';
        final actionType = record['type']?.toString() ?? '';
        final actionDate = DateTime.tryParse(record['date']?.toString() ?? '') ?? DateTime.now();
        debugPrint('🌟 [worker_actions] وصل إجراء: $actionType للعامل $workerName (id=$stableKey)');

        final allWorkerBoxNames = ['workers_flexo', 'workers_production', 'workers_staple', 'workers'];
        final action = WorkerAction.fromJson(Map<String, dynamic>.from(record));
        dynamic existingKey = stableKey;
        dynamic oldLocalKey;

        for (var i = 0; i < box.length; i++) {
          final a = box.getAt(i);
          if (a != null && a.id == stableKey) { existingKey = box.keyAt(i); break; }
        }
        if (existingKey == stableKey) {
          for (var i = 0; i < box.length; i++) {
            final a = box.getAt(i);
            if (a != null && a.workerName == workerName && a.type == actionType &&
                a.date.difference(actionDate).abs().inHours < 1) {
              oldLocalKey = box.keyAt(i);
              debugPrint('🔍 [worker_actions] وُجد إجراء محلي مطابق دلالياً (key=$oldLocalKey)');
              break;
            }
          }
        }

        await box.put(existingKey, action);
        if (oldLocalKey != null && oldLocalKey != existingKey) {
          await box.delete(oldLocalKey);
          debugPrint('🧹 [worker_actions] حُذف الإجراء المحلي القديم (key=$oldLocalKey)');
        }
        debugPrint('✅ [worker_actions] تم حفظ/تحديث: $actionType - $workerName (key=$existingKey)');

        for (final boxName in allWorkerBoxNames) {
          if (!Hive.isBoxOpen(boxName)) continue;
          final workerBox = Hive.box<Worker>(boxName);
          for (var i = 0; i < workerBox.length; i++) {
            final w = workerBox.getAt(i);
            if (w == null || w.name != workerName) continue;
            try {
              if (w.actions.any((a) => a.id == stableKey)) {
                debugPrint('⏭️ [worker_actions] موجود بالـ id في $boxName'); continue;
              }
              final localIdx = w.actions.indexWhere((a) =>
                  a.workerName == workerName && a.type == actionType &&
                  a.date.difference(actionDate).abs().inHours < 1 && a.id != stableKey);
              if (localIdx != -1) {
                w.actions.removeAt(localIdx);
                debugPrint('🧹 [worker_actions] أُزيل الإجراء المحلي من HiveList في $boxName');
              }
              final savedAction = box.get(existingKey);
              if (savedAction != null) {
                w.actions.add(savedAction);
                await w.save();
                debugPrint('✅ [worker_actions] أُضيف الإجراء لـ "$workerName" في $boxName');
              }
            } catch (e) { debugPrint('⚠️ [worker_actions] خطأ في $boxName: $e'); }
          }
        }
      }
    } catch (e) { debugPrint('❌ _onAttendanceLogChange: $e'); }
  }

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
    if (_queueBox == null || _queueBox!.isEmpty) {
      debugPrint('📱 Mobile Queue: القائمة فارغة.'); return;
    }

    debugPrint('📱 Mobile Queue: محاولة إرسال... (${_queueBox!.length} عنصر)');
    final hasInternet = await _checkInternet();
    if (!hasInternet) { debugPrint('📴 Queue: لا إنترنت.'); return; }

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
        final updated = Map<String, dynamic>.from(item);
        updated['retries'] = retries + 1;
        await _queueBox!.put(key, updated);
      }
    }

    for (final key in keysToDelete) { await _queueBox!.delete(key); }
    _isProcessingQueue = false;
    debugPrint('✅ Queue: اكتملت. متبقي: ${_queueBox!.length}');
  }

  // ==============================================================
  // Helpers — Workers
  // ==============================================================

  Future<void> _deleteWorkerBySyncId(Box<Worker> box, String syncId) async {
    if (box.containsKey(syncId)) {
      await box.delete(syncId);
      debugPrint('🗑️ [workers] حُذف بالمفتاح المباشر: $syncId'); return;
    }
    for (int i = 0; i < box.length; i++) {
      final w = box.getAt(i);
      if (w != null && w.syncId == syncId) {
        await box.deleteAt(i);
        debugPrint('🗑️ [workers] حُذف بالبحث الخطي: $syncId'); return;
      }
    }
    debugPrint('⚠️ [workers] لم يُعثر على العامل (syncId=$syncId)');
  }

  Future<void> _deleteWorkerFromBox(Box<Worker> box, String name, String factoryId) async {
    for (int i = 0; i < box.length; i++) {
      final w = box.getAt(i);
      if (w?.name == name && w?.factoryId == factoryId) { await box.deleteAt(i); return; }
    }
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
