// lib/services/sync/production_sync.dart
//
// Mixin: ProductionSync on SyncServiceBase
// المسؤولية: مزامنة جدولَي live_sessions + flexo_production_reports
//   • القناتان: _liveSessionsChannel + _productionChannel
//   • الـ Callbacks: _onLiveSessionChange + _onFlexoProductionReportChange
//   • المزامنة المبدئية: _initLiveSessions + _initFlexoProductionReports
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
  RealtimeChannel? _lineProductionChannel;
  RealtimeChannel? _liveSessionsChannel;
  RealtimeChannel? _archivedReportsChannel;
  RealtimeChannel? _dieCuttingProductionChannel;

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
        final sessionAge = now.toUtc().difference(session.startTime.toUtc()).abs();
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

  /// المزامنة المبدئية لجدول flexo_production_reports و line_production_reports → Hive box: flexo_production_reports_box
  Future<void> _initProductionReports(String factoryId) async {
    try {
      final resFlexo = await _supabase
          .from('flexo_production_reports')
          .select()
          .or('factory_id.eq.$factoryId,factory_id.is.null');

      final resLine = await _supabase
          .from('line_production_reports')
          .select()
          .or('factory_id.eq.$factoryId,factory_id.is.null');

      final res = [...resFlexo, ...resLine];
      // فرز محلي حسب date ثم end_time تنازلياً
      res.sort((a, b) {
        final dateComparison = (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? '');
        if (dateComparison != 0) return dateComparison;
        return (b['end_time']?.toString() ?? '').compareTo(a['end_time']?.toString() ?? '');
      });

      final box = Hive.isBoxOpen('flexo_production_reports_box')
          ? Hive.box<FlexoProductionReport>('flexo_production_reports_box')
          : await Hive.openBox<FlexoProductionReport>('flexo_production_reports_box');

      if (res.isEmpty) {
        debugPrint(
          '⚠️ [Safe Pull] بيانات التقارير من السيرفر فارغة... لا يوجد ما يتم تحديثه.',
        );
        return;
      }

      final Map<String, FlexoProductionReport> reportsMap = {};
      for (final r in res) {
        final syncId = r['sync_id']?.toString() ?? r['id']?.toString();
        if (syncId == null) continue;

        final existing = box.get(syncId);
        Map<String, dynamic> updatedData = Map<String, dynamic>.from(r);

        if (existing != null) {
          final double existingWeight = existing.weight ?? 0.0;
          final double currentWeight = double.tryParse(r['weight']?.toString() ?? '0') ?? 0.0;
          if (currentWeight == 0 && existingWeight > 0) {
            updatedData['weight'] = existingWeight;
          }

          final List existingLayers = existing.paperLayers ?? [];
          final List currentLayers = r['paper_layers'] as List? ?? [];
          if (currentLayers.isEmpty && existingLayers.isNotEmpty) {
            updatedData['paper_layers'] = existingLayers;
          }
        }

        reportsMap[syncId] = FlexoProductionReport.fromJson(updatedData);
      }
      // تفريغ الصندوق لتجنب بقاء بيانات قديمة بأسماء حقول غير متوافقة (مثل ---)
      await box.clear();
      for (var key in reportsMap.keys) {
        await box.put(key, reportsMap[key]!);
      }
      debugPrint('✅ ProductionSync: تم استرجاع ${res.length} production_reports (flexo + line).');
    } catch (e) {
      debugPrint('❌ ProductionSync._initProductionReports: $e');
    }
  }

  /// المزامنة المبدئية لجدول die_cutting_production_reports → Hive box: die_cutting_production_reports
  Future<void> _initDieCuttingReports(String factoryId) async {
    try {
      final res = await _supabase
          .from('die_cutting_production_reports')
          .select()
          .or('factory_id.eq.$factoryId,factory_id.is.null')
          .order('report_date', ascending: false);

      final box = Hive.isBoxOpen('die_cutting_production_reports')
          ? Hive.box<DieCuttingProductionReport>('die_cutting_production_reports')
          : await Hive.openBox<DieCuttingProductionReport>('die_cutting_production_reports');

      if (res.isEmpty) return;

      final Map<String, DieCuttingProductionReport> reportsMap = {};
      for (final r in res) {
        final syncId = r['sync_id']?.toString() ?? r['id']?.toString();
        if (syncId == null) continue;
        final reportObj = DieCuttingProductionReport.fromJson(r);
        reportsMap[syncId] = reportObj;
      }
      
      // تفريغ الصندوق للتأكد من عدم وجود بيانات قديمة متراكمة
      await box.clear();
      for (var key in reportsMap.keys) {
        await box.put(key, reportsMap[key]!);
      }
      debugPrint('✅ ProductionSync: تم استرجاع ${res.length} die_cutting_production_reports.');
    } catch (e) {
      debugPrint('❌ ProductionSync._initDieCuttingReports: $e');
    }
  }

  /// المزامنة المبدئية لجدول archived_reports → Hive boxes: flexoArchive & lineArchive
  Future<void> _initArchivedReports(String factoryId) async {
    try {
      final res = await _supabase
          .from('archived_reports')
          .select()
          .or('factory_id.eq.$factoryId,factory_id.is.null')
          .order('date', ascending: false);

      final flexoBox = Hive.isBoxOpen('flexoArchive')
          ? Hive.box('flexoArchive')
          : await Hive.openBox('flexoArchive');
      final lineBox = Hive.isBoxOpen('lineArchive')
          ? Hive.box('lineArchive')
          : await Hive.openBox('lineArchive');
      final crushingBox = Hive.isBoxOpen('crushingArchive')
          ? Hive.box('crushingArchive')
          : await Hive.openBox('crushingArchive');

      if (res.isEmpty) {
        debugPrint(
          '⚠️ [Safe Pull] بيانات الأرشيف من السيرفر فارغة... يُمنع مسح الصندوق المحلي.',
        );
        return;
      }

      for (final r in res) {
        final hiveRecord = _reportToHive(r);
        final syncId = r['sync_id'] ?? r['id'];
        if (syncId == null) continue;
        hiveRecord['sync_id'] = syncId;

        // حدّد الـ box الصحيح حسب القسم
        final dept = hiveRecord['department']?.toString() ?? 'flexo';
        final isProdLine = dept == 'production_line' ||
            (hiveRecord['machineName'] ?? hiveRecord['machine_name'])?.toString() == 'خط الإنتاج';
        final isCrushing = dept == 'crushing';

        final targetBox = isProdLine 
            ? lineBox 
            : isCrushing 
                ? crushingBox 
                : flexoBox;

        final existing = targetBox.get(syncId);
        if (existing is Map && existing['data'] is Map) {
          final existingData = existing['data'] as Map;
          final existingW = existingData['weight'] ?? 0;
          final double existingWeightVal = existingW is num
              ? existingW.toDouble()
              : (double.tryParse(existingW.toString()) ?? 0.0);
          final currentW = hiveRecord['weight'] ?? 0;
          final double currentWeightVal = currentW is num
              ? currentW.toDouble()
              : (double.tryParse(currentW.toString()) ?? 0.0);

          if (currentWeightVal == 0 && existingWeightVal > 0) {
            hiveRecord['weight'] = existingWeightVal;
            if (hiveRecord['dimensions'] is Map) {
              (hiveRecord['dimensions'] as Map)['weight'] = existingWeightVal;
            }
          }

          final currentLayers = hiveRecord['paperLayers'] is List
              ? (hiveRecord['paperLayers'] as List)
              : [];
          final existingLayers = existingData['paperLayers'] is List
              ? (existingData['paperLayers'] as List)
              : [];
          if (currentLayers.isEmpty && existingLayers.isNotEmpty) {
            hiveRecord['paperLayers'] = existingLayers;
            if (hiveRecord['dimensions'] is Map) {
              (hiveRecord['dimensions'] as Map)['paperLayers'] = existingLayers;
            }
          }
        }

        // نقل أي سجل موجود في الـ box الخاطئ إلى الصحيح
        if (targetBox != flexoBox && flexoBox.containsKey(syncId)) {
          await flexoBox.delete(syncId);
        }
        if (targetBox != lineBox && lineBox.containsKey(syncId)) {
          await lineBox.delete(syncId);
        }
        if (targetBox != crushingBox && crushingBox.containsKey(syncId)) {
          await crushingBox.delete(syncId);
        }

        final archiveEntry = {
          'type': 'REPORT',
          'data': hiveRecord,
          'archiveDate':
              r['date']?.toString() ?? DateTime.now().toIso8601String(),
        };
        await targetBox.put(syncId, archiveEntry);
      }
      debugPrint(
          '✅ ProductionSync: تم استرجاع ${res.length} archived_reports (مُقسَّمة بين flexoArchive و lineArchive و crushingArchive).');
    } catch (e) {
      debugPrint('❌ ProductionSync._initArchivedReports: $e');
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

    // ─── flexo_production_reports ────────────────────────────────────────
    _productionChannel = _supabase
        .channel('rt_flexo_production_reports_${factoryId}_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'flexo_production_reports',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [flexo_production_reports] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onProductionReportChange(payload, factoryId, 'flexo_production_reports');
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → flexo_production_reports (factory: $factoryId)');
            _reconnectAttempts['production_channels'] = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → flexo_production_reports — جدولة إعادة الاتصال...');
            _scheduleReconnect('production_channels', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → flexo_production_reports: $error');
            _scheduleReconnect('production_channels', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else {
            debugPrint('📡 flexo_production_reports: $status ${error ?? ""}');
          }
        });

    // ─── line_production_reports ─────────────────────────────────────────
    _lineProductionChannel = _supabase
        .channel('rt_line_production_reports_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'line_production_reports',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [line_production_reports] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onProductionReportChange(payload, factoryId, 'line_production_reports');
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → line_production_reports (factory: $factoryId)');
            _reconnectAttempts['line_production_channels'] = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → line_production_reports — جدولة إعادة الاتصال...');
            _scheduleReconnect('line_production_channels', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → line_production_reports: $error');
            _scheduleReconnect('line_production_channels', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else {
            debugPrint('📡 line_production_reports: $status ${error ?? ""}');
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
            _reconnectAttempts['production_channels'] = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → live_sessions — جدولة إعادة الاتصال...');
            _scheduleReconnect('production_channels', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → live_sessions: $error');
            _scheduleReconnect('production_channels', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else {
            debugPrint('📡 live_sessions: $status ${error ?? ""}');
          }
        });

    // ─── archived_reports ──────────────────────────────────────────
    _archivedReportsChannel = _supabase
        .channel('rt_archived_reports_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'archived_reports',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [archived_reports] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onArchivedReportChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → archived_reports (factory: $factoryId)');
            _reconnectAttempts['archived_reports_channel'] = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → archived_reports — جدولة إعادة الاتصال...');
            _scheduleReconnect('archived_reports_channel', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → archived_reports: $error');
            _scheduleReconnect('archived_reports_channel', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else {
            debugPrint('📡 archived_reports: $status ${error ?? ""}');
          }
        });
    // ─── die_cutting_production_reports ─────────────────────────────
    _dieCuttingProductionChannel = _supabase
        .channel('rt_die_cutting_reports_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'die_cutting_production_reports',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [die_cutting_production_reports] event=${payload.eventType}',
            );
            _onDieCuttingReportChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → die_cutting_production_reports (factory: $factoryId)');
            _reconnectAttempts['die_cutting_reports_channel'] = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → die_cutting_production_reports — جدولة إعادة الاتصال...');
            _scheduleReconnect('die_cutting_reports_channel', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → die_cutting_production_reports: $error');
            _scheduleReconnect('die_cutting_reports_channel', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else {
            debugPrint('📡 die_cutting_production_reports: $status ${error ?? ""}');
          }
        });
  }

  /// إغلاق قنوات الإنتاج وتحريرها
  Future<void> _tearDownProductionChannels() async {
    try {
      if (_productionChannel != null) {
        await _supabase.removeChannel(_productionChannel!);
        _productionChannel = null;
      }
      if (_lineProductionChannel != null) {
        await _supabase.removeChannel(_lineProductionChannel!);
        _lineProductionChannel = null;
      }
      if (_liveSessionsChannel != null) {
        await _supabase.removeChannel(_liveSessionsChannel!);
        _liveSessionsChannel = null;
      }
      if (_archivedReportsChannel != null) {
        await _supabase.removeChannel(_archivedReportsChannel!);
        _archivedReportsChannel = null;
      }
      if (_dieCuttingProductionChannel != null) {
        await _supabase.removeChannel(_dieCuttingProductionChannel!);
        _dieCuttingProductionChannel = null;
      }
    } catch (e) {
      debugPrint('❌ _tearDownProductionChannels error: $e');
    }
  }

  // ==============================================================
  // Real-time Callbacks
  // ==============================================================

  // ─── die_cutting_production_reports ───────────────────────────────
  void _onDieCuttingReportChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      Map<String, dynamic> record = isDelete 
          ? (payload.oldRecord.isNotEmpty ? payload.oldRecord : payload.newRecord)
          : payload.newRecord;

      if (record.isEmpty) return;

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) return;

      if (!Hive.isBoxOpen('die_cutting_production_reports')) return;
      final box = Hive.box<DieCuttingProductionReport>('die_cutting_production_reports');
      
      final payloadSyncId = record['sync_id']?.toString();
      final payloadId     = record['id']?.toString();
      
      if (isDelete) {
        if (payloadSyncId != null && box.containsKey(payloadSyncId)) {
          await box.delete(payloadSyncId);
        } else if (payloadId != null && box.containsKey(payloadId)) {
          await box.delete(payloadId);
        }
      } else {
        final stableKey = payloadSyncId ?? payloadId;
        if (stableKey == null) return;
        
        final reportObj = DieCuttingProductionReport.fromJson(record);
        await box.put(stableKey, reportObj);
        debugPrint('✅ [die_cutting_production_reports] تم حفظ محلياً: $stableKey');
      }
    } catch (e) {
      debugPrint('❌ _onDieCuttingReportChange: $e');
    }
  }

  // ─── flexo_production_reports & line_production_reports → flexo_production_reports_box ───
  void _onProductionReportChange(
    PostgresChangePayload payload,
    String myFactoryId,
    String tableName,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;

      // ⚠️ عند DELETE: oldRecord يكون فارغاً إذا لم يكن REPLICA IDENTITY FULL مفعّلاً.
      // نستخدم newRecord كـ fallback لاستخراج المعرّف (id/sync_id).
      Map<String, dynamic> record;
      if (isDelete) {
        record = payload.oldRecord.isNotEmpty
            ? payload.oldRecord
            : payload.newRecord;
      } else {
        record = payload.newRecord;
      }

      if (record.isEmpty) {
        debugPrint('⚠️ [$tableName] DELETE payload فارغ تماماً! '
            'تأكد من: ALTER TABLE $tableName REPLICA IDENTITY FULL;');
        return;
      }

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [$tableName] تجاهل: factory مختلف'); return;
      }


      if (!Hive.isBoxOpen('flexo_production_reports_box')) {
        debugPrint('⚠️ [$tableName] Box flexo_production_reports_box مغلق!'); return;
      }
      final box = Hive.box<FlexoProductionReport>('flexo_production_reports_box');
      final stableKey = record['sync_id']?.toString() ?? record['id']?.toString();

      if (isDelete) {
        // ✅ نستخرج كلا المعرّفين من oldRecord للمقارنة الشاملة
        final payloadSyncId = record['sync_id']?.toString();
        final payloadId     = record['id']?.toString();
        if (payloadSyncId == null && payloadId == null) return;

        bool deleted = false;

        // 1️⃣ بحث مباشر بالمفتاح (الأسرع)
        for (final candidateKey in [payloadSyncId, payloadId]) {
          if (candidateKey != null && box.containsKey(candidateKey)) {
            await box.delete(candidateKey);
            deleted = true;
            debugPrint('🗑️ [$tableName] حُذف مباشرةً بالمفتاح=$candidateKey');
            break;
          }
        }

        // 2️⃣ بحث خطي شامل — يقارن (id, sync_id) من payload مع (id, sync_id) من كل سجل
        if (!deleted) {
          for (int i = 0; i < box.length; i++) {
            final v = box.getAt(i);
            if (v == null) continue;
            final vSyncId = v.syncId;
            final vId     = v.id;
            // مطابقة أي من المعرّفات الأربع
            final match =
                (payloadSyncId != null && (vSyncId == payloadSyncId || vId == payloadSyncId)) ||
                (payloadId     != null && (vSyncId == payloadId     || vId == payloadId));
            if (match) {
              final foundKey = box.keyAt(i);
              await box.delete(foundKey);
              deleted = true;
              debugPrint('🗑️ [$tableName] حُذف (خطي) key=$foundKey '
                  '(payload: sync_id=$payloadSyncId | id=$payloadId)');
              break;
            }
          }
        }

        if (!deleted) {
          debugPrint('⚠️ [$tableName] Ghost Record — لم يُعثر على سجل '
              '(payload: sync_id=$payloadSyncId | id=$payloadId)');
        }
      } else {
        if (stableKey == null) {
          debugPrint('⚠️ [$tableName] لا يوجد sync_id أو id!'); return;
        }
        final clientName = record['client_name'] ?? record['clientName'] ?? '';
        debugPrint('🌟 وصلت بيانات جديدة [$tableName]: $clientName (key: $stableKey)');

        dynamic existingKey = stableKey;
        FlexoProductionReport? existingRecord;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.syncId == stableKey) {
            existingKey = box.keyAt(i);
            existingRecord = item;
            break;
          }
        }

        Map<String, dynamic> updatedData = Map<String, dynamic>.from(record);
        updatedData['sync_id'] = stableKey;
        if (existingRecord != null &&
            existingRecord.department != null &&
            existingRecord.department!.isNotEmpty) {
          updatedData['department'] = existingRecord.department;
        }
        final reportObj = FlexoProductionReport.fromJson(updatedData);
        await box.put(existingKey, reportObj);
        debugPrint('✅ [$tableName] تم حفظ محلياً: $stableKey');

        if (payload.eventType == PostgresChangeEvent.insert) {
          final productName = record['product']?.toString() ?? record['product_name']?.toString() ?? '';
          final machineName = record['machine_name']?.toString() ?? record['machineName']?.toString() ?? '';
          const title = "📊 تقرير إنتاج جديد";
          final bodyParts = <String>[
            if (clientName.toString().trim().isNotEmpty) "العميل: $clientName",
            if (productName.trim().isNotEmpty) "الصنف: $productName",
            if (machineName.trim().isNotEmpty) "الماكينة: $machineName",
          ];
          final body = bodyParts.isNotEmpty ? bodyParts.join(' | ') : "تم إضافة تقرير إنتاج جديد";

          UIUtils.showTopOverlay(
            title: title,
            message: body,
          );

          UIUtils.showDesktopNotification(
            title: title,
            body: body,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ _onFlexoProductionReportChange: $e');
    }
  }

  // ─── archived_reports → crushingArchive / lineArchive / flexoArchive ──
  void _onArchivedReportChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;

      Map<String, dynamic> record;
      if (isDelete) {
        record = payload.oldRecord.isNotEmpty
            ? payload.oldRecord
            : payload.newRecord;
      } else {
        record = payload.newRecord;
      }

      if (record.isEmpty) {
        debugPrint(
          '⚠️ [archived_reports] DELETE payload فارغ — تأكد من: '
          'ALTER TABLE archived_reports REPLICA IDENTITY FULL;',
        );
        return;
      }

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) return;

      // تحديد الصندوق المناسب
      final hiveRecord = isDelete ? record : _reportToHive(record);
      final dept = isDelete
          ? (record['department']?.toString() ?? '')
          : (hiveRecord['department']?.toString() ?? 'flexo');
      final isCrushing = dept == 'crushing' || dept == 'die_cutting';
      final isProdLine = dept == 'production_line' ||
          (!isDelete && (hiveRecord['machineName'] ?? hiveRecord['machine_name'])?.toString() == 'خط الإنتاج');

      final String boxName = isCrushing
          ? 'crushingArchive'
          : isProdLine
              ? 'lineArchive'
              : 'flexoArchive';

      final Box targetBox = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);

      final syncId = record['sync_id']?.toString() ?? record['id']?.toString();
      if (syncId == null || syncId.isEmpty) {
        debugPrint('⚠️ [archived_reports] لا يوجد sync_id أو id في payload!');
        return;
      }

      if (isDelete) {
        // ✅ نستخرج كلا المعرّفين من oldRecord للمقارنة الشاملة
        final payloadSyncId = record['sync_id']?.toString();
        final payloadId     = record['id']?.toString();

        // بحث شامل في جميع صناديق الأرشيف لضمان الحذف الصحيح
        bool deleted = false;
        for (final name in ['crushingArchive', 'lineArchive', 'flexoArchive']) {
          if (deleted) break; // وجدناه في صندوق سابق، لا داعي للاستمرار
          final box = Hive.isBoxOpen(name)
              ? Hive.box(name)
              : await Hive.openBox(name);

          // 1️⃣ بحث مباشر بالمفتاح (الأسرع)
          for (final candidateKey in [payloadSyncId, payloadId]) {
            if (candidateKey != null && box.containsKey(candidateKey)) {
              await box.delete(candidateKey);
              deleted = true;
              debugPrint('🗑️ [archived_reports] حُذف مباشرةً من $name بالمفتاح=$candidateKey');
              break;
            }
          }
          if (deleted) break;

          // 2️⃣ بحث خطي شامل — (id, sync_id) من payload مع (id, sync_id) من كل سجل
          for (int i = 0; i < box.length; i++) {
            final v = box.getAt(i);
            if (v is! Map) continue;
            // الأرشيف مُغلَّف في { 'type', 'data', 'archiveDate' } أو مباشر
            final vData = (v['data'] is Map) ? v['data'] as Map : v;
            final vSyncId = vData['sync_id']?.toString();
            final vId     = vData['id']?.toString();
            // أيضاً المفتاح نفسه (box key قد يكون sync_id)
            final boxKey  = box.keyAt(i)?.toString();

            final match =
                (payloadSyncId != null &&
                    (vSyncId == payloadSyncId || vId == payloadSyncId || boxKey == payloadSyncId)) ||
                (payloadId != null &&
                    (vSyncId == payloadId || vId == payloadId || boxKey == payloadId));
            if (match) {
              final foundKey = box.keyAt(i);
              await box.delete(foundKey);
              deleted = true;
              debugPrint('🗑️ [archived_reports] حُذف (خطي) من $name key=$foundKey '
                  '(payload: sync_id=$payloadSyncId | id=$payloadId)');
              break;
            }
          }
        }
        if (!deleted) {
          debugPrint('⚠️ [archived_reports] Ghost Record — لم يُعثر على السجل '
              '(payload: sync_id=$payloadSyncId | id=$payloadId)');
        }
      } else {
        // INSERT / UPDATE → حفظ في الصندوق الصحيح
        hiveRecord['sync_id'] = syncId;
        final archiveEntry = {
          'type': 'REPORT',
          'data': hiveRecord,
          'archiveDate': record['date']?.toString() ?? DateTime.now().toIso8601String(),
        };
        await targetBox.put(syncId, archiveEntry);
        debugPrint('✅ [archived_reports] تم حفظ/تحديث في $boxName: $syncId');
      }
    } catch (e) {
      debugPrint('❌ _onArchivedReportChange: $e');
    }
  }

  // ─── live_sessions → flexo_live_sessions ────────────────────────
  void _onLiveSessionChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;

      // ⚠️ عند DELETE: Supabase يرسل oldRecord فقط إذا كان REPLICA IDENTITY FULL مفعّلاً.
      // إذا كان oldRecord فارغاً، نحاول استخدام newRecord كـ fallback.
      Map<String, dynamic> record;
      if (isDelete) {
        record = payload.oldRecord.isNotEmpty
            ? payload.oldRecord
            : payload.newRecord;
      } else {
        record = payload.newRecord;
      }

      if (record.isEmpty) {
        debugPrint(
          '⚠️ [live_sessions] DELETE payload فارغ تماماً! '
          'تأكد من تفعيل: ALTER TABLE live_sessions REPLICA IDENTITY FULL;',
        );
        return;
      }

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) return;

      if (!Hive.isBoxOpen('flexo_live_sessions')) {
        await Hive.openBox<LiveSession>('flexo_live_sessions');
      }
      final box = Hive.box<LiveSession>('flexo_live_sessions');

      // محاولة استخراج المفتاح الثابت من أكثر من حقل ممكن
      final stableKey = record['sync_id']?.toString()
          ?? record['id']?.toString();

      if (stableKey == null) {
        debugPrint('⚠️ [live_sessions] DELETE: لا يوجد sync_id أو id في payload!');
        return;
      }

      if (isDelete) {
        // ── بحث شامل في الصندوق للعثور على المفتاح ──
        dynamic keyToDelete;

        // أولاً: بحث مباشر بالـ stableKey
        if (box.containsKey(stableKey)) {
          keyToDelete = stableKey;
        } else {
          // ثانياً: بحث بالمرور على الكل ومقارنة session.id
          for (var i = 0; i < box.length; i++) {
            final session = box.getAt(i);
            if (session != null && session.id == stableKey) {
              keyToDelete = box.keyAt(i);
              break;
            }
          }
        }

        if (keyToDelete != null) {
          await box.delete(keyToDelete);
          debugPrint('🗑️ [live_sessions] حُذف محلياً: $stableKey');
        } else {
          debugPrint('⚠️ [live_sessions] لم يُعثر على الجلسة محلياً: $stableKey (ربما حُذف مسبقاً)');
        }
      } else {
        var session = LiveSession.fromJson(record);
        dynamic existingKey = stableKey;
        LiveSession? existingSession;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) {
            existingKey = box.keyAt(i);
            existingSession = item;
            break;
          }
        }
        if (existingSession != null) {
          final keepLayers = (session.paperLayers == null || session.paperLayers!.isEmpty) &&
              (existingSession.paperLayers != null && existingSession.paperLayers!.isNotEmpty);
          if (keepLayers) {
            session = LiveSession(
              id: session.id,
              machineName: session.machineName,
              clientName: session.clientName,
              productName: session.productName,
              productCode: session.productCode,
              orderNumber: session.orderNumber,
              technicianName: session.technicianName,
              startTime: session.startTime,
              downtimeIntervals: session.downtimeIntervals,
              isRunning: session.isRunning,
              lastStateChange: session.lastStateChange,
              dimensions: session.dimensions ?? existingSession.dimensions,
              isSheet: session.isSheet ?? existingSession.isSheet,
              imagePaths: session.imagePaths ?? existingSession.imagePaths,
              factoryId: session.factoryId ?? existingSession.factoryId,
              createdByDeviceId: session.createdByDeviceId ?? existingSession.createdByDeviceId,
              technicianId: session.technicianId ?? existingSession.technicianId,
              department: session.department ?? existingSession.department,
              shift: session.shift ?? existingSession.shift,
              paperLayers: existingSession.paperLayers,
            );
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
    String? dept = r['department']?.toString();
    if (dept == null || dept.trim().isEmpty || dept == 'null') {
      final machineName =
          (r['machineName'] ?? r['machine_name'])?.toString() ?? '';
      if (machineName == 'خط الإنتاج') {
        dept = 'production_line';
      }
      dept ??= 'flexo';
    }

    final dims = r['dimensions'] is Map
        ? Map<String, dynamic>.from(r['dimensions'])
        : <String, dynamic>{};

    final rawW = r['weight'] ?? r['weight_tons'] ?? dims['weight'] ?? 0;
    final double weightVal =
        rawW is num ? rawW.toDouble() : (double.tryParse(rawW.toString()) ?? 0.0);

    final rawLayers = r['paperLayers'] ??
        r['paper_layers'] ??
        dims['paperLayers'] ??
        dims['paper_layers'] ??
        [];
    final List<dynamic> layersList = rawLayers is List ? rawLayers : [];

    return {
      'sync_id': r['sync_id'],
      'id': r['id'] ?? r['sync_id'],
      'department': dept,
      'date': r['date'],
      'clientName': r['clientName'] ?? r['client_name'],
      'product': r['product'] ?? r['product_name'],
      'productCode': r['productCode'] ?? r['product_code'],
      'orderNumber': r['orderNumber'] ?? r['order_number'],
      'formNumber': r['formNumber'] ?? r['form_number'],
      'startTime': r['startTime'] ?? r['start_time'],
      'endTime': r['endTime'] ?? r['end_time'],
      'downtimeStart': r['downtimeStart'] ?? r['downtime_start'],
      'downtimeEnd': r['downtimeEnd'] ?? r['downtime_end'],
      'totalDowntime': r['totalDowntime'] ?? r['total_downtime'],
      'machineName': r['machineName'] ?? r['machine_name'],
      'technicianName': r['technicianName'] ?? r['technician_name'],
      'technician_id': r['technician_id'] ?? r['technicianId'],
      'quantity': r['quantity'],
      'weight': weightVal,
      'paperLayers': layersList,
      'lineWaste': r['lineWaste'] ?? r['line_waste'],
      'printWaste': r['printWaste'] ?? r['print_waste'],
      'notes': r['notes'],
      'isSheet': r['isSheet'] ?? r['is_sheet'] ?? false,
      'factory_id': r['factory_id'],
      'colors': r['colors'] ?? [],
      'dimensions': dims,
    };
  }

  // ==============================================================
  // Direct Push (Direct Batch Upsert) لتقارير الإنتاج والأرشيف
  // ==============================================================

  /// الرفع المباشر المتزامن لكافة التقارير والأرشيف إلى جداول flexo_production_reports و archived_reports
  Future<void> directPushAllReports() async {
    try {
      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) throw Exception('المصنع غير محدد (يجب تسجيل الدخول)');

      final prodBox = Hive.isBoxOpen('flexo_production_reports_box')
          ? Hive.box<FlexoProductionReport>('flexo_production_reports_box')
          : await Hive.openBox<FlexoProductionReport>('flexo_production_reports_box');

      final flexoArchiveBox = Hive.isBoxOpen('flexoArchive')
          ? Hive.box('flexoArchive')
          : await Hive.openBox('flexoArchive');
      final lineArchiveBox = Hive.isBoxOpen('lineArchive')
          ? Hive.box('lineArchive')
          : await Hive.openBox('lineArchive');
      final crushingArchiveBox = Hive.isBoxOpen('crushingArchive')
          ? Hive.box('crushingArchive')
          : await Hive.openBox('crushingArchive');

      if (prodBox.isEmpty && flexoArchiveBox.isEmpty && lineArchiveBox.isEmpty && crushingArchiveBox.isEmpty) {
        debugPrint('⚠️ [directPushAllReports] الصناديق المحلية للتقارير والأرشيف فارغة.');
        return;
      }

      // ─── 1. تجميع وتنظيف تقارير الإنتاج (flexo_production_reports) ───
      final rawProdRecords = <Map<String, dynamic>>[];
      for (final key in prodBox.keys) {
        final item = prodBox.get(key);
        if (item == null) continue;
        final payload = _normalizeReportPayload(item.toJson(), factoryId);
        if (payload != null) {
          rawProdRecords.add(payload);
        }
      }

      final Map<String, Map<String, dynamic>> uniqueProdRecords = {};
      for (var record in rawProdRecords) {
        final syncId = record['sync_id']?.toString();
        if (syncId != null && syncId.trim().isNotEmpty) {
          uniqueProdRecords[syncId] = record;
        }
      }
      final List<Map<String, dynamic>> productionReportsList = uniqueProdRecords.values.toList();

      // ─── 2. تجميع وتنظيف تقارير الأرشيف من كلا الـ boxes (archived_reports) ───
      final rawArchivedRecords = <Map<String, dynamic>>[];
      for (final archiveBox in [flexoArchiveBox, lineArchiveBox, crushingArchiveBox]) {
        for (final key in archiveBox.keys) {
          final item = archiveBox.get(key);
          if (item is! Map) continue;
          final itemMap = Map<String, dynamic>.from(item);
          final reportData = itemMap['data'] is Map
              ? Map<String, dynamic>.from(itemMap['data'])
              : itemMap;
          final payload = _normalizeReportPayload(reportData, factoryId);
          if (payload != null) {
            rawArchivedRecords.add(payload);
          }
        }
      }

      final Map<String, Map<String, dynamic>> uniqueArchivedRecords = {};
      for (var record in rawArchivedRecords) {
        final syncId = record['sync_id']?.toString();
        if (syncId != null && syncId.trim().isNotEmpty) {
          uniqueArchivedRecords[syncId] = record;
        }
      }
      final List<Map<String, dynamic>> archivedReportsList = uniqueArchivedRecords.values.toList();

      // ─── 3. الرفع المباشر لجداول Supabase ───
      final flexoReports = productionReportsList.where((r) => r['department'] != 'production_line').toList();
      final lineReports = productionReportsList.where((r) => r['department'] == 'production_line').toList();

      if (flexoReports.isNotEmpty) {
        debugPrint('📤 [directPushAllReports] جاري رفع ${flexoReports.length} تقرير إنتاج إلى flexo_production_reports...');
        await _safeUpsertReports('flexo_production_reports', flexoReports);
        debugPrint('✅ [directPushAllReports] تم رفع ${flexoReports.length} تقرير إنتاج بنجاح!');
      }

      if (lineReports.isNotEmpty) {
        debugPrint('📤 [directPushAllReports] جاري رفع ${lineReports.length} تقرير إنتاج خط إلى line_production_reports...');
        await _safeUpsertReports('line_production_reports', lineReports);
        debugPrint('✅ [directPushAllReports] تم رفع ${lineReports.length} تقرير إنتاج خط بنجاح!');
      }

      if (archivedReportsList.isNotEmpty) {
        debugPrint('📤 [directPushAllReports] جاري رفع ${archivedReportsList.length} تقرير أرشيف إلى archived_reports...');
        await _safeUpsertReports('archived_reports', archivedReportsList);
        debugPrint('✅ [directPushAllReports] تم رفع ${archivedReportsList.length} تقرير أرشيف بنجاح!');
      }

      // ─── 4. تنظيف طابور المزامنة من السجلات التي رُفعت بالفعل ───
      final queueBox = Hive.isBoxOpen('sync_queue')
          ? Hive.box('sync_queue')
          : await Hive.openBox('sync_queue');
      final keysToDelete = <dynamic>[];
      for (var i = 0; i < queueBox.length; i++) {
        final item = queueBox.getAt(i);
        if (item is Map &&
            (item['table']?.toString() == 'flexo_production_reports' ||
             item['table']?.toString() == 'line_production_reports' ||
             item['table']?.toString() == 'archived_reports')) {
          keysToDelete.add(queueBox.keyAt(i));
        }
      }
      for (final k in keysToDelete) {
        await queueBox.delete(k);
      }
      debugPrint('🧹 [directPushAllReports] تم مسح ${keysToDelete.length} سجل من sync_queue.');
    } catch (e) {
      debugPrint('❌ directPushAllReports error: $e');
      rethrow;
    }
  }

  /// مساعد لتوحيد هيكل التقارير وتنظيفها (Sanitization)
  Map<String, dynamic>? _normalizeReportPayload(Map<String, dynamic> r, String factoryId) {
    final String syncId = (r['sync_id']?.toString().trim().isNotEmpty == true)
        ? r['sync_id'].toString().trim()
        : ((r['id']?.toString().trim().isNotEmpty == true)
            ? r['id'].toString().trim()
            : '');
    if (syncId.isEmpty) return null;

    final dims = (r['dimensions'] is Map)
        ? Map<String, dynamic>.from(r['dimensions'])
        : <String, dynamic>{};

    final rawW = r['weight'] ?? r['weight_tons'] ?? dims['weight'] ?? 0;
    final double weightVal =
        rawW is num ? rawW.toDouble() : (double.tryParse(rawW.toString()) ?? 0.0);

    final rawLayers = r['paperLayers'] ??
        r['paper_layers'] ??
        dims['paperLayers'] ??
        dims['paper_layers'] ??
        [];
    final List<dynamic> layersList = rawLayers is List ? rawLayers : [];

    dims['weight'] = weightVal;
    dims['paperLayers'] = layersList;

    final payload = <String, dynamic>{
      'sync_id': syncId,
      'factory_id': r['factory_id']?.toString().trim().isNotEmpty == true
          ? r['factory_id'].toString().trim()
          : factoryId,
      'date': r['date']?.toString() ?? DateTime.now().toIso8601String(),
      'client_name': r['client_name']?.toString() ?? r['clientName']?.toString() ?? '',
      'product': r['product']?.toString() ?? r['product_name']?.toString() ?? '',
      'product_code': r['product_code']?.toString() ?? r['productCode']?.toString() ?? '',
      'dimensions': dims,
      'colors': (r['colors'] is List)
          ? List<dynamic>.from(r['colors'])
          : [],
      'quantity': int.tryParse(r['quantity']?.toString() ?? '') ?? 0,
      'notes': r['notes']?.toString(),
      'order_number': r['order_number']?.toString() ?? r['orderNumber']?.toString(),
      'start_time': r['start_time']?.toString() ?? r['startTime']?.toString(),
      'end_time': r['end_time']?.toString() ?? r['endTime']?.toString(),
      'line_waste': int.tryParse((r['line_waste'] ?? r['lineWaste'])?.toString() ?? ''),
      'print_waste': int.tryParse((r['print_waste'] ?? r['printWaste'])?.toString() ?? ''),
      'downtime_start': r['downtime_start']?.toString() ?? r['downtimeStart']?.toString(),
      'downtime_end': r['downtime_end']?.toString() ?? r['downtimeEnd']?.toString(),
      'total_downtime': r['total_downtime']?.toString() ?? r['totalDowntime']?.toString(),
      'machine_name': r['machine_name']?.toString() ?? r['machineName']?.toString(),
      'technician_name': r['technician_name']?.toString() ?? r['technicianName']?.toString(),
      'technician_id': r['technician_id']?.toString() ?? r['technicianId']?.toString(),
      'department': r['department']?.toString() ??
          ((r['machine_name']?.toString() == 'خط الإنتاج' ||
                  r['machineName']?.toString() == 'خط الإنتاج')
              ? 'production_line'
              : 'flexo'),
      'paperLayers': layersList,
      'paper_layers': layersList,
      'weight': weightVal,
      'is_sheet': r['is_sheet'] == true || r['isSheet'] == true || r['is_sheet'] == 'true',
    };

    // الحذف القاطع لمفتاح 'id' من جميع الخرائط (Unconditional Remove)
    payload.remove('id');

    // إزالة أو تنظيف أي قيم null
    payload.removeWhere((key, value) =>
        value == null ||
        (value is String && value.trim().toLowerCase() == 'null'));

    return payload;
  }

  /// رفع آمن مع التعامل مع احتمال اختلاف أعمدة الجدول بالسحابة
  Future<void> _safeUpsertReports(String table, List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    try {
      await _supabase.from(table).upsert(records, onConflict: 'sync_id');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.code == '42703' || e.message.toLowerCase().contains('column')) {
        debugPrint('⚠️ [directPushAllReports] حقل غير موجود في جدول $table (${e.message})، جاري إزالة الأعمدة الاختيارية وإعادة الرفع...');
        for (var r in records) {
          if (e.message.contains('technician_id')) r.remove('technician_id');
          if (e.message.contains('is_sheet')) r.remove('is_sheet');
        }
        await _supabase.from(table).upsert(records, onConflict: 'sync_id');
      } else {
        rethrow;
      }
    }
  }
}

