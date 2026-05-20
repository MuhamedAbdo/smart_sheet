// lib/services/sync/workers_sync.dart
//
// Mixin: WorkersSync on SyncServiceBase
// المسؤولية: مزامنة جدولَي workers + worker_actions (Attendance Logs)
//   • القنوات: _workersChannel + _attendanceLogsChannel
//   • الـ Callbacks: _onWorkerChange + _onAttendanceLogChange
//   • المزامنة المبدئية: _initWorkers + _initWorkerActions
//   • الـ Helpers: _deleteWorkerBySyncId + _deleteWorkerFromBox
//
// ⚠️ لا تعدّل هذا الملف إلا عند تغيير منطق العمال أو حضورهم حصراً.
//
// 🔑 part of sync_service.dart — نفس الـ library → يرى جميع الـ private.
//    mixin on SyncServiceBase → يرى _supabase + _scheduleReconnect + _reconnectAttempts.

part of '../sync_service.dart';

mixin WorkersSync on SyncServiceBase {
  // ─── حقول القنوات ────────────────────────────────────────────────
  RealtimeChannel? _workersChannel;
  RealtimeChannel? _attendanceLogsChannel;

  // ==============================================================
  // Initial Sync
  // ==============================================================

  /// المزامنة المبدئية لـ workers → Hive boxes
  Future<void> _initWorkers(String factoryId) async {
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
          debugPrint('⚠️ WorkersSync.init: خطأ عند نسخ العمال لـ $boxName: $e');
        }
      }
      debugPrint('✅ WorkersSync: تم استرجاع ${res.length} workers ونشرهم في جميع boxes الأقسام.');
    } catch (e) {
      debugPrint('❌ WorkersSync.initialize(workers): $e');
    }
  }

  /// المزامنة المبدئية لـ worker_actions (= attendance_logs)
  Future<void> _initWorkerActions(String factoryId) async {
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
            debugPrint('⚠️ WorkersSync.init: خطأ عند ربط إجراءات العامل ${w.name}: $e');
          }
        }
      }
      debugPrint('✅ WorkersSync: تم استرجاع ${res.length} worker_actions وربطها بالعمال.');
    } catch (e) {
      debugPrint('❌ WorkersSync.initialize(worker_actions): $e');
    }
  }

  // ==============================================================
  // Channel Setup & Teardown
  // ==============================================================

  /// إعداد قنوات العمال والحركات
  void _setupWorkersChannels(String factoryId) {
    _setupWorkersChannel(factoryId);
    _setupAttendanceLogsChannel(factoryId);
  }

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

  /// إغلاق قنوات العمال والحركات
  Future<void> _tearDownWorkersChannels() async {
    if (_workersChannel != null) {
      await _supabase.removeChannel(_workersChannel!);
      _workersChannel = null;
    }
    if (_attendanceLogsChannel != null) {
      await _supabase.removeChannel(_attendanceLogsChannel!);
      _attendanceLogsChannel = null;
    }
  }

  // ==============================================================
  // Real-time Callbacks
  // ==============================================================

  // ─── workers ──────────────────────────────────────────────────
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

  // ─── worker_actions (Attendance Logs) ─────────────────────────
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

        // البحث عن المفتاح الحقيقي داخل الـ Box عن طريق الـ ID المستقر
        for (var i = 0; i < box.length; i++) {
          final action = box.getAt(i);
          if (action != null && (action.syncId == stableKey || action.id == stableKey)) {
            existingKey = box.keyAt(i);
            break;
          }
        }

        // إزالة الإجراء المفرغ من قائمة الحركات (actions) الخاصة بالعامل في جميع الـ boxes الخاصة بالأقسام
        // نقوم بذلك أولاً قبل حذف السجل من بوكس الإجراءات لمنع تحول المراجع إلى null في الـ HiveList وتسبب أخطاء
        final workerName = record['worker_name']?.toString() ?? '';
        final allWorkerBoxNames = ['workers_flexo', 'workers_production', 'workers_staple', 'workers'];
        for (final boxName in allWorkerBoxNames) {
          if (!Hive.isBoxOpen(boxName)) continue;
          final workerBox = Hive.box<Worker>(boxName);
          for (var i = 0; i < workerBox.length; i++) {
            final w = workerBox.getAt(i);
            if (w == null) continue;
            if (workerName.isNotEmpty && w.name != workerName) continue;
            try {
              final initialLength = w.actions.length;
              // إزالة الإجراء المطابق وأي مراجع تالفة (null) بشكل آمن تماماً وبدون تحذيرات مترجم Dart
              w.actions.removeWhere((a) {
                final dynamic da = a;
                return da == null || da.id == stableKey || da.syncId == stableKey;
              });
              
              if (w.actions.length != initialLength) {
                await w.save();
                debugPrint('🧹 [worker_actions] تم إزالة الإجراء ($stableKey) وتحديث العامل "${w.name}" في $boxName');
              }
            } catch (e) {
              debugPrint('⚠️ [worker_actions] خطأ في إزالة الإجراء من $boxName: $e');
            }
          }
        }

        if (existingKey != null) {
          await box.delete(existingKey);
          debugPrint('🗑️ [worker_actions] حُذفت محلياً بنجاح من الـ Box');
        } else {
          // كود الحذف الاحتياطي الحالي
          await box.delete(stableKey);
        }
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

  // ==============================================================
  // Helpers
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
}
