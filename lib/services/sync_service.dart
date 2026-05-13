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
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/live_session.dart';
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
        debugPrint('✅ SyncService: تم استرجاع ${res.length} workers.');
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

      if (!Hive.isBoxOpen('workers_flexo')) {
        debugPrint('⚠️ [workers] Box workers_flexo مغلق!');
        return;
      }
      final box = Hive.box<Worker>('workers_flexo');
      final workerName = record['name']?.toString() ?? '';

      if (isDelete) {
        // استخدام sync_id أو id للحذف المباشر (أكثر موثوقية من الاسم)
        final syncId = record['sync_id']?.toString() ?? record['id']?.toString();
        if (syncId != null && syncId.isNotEmpty) {
          await _deleteWorkerBySyncId(box, syncId);
          debugPrint('🗑️ [workers] حُذف محلياً بـ sync_id: $syncId ($workerName)');
        } else {
          // fallback: الحذف بالاسم إذا لم يكن sync_id موجوداً
          await _deleteWorkerFromBox(box, workerName, myFactoryId);
          debugPrint('🗑️ [workers] حُذف محلياً بالاسم (fallback): $workerName');
        }
      } else {
        debugPrint('🌟 وصلت بيانات جديدة [workers]: $workerName');

        try {
          final actionsList = record['actions'] as List? ?? [];
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

          // FIX: استخدام مفتاح ثابت = sync_id من Supabase أو name+factoryId كـ fallback
          // هذا يمنع تكرار العامل مع كل تحديث Real-time
          final stableKey = record['sync_id']?.toString() ??
              record['id']?.toString() ??
              '${workerName}_$myFactoryId';

          // FIX: البحث عن السجل لمنع التكرار (Double Entry)
          dynamic existingKey = stableKey;
          for (var i = 0; i < box.length; i++) {
            final item = box.getAt(i);
            if (item != null && item.syncId == stableKey) {
              existingKey = box.keyAt(i);
              break;
            }
          }

          await box.put(existingKey, worker);
          debugPrint('✅ [workers] تم حفظ/تحديث محلياً بمفتاح ثابت: $workerName ($stableKey)');
        } catch (workerError) {
          debugPrint('❌ [workers] فشل تحويل payload إلى Worker: $workerError');
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
