// lib/services/sync_service.dart
//
// نظام المزامنة المركزي – Offline-First + Supabase Real-time
//
// الجداول المُزامَنة:
//   customers          ↔ savedSheetSizes   (Box)
//   production_reports ↔ inkReports        (Box)
//   workers            ↔ workers_flexo     (Box<Worker>)
//   machines           ↔ flexo_machines    (Box<FlexoMachine>)
//   worker_actions     ↔ worker_actions    (Box<WorkerAction>)  [= attendance_logs]

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

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _customersChannel;
  RealtimeChannel? _productionChannel;
  RealtimeChannel? _workersChannel;
  RealtimeChannel? _liveSessionsChannel;
  RealtimeChannel? _machinesChannel;
  RealtimeChannel? _attendanceLogsChannel;
  RealtimeChannel? _customerProductsChannel;
  RealtimeChannel? _machineReportsChannel;

  // ─── Auto-Reconnect ───────────────────────────────────────────
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 6;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  String? _currentFactoryId; // لاستخدامه في إعادة الاتصال التلقائي

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

      // 1. تنزيل الجلسات الحية النشطة
      try {
        final liveSessionsResponse = await _supabase.from('live_sessions').select().eq('factory_id', factoryId);
        final liveSessionsBox = Hive.isBoxOpen('flexo_live_sessions') 
            ? Hive.box<LiveSession>('flexo_live_sessions') 
            : await Hive.openBox<LiveSession>('flexo_live_sessions');
            
        final Map<dynamic, LiveSession> sessionsMap = {};
        final now = DateTime.now();
        
        for (final record in liveSessionsResponse) {
          final session = LiveSession.fromJson(record);
          // ✅ تحسين أمان الجلسات: استبعاد الجلسات التي مر عليها أكثر من 24 ساعة
          final sessionAge = now.difference(session.startTime);
          if (sessionAge.inHours < 24) {
            sessionsMap[session.id] = session;
          } else {
            debugPrint('🧹 SyncService: تجاهل جلسة قديمة (Ghost) للماكينة: ${session.machineName}');
          }
        }
        
        // مسح الجلسات القديمة من Hive قبل إضافة الجديدة لضمان نظافة الواجهة
        await liveSessionsBox.clear();
        
        for (var key in sessionsMap.keys) {
          await liveSessionsBox.put(key, sessionsMap[key]!);
        }
        debugPrint('✅ SyncService: تم استرجاع ${sessionsMap.length} جلسة نشطة (من إجمالي ${liveSessionsResponse.length}).');
      } catch (e) {
        debugPrint('❌ SyncService.initialize(live_sessions): $e');
      }

      // 2. المزامنة المبدئية لـ customers
      try {
        final res = await _supabase.from('customers').select().eq('factory_id', factoryId);
        final box = Hive.isBoxOpen('savedSheetSizes') ? Hive.box('savedSheetSizes') : await Hive.openBox('savedSheetSizes');
        
        final Map<dynamic, dynamic> customersMap = {};
        for (final r in res) {
          final hiveRecord = _customerToHive(r);
          hiveRecord['sync_id'] = r['sync_id'] ?? r['id'];
          customersMap[hiveRecord['sync_id']] = hiveRecord;
        }
        for (var key in customersMap.keys) {
          await box.put(key, customersMap[key]);
        }
        debugPrint('✅ SyncService: تم استرجاع ${res.length} customers.');
      } catch (e) { debugPrint('❌ SyncService.initialize(customers): $e'); }

      // 3. المزامنة المبدئية لـ workers
      try {
        final res = await _supabase.from('workers').select().eq('factory_id', factoryId);
        final box = Hive.isBoxOpen('workers_flexo') ? Hive.box<Worker>('workers_flexo') : await Hive.openBox<Worker>('workers_flexo');
        
        final Map<dynamic, Worker> workersMap = {};
        final actionsBox = Hive.isBoxOpen('worker_actions') 
            ? Hive.box<WorkerAction>('worker_actions') 
            : await Hive.openBox<WorkerAction>('worker_actions');

        for (final r in res) {
          // استخراج الحركات ومعالجتها بشكل منفصل لتجنب خطأ HiveList
          final actionsList = r['actions'] as List? ?? [];
          final workerData = Map<String, dynamic>.from(r);
          workerData['actions'] = []; // نترك الحركات فارغة مؤقتاً عند الإنشاء عبر FromJson
          
          final worker = Worker.fromJson(workerData);
          
          // إضافة الحركات للصندوق ثم للـ HiveList الخاص بالعامل
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

        // نشر نفس البيانات في جميع boxes الأقسام لإطلاق ValueListenableBuilder في كل شاشة
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

      // 4. المزامنة المبدئية لـ production_reports
      try {
        final res = await _supabase.from('production_reports').select().eq('factory_id', factoryId);
        final box = Hive.isBoxOpen('inkReports') ? Hive.box('inkReports') : await Hive.openBox('inkReports');
        
        final Map<dynamic, dynamic> reportsMap = {};
        for (final r in res) {
          final hiveRecord = _reportToHive(r);
          hiveRecord['sync_id'] = r['sync_id'] ?? r['id'];
          reportsMap[hiveRecord['sync_id']] = hiveRecord;
        }
        for (var key in reportsMap.keys) {
          await box.put(key, reportsMap[key]);
        }
        debugPrint('✅ SyncService: تم استرجاع ${res.length} production_reports.');
      } catch (e) { debugPrint('❌ SyncService.initialize(production_reports): $e'); }

      // 5. المزامنة المبدئية لـ machines
      try {
        final res = await _supabase.from('machines').select().eq('factory_id', factoryId);
        final box = Hive.isBoxOpen('flexo_machines')
            ? Hive.box<FlexoMachine>('flexo_machines')
            : await Hive.openBox<FlexoMachine>('flexo_machines');

        for (final r in res) {
          final stableKey = r['sync_id']?.toString() ?? r['id']?.toString();
          if (stableKey == null) continue;
          // منع التكرار: نتحقق أولاً
          dynamic existingKey = stableKey;
          for (var i = 0; i < box.length; i++) {
            final m = box.getAt(i);
            if (m != null && m.id == stableKey) {
              existingKey = box.keyAt(i);
              break;
            }
          }
          final machine = FlexoMachine(
            id: stableKey,
            name: r['name']?.toString() ?? '',
          );
          await box.put(existingKey, machine);
        }
        debugPrint('✅ SyncService: تم استرجاع ${res.length} machines.');
      } catch (e) { debugPrint('❌ SyncService.initialize(machines): $e'); }

      // 6. المزامنة المبدئية لـ worker_actions (= attendance_logs)
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

  /// مزامنة إجبارية (Full Sync Push): إضافة جميع البيانات المحلية إلى طابور المزامنة
  Future<String> forcePushAllLocalDataToServer() async {
    try {
      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) throw Exception('المصنع غير محدد');

      int addedCount = 0;

      // 1. العملاء (customers)
      final customersBox = Hive.isBoxOpen('savedSheetSizes') ? Hive.box('savedSheetSizes') : await Hive.openBox('savedSheetSizes');
      for (var key in customersBox.keys) {
        final data = customersBox.get(key);
        if (data is Map) {
          final Map<String, dynamic> mapData = Map<String, dynamic>.from(data);
          mapData['factory_id'] = factoryId; // لضمان الارتباط
          // إزالة مفتاح sync_status لو موجود لأنه محلي فقط
          mapData.remove('sync_status'); 
          await pushToQueue('customers', mapData, operation: 'upsert');
          addedCount++;
        }
      }

      // 2. العمال (workers)
      final workersBox = Hive.isBoxOpen('workers_flexo') ? Hive.box<Worker>('workers_flexo') : await Hive.openBox<Worker>('workers_flexo');
      for (var key in workersBox.keys) {
        final worker = workersBox.get(key);
        if (worker != null) {
          final mapData = worker.toJson();
          mapData['factory_id'] = factoryId;
          await pushToQueue('workers', mapData, operation: 'upsert');
          addedCount++;
        }
      }

      // 3. التقارير (production_reports)
      final reportsBox = Hive.isBoxOpen('inkReports') ? Hive.box('inkReports') : await Hive.openBox('inkReports');
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
  // Real-time Channel Setup
  // ==============================================================

  void _setupChannels(String factoryId) {
    if (_isDisposed) return;
    _currentFactoryId = factoryId;
    debugPrint('📡 SyncService: إعداد الـ channels لـ factory: $factoryId (محاولة #$_reconnectAttempts)');

    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'factory_id',
      value: factoryId,
    );

    // ─── 1. customers ────────────────────────────────────────────
    _customersChannel = _supabase
        .channel('rt_customers_${factoryId}_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'customers',
          filter: filter,
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
            _reconnectAttempts = 0; // إعادة العداد عند النجاح
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → customers — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → customers: $error');
            _scheduleReconnect();
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
          filter: filter,
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
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → production_reports — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → production_reports: $error');
            _scheduleReconnect();
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
          filter: filter,
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

    // ─── 4. live_sessions ──────────────────────────────────────────
    _liveSessionsChannel = _supabase
        .channel('rt_live_sessions_${factoryId}_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_sessions',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [live_sessions] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onLiveSessionChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → live_sessions (factory: $factoryId)');
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → live_sessions — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → live_sessions: $error');
            _scheduleReconnect();
          } else {
            debugPrint('📡 live_sessions: $status ${error ?? ""}');
          }
        });

    // ─── 5. machines ──────────────────────────────────────────────
    _machinesChannel = _supabase
        .channel('rt_machines_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'machines',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [machines] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
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

    // ─── 6. worker_actions (= attendance_logs) ────────────────────
    _attendanceLogsChannel = _supabase
        .channel('rt_worker_actions_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'worker_actions',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [worker_actions] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
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
          } else {
            debugPrint('📡 customer_products: $status ${error ?? ""}');
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
          } else {
            debugPrint('📡 machine_reports: $status ${error ?? ""}');
          }
        });
  }

  Future<void> _tearDownChannels() async {
    // إلغاء أي جدولة معلقة قبل إغلاق الـ channels
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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
      if (_liveSessionsChannel != null) {
        await _supabase.removeChannel(_liveSessionsChannel!);
        _liveSessionsChannel = null;
      }
      if (_machinesChannel != null) {
        await _supabase.removeChannel(_machinesChannel!);
        _machinesChannel = null;
      }
      if (_attendanceLogsChannel != null) {
        await _supabase.removeChannel(_attendanceLogsChannel!);
        _attendanceLogsChannel = null;
      }
      if (_customerProductsChannel != null) {
        await _supabase.removeChannel(_customerProductsChannel!);
        _customerProductsChannel = null;
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
  // Auto-Reconnect Logic — Exponential Backoff
  // ==============================================================

  /// جدولة إعادة الاتصال بعد انتهاء المهلة أو حدوث خطأ:
  /// #1 → 5ث | #2 → 10ث | #3 → 20ث | #4 → 40ث | #5 → 80ث | #6+ → توقف
  void _scheduleReconnect() {
    if (_isDisposed || _currentFactoryId == null) return;

    // منع جدولة متكررة: إذا كان هناك طلب معلق بالفعل نتجاهل الطلب الجديد
    if (_reconnectTimer?.isActive == true) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        '⛔ SyncService: تجاوز الحد الأقصى ($_maxReconnectAttempts). '
        'استخدم SyncService.instance.initialize() للإعادة يدوياً.',
      );
      return;
    }

    _reconnectAttempts++;
    // Exponential backoff: clamp لمنع تجاوز 80ث
    final delaySeconds = (5 * (1 << (_reconnectAttempts - 1))).clamp(5, 80);
    final delay = Duration(seconds: delaySeconds);

    debugPrint(
      '⏳ SyncService: إعادة محاولة #$_reconnectAttempts '
      'خلال ${delay.inSeconds}ث...',
    );

    _reconnectTimer = Timer(delay, () async {
      if (_isDisposed || _currentFactoryId == null) return;
      debugPrint('🔄 SyncService: بدء إعادة الاتصال (محاولة #$_reconnectAttempts)...');
      await _tearDownChannels();
      _setupChannels(_currentFactoryId!);
    });
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

      // فلترة factory_id داخل الـ callback — نتجاهل الفحص في حالة DELETE
      // لأن Supabase يُرسل oldRecord بدون factory_id في أحداث الحذف
      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) {
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
        // Supabase يُرسل في DELETE: sync_id قد يكون null ولكن id دائماً موجود
        final syncId  = record['sync_id']?.toString();
        final remoteId = record['id']?.toString();
        debugPrint('🗑️ [customers] وصل طلب حذف: $clientName (sync_id=$syncId, id=$remoteId)');
        final deleted = await _deleteFromBoxByAnyId(box, syncId: syncId, remoteId: remoteId);
        if (!deleted) {
          // آخر محاولة: بالاسم
          await _deleteFromBoxByClientName(box, clientName);
        }
        debugPrint('🗑️ [customers] اكتمل الحذف المحلي: $clientName');
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

        // FIX: البحث عن السجل لمنع التكرار (Double Entry)
        dynamic existingKey = syncId;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item is Map && item['sync_id'] == syncId) {
            existingKey = box.keyAt(i);
            break;
          }
        }

        // FIX: box.put(key) بدلاً من box.add() — يمنع التكرار ويُطلق ValueListenable
        await box.put(existingKey, hiveRecord);
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
      if (!isDelete && recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [production_reports] تجاهل: factory مختلف');
        return;
      }

      if (!Hive.isBoxOpen('inkReports')) {
        debugPrint('⚠️ [production_reports] Box inkReports مغلق!');
        return;
      }
      final box = Hive.box('inkReports');

      // FIX: نستخدم sync_id كمفتاح أساسي بدلاً من id العشوائي
      final stableKey = record['sync_id']?.toString() ?? record['id']?.toString();

      if (isDelete) {
        final syncId   = record['sync_id']?.toString();
        final remoteId = record['id']?.toString();
        if (syncId == null && remoteId == null) return;
        await _deleteFromBoxByAnyId(box, syncId: syncId, remoteId: remoteId);
        debugPrint('🗑️ [production_reports] تم الحذف المحلي (sync_id=$syncId | id=$remoteId)');
      } else {
        if (stableKey == null) {
          debugPrint('⚠️ [production_reports] لا يوجد sync_id أو id!');
          return;
        }

        final clientName = record['client_name'] ?? record['clientName'] ?? '';
        debugPrint('🌟 وصلت بيانات جديدة [production_reports]: $clientName (key: $stableKey)');

        // FIX: البحث عن السجل لمنع التكرار (Double Entry)
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item is Map && item['sync_id'] == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }

        // FIX: تحويل البيانات من snake_case إلى camelCase لتتوافق مع الواجهة
        final hiveRecord = _reportToHive(record);
        hiveRecord['sync_id'] = stableKey; 

        // FIX: box.put(existingKey) — Upsert حقيقي يمنع التكرار
        await box.put(existingKey, hiveRecord);
        debugPrint('✅ [production_reports] تم حفظ محلياً: $stableKey');
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

      // فلترة factory_id — نتجاهل الفحص في حالة DELETE
      // لأن Supabase يُرسل oldRecord بدون factory_id في أحداث الحذف
      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [workers] تجاهل: factory مختلف');
        return;
      }

      // ─── جميع boxes العمال التي يجب تحديثها فوراً لإطلاق ValueListenableBuilder ───
      // الأسباب: كل قسم (فلكسو، دبوس، خط إنتاج) يستخدم box مختلف
      // لكن SyncService يستقبل التحديثات مرة واحدة → يجب إشعار جميع الـ boxes
      final allWorkerBoxNames = ['workers_flexo', 'workers_production', 'workers_staple', 'workers'];
      final List<Box<Worker>> allWorkerBoxes = allWorkerBoxNames
          .where((name) => Hive.isBoxOpen(name))
          .map((name) => Hive.box<Worker>(name))
          .toList();

      if (allWorkerBoxes.isEmpty) {
        debugPrint('⚠️ [workers] لا توجد boxes عمال مفتوحة!');
        return;
      }
      final workerName = record['name']?.toString() ?? '';

      if (isDelete) {
        final syncId = record['sync_id']?.toString() ?? record['id']?.toString();
        if (syncId != null && syncId.isNotEmpty) {
          for (final workerBox in allWorkerBoxes) {
            await _deleteWorkerBySyncId(workerBox, syncId);
          }
          debugPrint('🗑️ [workers] حُذف محلياً من ${allWorkerBoxes.length} boxes (sync_id=$syncId) ($workerName)');
        } else {
          for (final workerBox in allWorkerBoxes) {
            await _deleteWorkerFromBox(workerBox, workerName, myFactoryId);
          }
          debugPrint('🗑️ [workers] حُذف محلياً من ${allWorkerBoxes.length} boxes بالاسم: $workerName');
        }
      } else {
        debugPrint('🌟 وصلت بيانات جديدة [workers]: $workerName → سيتم حفظها في ${allWorkerBoxes.length} boxes');

        try {
          final actionsList = record['actions'] as List? ?? [];
          final stableKey = record['sync_id']?.toString() ??
              record['id']?.toString() ??
              '${workerName}_$myFactoryId';

          // الكتابة في جميع boxes لإطلاق ValueListenableBuilder في كل شاشة قسم
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

              // البحث عن مفتاح موجود لمنع التكرار
              dynamic existingKey = stableKey;
              for (var i = 0; i < workerBox.length; i++) {
                final item = workerBox.getAt(i);
                if (item != null && item.syncId == stableKey) {
                  existingKey = workerBox.keyAt(i);
                  break;
                }
              }

              await workerBox.put(existingKey, worker);
            } catch (boxError) {
              debugPrint('❌ [workers] خطأ عند الكتابة في ${workerBox.name}: $boxError');
            }
          }
          debugPrint('✅ [workers] تم حفظ $workerName في ${allWorkerBoxes.length} boxes (key=$stableKey)');
        } catch (workerError) {
          debugPrint('❌ [workers] فشل تحويل payload: $workerError');
        }
      }
    } catch (e) {
      debugPrint('❌ _onWorkerChange: $e');
    }
  }

  // ─── live_sessions → flexo_live_sessions ───────────────────────
  void _onLiveSessionChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;

      if (record.isEmpty) return;

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) return;

      if (!Hive.isBoxOpen('flexo_live_sessions')) {
        await Hive.openBox<LiveSession>('flexo_live_sessions');
      }
      final box = Hive.box<LiveSession>('flexo_live_sessions');
      
      final stableKey = record['sync_id']?.toString() ?? record['id']?.toString();
      if (stableKey == null) return;

      if (isDelete) {
        // حذف من الجلسات الحية
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final session = box.getAt(i);
          if (session != null && session.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }
        await box.delete(existingKey);
        debugPrint('🗑️ [live_sessions] حُذف محلياً: $stableKey');
      } else {
        // إضافة أو تحديث الجلسة
        final session = LiveSession.fromJson(record);
        
        // FIX: البحث عن السجل لمنع التكرار (Double Entry)
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }

        await box.put(existingKey, session);
        debugPrint('✅ [live_sessions] تم حفظ/تحديث محلياً: $stableKey');
      }
    } catch (e) {
      debugPrint('❌ _onLiveSessionChange: $e');
    }
  }

  // ─── machines → flexo_machines ────────────────────────────────
  void _onMachineChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;

      if (record.isEmpty) {
        debugPrint('⚠️ [machines] payload فارغ! تحقق من Replica Identity.');
        return;
      }

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [machines] تجاهل: factory مختلف ($recordFactoryId)');
        return;
      }

      if (!Hive.isBoxOpen('flexo_machines')) {
        await Hive.openBox<FlexoMachine>('flexo_machines');
      }
      final box = Hive.box<FlexoMachine>('flexo_machines');

      // المفتاح الثابت: sync_id أولاً ثم id
      final stableKey = record['sync_id']?.toString() ?? record['id']?.toString();
      if (stableKey == null) {
        debugPrint('⚠️ [machines] لا يوجد sync_id أو id!');
        return;
      }

      if (isDelete) {
        // حذف: بحث عن الماكينة بـ id
        dynamic existingKey;
        for (var i = 0; i < box.length; i++) {
          final m = box.getAt(i);
          if (m != null && m.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }
        if (existingKey != null) {
          await box.delete(existingKey);
          debugPrint('🗑️ [machines] حُذفت محلياً: $stableKey');
        } else if (box.containsKey(stableKey)) {
          await box.delete(stableKey);
          debugPrint('🗑️ [machines] حُذفت بالمفتاح المباشر: $stableKey');
        } else {
          debugPrint('⚠️ [machines] لم يُعثر على الماكينة للحذف: $stableKey');
        }
      } else {
        final machineName = record['name']?.toString() ?? '';
        debugPrint('🌟 [machines] وصلت ماكينة جديدة: $machineName (key=$stableKey, factory=$recordFactoryId)');

        // Upsert: نبحث عن مفتاح موجود أولاً
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final m = box.getAt(i);
          if (m != null && m.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }

        final machine = FlexoMachine(
          id: stableKey,
          name: machineName,
        );
        await box.put(existingKey, machine);
        debugPrint('✅ [machines] تم حفظ/تحديث محلياً: $machineName (key=$existingKey)');
      }
    } catch (e) {
      debugPrint('❌ _onMachineChange: $e');
    }
  }

  // ─── worker_actions → worker_actions (attendance_logs) ────────
  void _onAttendanceLogChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;

      if (record.isEmpty) {
        debugPrint('⚠️ [worker_actions] payload فارغ! تحقق من Replica Identity.');
        return;
      }

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [worker_actions] تجاهل: factory مختلف ($recordFactoryId)');
        return;
      }

      if (!Hive.isBoxOpen('worker_actions')) {
        await Hive.openBox<WorkerAction>('worker_actions');
      }
      final box = Hive.box<WorkerAction>('worker_actions');

      final stableKey = record['id']?.toString();
      if (stableKey == null) {
        debugPrint('⚠️ [worker_actions] لا يوجد id في payload!');
        return;
      }

      if (isDelete) {
        dynamic existingKey;
        for (var i = 0; i < box.length; i++) {
          final a = box.getAt(i);
          if (a != null && a.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }
        if (existingKey != null) {
          await box.delete(existingKey);
          debugPrint('🗑️ [worker_actions] حُذف محلياً: $stableKey');
        } else if (box.containsKey(stableKey)) {
          await box.delete(stableKey);
          debugPrint('🗑️ [worker_actions] حُذف بالمفتاح المباشر: $stableKey');
        } else {
          debugPrint('⚠️ [worker_actions] لم يُعثر على السجل للحذف: $stableKey');
        }
      } else {
        final workerName = record['worker_name']?.toString() ?? '';
        final actionType = record['type']?.toString() ?? '';
        final actionDate = DateTime.tryParse(record['date']?.toString() ?? '') ?? DateTime.now();
        debugPrint('🌟 [worker_actions] وصل إجراء جديد: $actionType للعامل $workerName (id=$stableKey)');

        final allWorkerBoxNames = ['workers_flexo', 'workers_production', 'workers_staple', 'workers'];

        // ② Upsert في worker_actions box
        // FIX: نبحث بـ Supabase id أولاً، ثم بالمطابقة الدلالية للإجراءات المحلية
        // (الإجراء المحلي يُحفظ بـ millisecondsSinceEpoch كـ id، بينما Supabase يعطيه id مختلفاً)
        final action = WorkerAction.fromJson(Map<String, dynamic>.from(record));
        dynamic existingKey = stableKey;
        dynamic oldLocalKey; // مفتاح الإجراء المحلي القديم إن وُجد

        // البحث بـ Supabase id أولاً
        for (var i = 0; i < box.length; i++) {
          final a = box.getAt(i);
          if (a != null && a.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }

        // إذا لم نجد مطابقاً بالـ id، نبحث دلالياً (نفس العامل + النوع + التاريخ خلال ساعة)
        // هذا يكتشف الإجراءات المحلية التي أُنشئت بـ id مختلف قبل المزامنة
        if (existingKey == stableKey) {
          for (var i = 0; i < box.length; i++) {
            final a = box.getAt(i);
            if (a != null &&
                a.workerName == workerName &&
                a.type == actionType &&
                a.date.difference(actionDate).abs().inHours < 1) {
              oldLocalKey = box.keyAt(i);
              debugPrint('🔍 [worker_actions] وُجد إجراء محلي مطابق دلالياً (key=$oldLocalKey) سيُستبدل بالنسخة المزامَنة');
              break;
            }
          }
        }

        // حفظ الإجراء المزامَن بمفتاح Supabase الثابت
        await box.put(existingKey, action);

        // حذف الإجراء المحلي القديم من الـ box (تجنب التكرار)
        if (oldLocalKey != null && oldLocalKey != existingKey) {
          await box.delete(oldLocalKey);
          debugPrint('🧹 [worker_actions] حُذف الإجراء المحلي القديم (key=$oldLocalKey) بعد استبداله بالمزامَن');
        }

        debugPrint('✅ [worker_actions] تم حفظ/تحديث محلياً: $actionType - $workerName (key=$existingKey)');

        // ③ تحديث HiveList العمال
        for (final boxName in allWorkerBoxNames) {
          if (!Hive.isBoxOpen(boxName)) continue;
          final workerBox = Hive.box<Worker>(boxName);
          for (var i = 0; i < workerBox.length; i++) {
            final w = workerBox.getAt(i);
            if (w == null || w.name != workerName) continue;
            try {
              // تحقق بـ Supabase id أولاً
              final exactMatch = w.actions.any((a) => a.id == stableKey);
              if (exactMatch) {
                debugPrint('⏭️ [worker_actions] الإجراء موجود بالـ id في $boxName');
                continue;
              }

              // FIX: إزالة أي إجراء محلي مطابق دلالياً (بـ id مختلف) قبل إضافة المزامَن
              final localIdx = w.actions.indexWhere((a) =>
                  a.workerName == workerName &&
                  a.type == actionType &&
                  a.date.difference(actionDate).abs().inHours < 1 &&
                  a.id != stableKey);
              if (localIdx != -1) {
                w.actions.removeAt(localIdx);
                debugPrint('🧹 [worker_actions] أُزيل الإجراء المحلي القديم من HiveList في $boxName');
              }

              final savedAction = box.get(existingKey);
              if (savedAction != null) {
                w.actions.add(savedAction);
                await w.save();
                debugPrint('✅ [worker_actions] تم إضافة الإجراء لعامل "$workerName" في box: $boxName');
              }
            } catch (we) {
              debugPrint('⚠️ [worker_actions] خطأ عند تحديث HiveList في $boxName: $we');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ _onAttendanceLogChange: $e');
    }
  }

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
        if (existingKey != null && box.containsKey(existingKey)) {
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
        if (existingKey != null && box.containsKey(existingKey)) {
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

  // ==============================================================
  // Offline Queue Processing
  // ==============================================================

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    if (_queueBox == null || _queueBox!.isEmpty) {
      debugPrint('📱 Mobile Queue: القائمة فارغة، لا يوجد شيء للإرسال.');
      return;
    }

    debugPrint('📱 Mobile Queue: محاولة إرسال بيانات... (${_queueBox!.length} عنصر في الانتظار)');

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

      // التحقق من أن الـ sync_id صالح (ليس فارغاً ولا يحتوي على رموز غريبة)
      final syncId = rawData['sync_id']?.toString() ?? rawData['id']?.toString();
      
      if (syncId == null || syncId.trim().isEmpty) {
        debugPrint('🗑️ تم حذف تقرير تالف من الطابور (sync_id فارغ)');
        keysToDelete.add(key);
        continue;
      }

      // التحقق من وجود رموز غير صالحة لمعرف
      final hasWeirdChars = RegExp(r'[<>{}\[\]\*\&\^%\$#@!]').hasMatch(syncId);
      if (hasWeirdChars) {
        debugPrint('🗑️ تم حذف تقرير تالف من الطابور (رموز غريبة: $syncId)');
        keysToDelete.add(key);
        continue;
      }

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

        if (operation == 'delete') {
          // ⚠️ نستخرج sync_id من الـ payload الأصلي قبل _sanitizePayload
          // لأن الـ sanitizer قد يُولّد UUID جديداً إذا كان sync_id فارغاً
          final syncId = payload['sync_id']?.toString() ?? payload['id']?.toString();
          if (syncId != null && syncId.isNotEmpty) {
            await _supabase.from(table).delete().eq('sync_id', syncId);
            debugPrint('✅ Queue: حذف من $table [sync_id=$syncId]');
          } else {
            debugPrint('⚠️ Queue: تجاهل delete — لا يوجد sync_id في payload $table');
          }
        } else {
          // FIX 22P02: تنظيف الـ payload من القيم الفارغة والأرقام الخاطئة
          final cleanPayload = _sanitizePayload(payload);
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


  /// دالة الحذف الموحدة — تبحث بثلاث طرق بالأولوية:
  /// 1. المفتاح المباشر (sync_id)   → O(1)
  /// 2. حقل sync_id داخل السجل     → O(n)
  /// 3. حقل id (Supabase UUID)       → O(n)
  /// تُعيد true إذا نجح الحذف
  Future<bool> _deleteFromBoxByAnyId(
    Box box, {
    String? syncId,
    String? remoteId,
  }) async {
    // ① مفتاح مباشر بـ sync_id
    if (syncId != null && box.containsKey(syncId)) {
      await box.delete(syncId);
      debugPrint('🗑️ [box] ✅ حُذف بالمفتاح المباشر (sync_id): $syncId');
      return true;
    }
    // ② مفتاح مباشر بـ remoteId
    if (remoteId != null && box.containsKey(remoteId)) {
      await box.delete(remoteId);
      debugPrint('🗑️ [box] ✅ حُذف بالمفتاح المباشر (id): $remoteId');
      return true;
    }
    // ③ بحث خطي: sync_id الداخلي أو id المخزون
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is! Map) continue;
      final vSyncId  = v['sync_id']?.toString();
      final vId      = v['id']?.toString();
      final matched  = (syncId  != null && vSyncId  == syncId) ||
                       (remoteId != null && vSyncId  == remoteId) ||
                       (remoteId != null && vId      == remoteId) ||
                       (syncId  != null && vId      == syncId);
      if (matched) {
        final matchKey = box.keyAt(i);
        await box.delete(matchKey);
        debugPrint('🗑️ [box] ✅ حُذف بالبحث الخطي (sync_id=$vSyncId | id=$vId)');
        return true;
      }
    }
    debugPrint('⚠️ [box] ❌ لم يُعثر على السجل للحذف (sync_id=$syncId | id=$remoteId)');
    return false;
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

  /// حذف عامل بـ sync_id — O(1) إذا كان المفتاح هو sync_id، وإلا بحث خطي
  Future<void> _deleteWorkerBySyncId(Box<Worker> box, String syncId) async {
    // محاولة O(1) أولاً: المفتاح المباشر هو sync_id
    if (box.containsKey(syncId)) {
      await box.delete(syncId);
      debugPrint('🗑️ [workers] حُذف بالمفتاح المباشر: $syncId');
      return;
    }
    // fallback: بحث خطي عبر syncId الداخلي
    for (int i = 0; i < box.length; i++) {
      final w = box.getAt(i);
      if (w != null && w.syncId == syncId) {
        await box.deleteAt(i);
        debugPrint('🗑️ [workers] حُذف بالبحث الخطي (syncId): $syncId');
        return;
      }
    }
    debugPrint('⚠️ [workers] لم يُعثر على العامل للحذف (syncId=$syncId)');
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
      'id':             r['id'],          // Supabase UUID — مطلوب لمطابقة حدث DELETE
      'sync_id':        r['sync_id'],
      'processType':    r['process_type'] ?? 'تفصيل',
      'clientName':     r['client_name'] ?? '',
      'productName':    r['product_name'] ?? '',
      'productCode':    r['product_code'] ?? '',
      'length':         r['length']?.toString() ?? '',
      'width':          r['width']?.toString() ?? '',
      'height':         r['height']?.toString() ?? '',
      'isSheet':        r['is_sheet'] ?? false,
      'date':           r['date'] ?? DateTime.now().toIso8601String(),
      'factory_id':     r['factory_id'],
      'imagePaths':     r['image_paths'] ?? [],
      'isClientRecord': r['is_client_record'] ?? false,
    };
  }

  Map<String, dynamic> _reportToHive(Map<String, dynamic> r) {
    return {
      'sync_id': r['sync_id'],
      'id': r['id'] ?? r['sync_id'],
      'date': r['date'],
      'clientName': r['clientName'] ?? r['client_name'],
      'product': r['product'] ?? r['product_name'],
      'productCode': r['productCode'] ?? r['product_code'],
      'orderNumber': r['orderNumber'] ?? r['order_number'],
      'startTime': r['startTime'] ?? r['start_time'],
      'endTime': r['endTime'] ?? r['end_time'],
      'downtimeStart': r['downtimeStart'] ?? r['downtime_start'],
      'downtimeEnd': r['downtimeEnd'] ?? r['downtime_end'],
      'totalDowntime': r['totalDowntime'] ?? r['total_downtime'],
      'machineName': r['machineName'] ?? r['machine_name'],
      'technicianName': r['technicianName'] ?? r['technician_name'],
      'quantity': r['quantity'],
      'lineWaste': r['lineWaste'] ?? r['line_waste'],
      'printWaste': r['printWaste'] ?? r['print_waste'],
      'notes': r['notes'],
      'isSheet': r['isSheet'] ?? r['is_sheet'] ?? false,
      'factory_id': r['factory_id'],
      'colors': r['colors'] ?? [],
      'dimensions': r['dimensions'] ?? {},
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
