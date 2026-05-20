// lib/services/sync/production_sync.dart
//
// Mixin: ProductionSync on SyncServiceBase
// المسؤولية: مزامنة جدولَي live_sessions + production_reports
//   • القناتان: _liveSessionsChannel + _productionChannel
//   • الـ Callbacks: _onLiveSessionChange + _onProductionReportChange
//   • المزامنة المبدئية: _initLiveSessions + _initProductionReports
//   • الـ Helpers: _reportToHive
//
// ⚠️ لا تعدّل هذا الملف إلا عند تغيير منطق جلسات الإنتاج أو تقاريرها حصراً.
//
// 🔑 part of sync_service.dart — نفس الـ library → يرى جميع الـ private.
//    mixin on SyncServiceBase → يرى _supabase + _scheduleReconnect + _reconnectAttempts.

part of '../sync_service.dart';

mixin ProductionSync on SyncServiceBase {
  // ─── حقول القنوات ────────────────────────────────────────────────
  RealtimeChannel? _productionChannel;
  RealtimeChannel? _liveSessionsChannel;

  // ==============================================================
  // Initial Sync
  // ==============================================================

  /// المزامنة المبدئية لجدول live_sessions → Hive box: flexo_live_sessions
  Future<void> _initLiveSessions(String factoryId) async {
    try {
      final liveSessionsResponse = await _supabase
          .from('live_sessions')
          .select()
          .eq('factory_id', factoryId);

      final liveSessionsBox = Hive.isBoxOpen('flexo_live_sessions')
          ? Hive.box<LiveSession>('flexo_live_sessions')
          : await Hive.openBox<LiveSession>('flexo_live_sessions');

      final Map<dynamic, LiveSession> sessionsMap = {};
      final now = DateTime.now();

      for (final record in liveSessionsResponse) {
        final session = LiveSession.fromJson(record);
        // ✅ استبعاد الجلسات التي مر عليها أكثر من 24 ساعة (Ghost Sessions)
        final sessionAge = now.difference(session.startTime);
        if (sessionAge.inHours < 24) {
          sessionsMap[session.id] = session;
        } else {
          debugPrint('🧹 ProductionSync: تجاهل جلسة Ghost للماكينة: ${session.machineName}');
        }
      }

      await liveSessionsBox.clear();
      for (var key in sessionsMap.keys) {
        await liveSessionsBox.put(key, sessionsMap[key]!);
      }
      debugPrint(
        '✅ ProductionSync: تم استرجاع ${sessionsMap.length} جلسة نشطة '
        '(من إجمالي ${liveSessionsResponse.length}).',
      );
    } catch (e) {
      debugPrint('❌ ProductionSync._initLiveSessions: $e');
    }
  }

  /// المزامنة المبدئية لجدول production_reports → Hive box: inkReports
  Future<void> _initProductionReports(String factoryId) async {
    try {
      final res = await _supabase
          .from('production_reports')
          .select()
          .eq('factory_id', factoryId);

      final box = Hive.isBoxOpen('inkReports')
          ? Hive.box('inkReports')
          : await Hive.openBox('inkReports');

      final Map<dynamic, dynamic> reportsMap = {};
      for (final r in res) {
        final hiveRecord = _reportToHive(r);
        hiveRecord['sync_id'] = r['sync_id'] ?? r['id'];
        reportsMap[hiveRecord['sync_id']] = hiveRecord;
      }
      for (var key in reportsMap.keys) {
        await box.put(key, reportsMap[key]);
      }
      debugPrint('✅ ProductionSync: تم استرجاع ${res.length} production_reports.');
    } catch (e) {
      debugPrint('❌ ProductionSync._initProductionReports: $e');
    }
  }

  // ==============================================================
  // Channel Setup & Teardown
  // ==============================================================

  /// إعداد قناتَي Real-time الخاصتين بجلسات الإنتاج والتقارير
  void _setupProductionChannels(String factoryId) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'factory_id',
      value: factoryId,
    );

    // ─── production_reports ────────────────────────────────────────
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

    // ─── live_sessions ─────────────────────────────────────────────
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
  }

  /// إغلاق قناتَي الإنتاج وتحريرهما
  Future<void> _tearDownProductionChannels() async {
    if (_productionChannel != null) {
      await _supabase.removeChannel(_productionChannel!);
      _productionChannel = null;
    }
    if (_liveSessionsChannel != null) {
      await _supabase.removeChannel(_liveSessionsChannel!);
      _liveSessionsChannel = null;
    }
  }

  // ==============================================================
  // Real-time Callbacks
  // ==============================================================

  // ─── production_reports → inkReports ────────────────────────────
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
        debugPrint('⏭️ [production_reports] تجاهل: factory مختلف'); return;
      }

      if (!Hive.isBoxOpen('inkReports')) {
        debugPrint('⚠️ [production_reports] Box inkReports مغلق!'); return;
      }
      final box = Hive.box('inkReports');
      final stableKey = record['sync_id']?.toString() ?? record['id']?.toString();

      if (isDelete) {
        final syncId   = record['sync_id']?.toString();
        final remoteId = record['id']?.toString();
        if (syncId == null && remoteId == null) return;

        bool deleted = false;
        if (syncId != null && box.containsKey(syncId)) {
          await box.delete(syncId); deleted = true;
        } else if (remoteId != null && box.containsKey(remoteId)) {
          await box.delete(remoteId); deleted = true;
        } else {
          for (int i = 0; i < box.length; i++) {
            final v = box.getAt(i);
            if (v is! Map) continue;
            final vSyncId = v['sync_id']?.toString();
            final vId     = v['id']?.toString();
            if ((syncId  != null && (vSyncId == syncId  || vId == syncId)) ||
                (remoteId != null && (vSyncId == remoteId || vId == remoteId))) {
              await box.deleteAt(i); deleted = true; break;
            }
          }
        }
        debugPrint('🗑️ [production_reports] '
            '${deleted ? "تم" : "لم يُعثر على سجل لـ"} الحذف '
            '(sync_id=$syncId | id=$remoteId)');
      } else {
        if (stableKey == null) {
          debugPrint('⚠️ [production_reports] لا يوجد sync_id أو id!'); return;
        }
        final clientName = record['client_name'] ?? record['clientName'] ?? '';
        debugPrint('🌟 وصلت بيانات جديدة [production_reports]: $clientName (key: $stableKey)');

        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item is Map && item['sync_id'] == stableKey) {
            existingKey = box.keyAt(i); break;
          }
        }

        final hiveRecord = _reportToHive(record);
        hiveRecord['sync_id'] = stableKey;
        await box.put(existingKey, hiveRecord);
        debugPrint('✅ [production_reports] تم حفظ محلياً: $stableKey');
      }
    } catch (e) {
      debugPrint('❌ _onProductionReportChange: $e');
    }
  }

  // ─── live_sessions → flexo_live_sessions ────────────────────────
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
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final session = box.getAt(i);
          if (session != null && session.id == stableKey) {
            existingKey = box.keyAt(i); break;
          }
        }
        await box.delete(existingKey);
        debugPrint('🗑️ [live_sessions] حُذف محلياً: $stableKey');
      } else {
        final session = LiveSession.fromJson(record);
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) {
            existingKey = box.keyAt(i); break;
          }
        }
        await box.put(existingKey, session);
        debugPrint('✅ [live_sessions] تم حفظ/تحديث: $stableKey');
      }
    } catch (e) {
      debugPrint('❌ _onLiveSessionChange: $e');
    }
  }

  // ==============================================================
  // Helpers — خاصة بتقارير الإنتاج
  // ==============================================================

  Map<String, dynamic> _reportToHive(Map<String, dynamic> r) {
    return {
      'sync_id':        r['sync_id'],
      'id':             r['id'] ?? r['sync_id'],
      'date':           r['date'],
      'clientName':     r['clientName']     ?? r['client_name'],
      'product':        r['product']        ?? r['product_name'],
      'productCode':    r['productCode']    ?? r['product_code'],
      'orderNumber':    r['orderNumber']    ?? r['order_number'],
      'startTime':      r['startTime']      ?? r['start_time'],
      'endTime':        r['endTime']        ?? r['end_time'],
      'downtimeStart':  r['downtimeStart']  ?? r['downtime_start'],
      'downtimeEnd':    r['downtimeEnd']    ?? r['downtime_end'],
      'totalDowntime':  r['totalDowntime']  ?? r['total_downtime'],
      'machineName':    r['machineName']    ?? r['machine_name'],
      'technicianName': r['technicianName'] ?? r['technician_name'],
      'quantity':       r['quantity'],
      'lineWaste':      r['lineWaste']      ?? r['line_waste'],
      'printWaste':     r['printWaste']     ?? r['print_waste'],
      'notes':          r['notes'],
      'isSheet':        r['isSheet']        ?? r['is_sheet'] ?? false,
      'factory_id':     r['factory_id'],
      'colors':         r['colors']         ?? [],
      'dimensions':     r['dimensions']     ?? {},
    };
  }
}
