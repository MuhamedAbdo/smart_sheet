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

  /// المزامنة المبدئية لجدول production_reports → Hive box: inkReports
  Future<void> _initProductionReports(String factoryId) async {
    try {
      final res = await _supabase
          .from('production_reports')
          .select()
          .eq('factory_id', factoryId)
          .order('date', ascending: false)
          .order('end_time', ascending: false);

      final box = Hive.isBoxOpen('inkReports')
          ? Hive.box('inkReports')
          : await Hive.openBox('inkReports');

      // منع المسح العكسي التلقائي (Safe Pull Logic)
      if (res.isEmpty || (box.isNotEmpty && res.length < box.length * 0.5)) {
        debugPrint(
          '⚠️ [Safe Pull] بيانات التقارير/الأرشيف من السيرفر فارغة... يُمنع مسح الصندوق المحلي.',
        );
        return;
      }

      final Map<dynamic, dynamic> reportsMap = {};
      for (final r in res) {
        final hiveRecord = _reportToHive(r);
        final syncId = r['sync_id'] ?? r['id'];
        hiveRecord['sync_id'] = syncId;

        final existing = box.get(syncId);
        if (existing is Map) {
          final existingW = existing['weight'] ?? 0;
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
          final existingLayers = existing['paperLayers'] is List
              ? (existing['paperLayers'] as List)
              : [];
          if (currentLayers.isEmpty && existingLayers.isNotEmpty) {
            hiveRecord['paperLayers'] = existingLayers;
            if (hiveRecord['dimensions'] is Map) {
              (hiveRecord['dimensions'] as Map)['paperLayers'] = existingLayers;
            }
          }
        }

        reportsMap[syncId] = hiveRecord;
      }
      for (var key in reportsMap.keys) {
        await box.put(key, reportsMap[key]);
      }
      debugPrint('✅ ProductionSync: تم استرجاع ${res.length} production_reports.');
    } catch (e) {
      debugPrint('❌ ProductionSync._initProductionReports: $e');
    }
  }

  /// المزامنة المبدئية لجدول archived_reports → Hive boxes: flexoArchive & lineArchive
  Future<void> _initArchivedReports(String factoryId) async {
    try {
      final res = await _supabase
          .from('archived_reports')
          .select()
          .eq('factory_id', factoryId)
          .order('date', ascending: false);

      final flexoBox = Hive.isBoxOpen('flexoArchive')
          ? Hive.box('flexoArchive')
          : await Hive.openBox('flexoArchive');
      final lineBox = Hive.isBoxOpen('lineArchive')
          ? Hive.box('lineArchive')
          : await Hive.openBox('lineArchive');

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
            (hiveRecord['machineName'] ?? hiveRecord['machine_name'])
                    ?.toString() ==
                'خط الإنتاج';
        final targetBox = isProdLine ? lineBox : flexoBox;

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
        final wrongBox = isProdLine ? flexoBox : lineBox;
        if (wrongBox.containsKey(syncId)) {
          await wrongBox.delete(syncId);
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
          '✅ ProductionSync: تم استرجاع ${res.length} archived_reports (مُقسَّمة بين flexoArchive و lineArchive).');
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
            _reconnectAttempts['production_channels'] = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → production_reports — جدولة إعادة الاتصال...');
            _scheduleReconnect('production_channels', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → production_reports: $error');
            _scheduleReconnect('production_channels', () async {
              await _tearDownProductionChannels();
              _setupProductionChannels(factoryId);
            });
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
        debugPrint('⚠️ [production_reports] DELETE payload فارغ تماماً! '
            'تأكد من: ALTER TABLE production_reports REPLICA IDENTITY FULL;');
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
        Map<dynamic, dynamic>? existingRecord;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item is Map && item['sync_id'] == stableKey) {
            existingKey = box.keyAt(i);
            existingRecord = item;
            break;
          }
        }

        final hiveRecord = _reportToHive(record);
        hiveRecord['sync_id'] = stableKey;
        if (existingRecord != null &&
            existingRecord['department'] != null &&
            existingRecord['department'].toString().isNotEmpty) {
          hiveRecord['department'] = existingRecord['department'];
        }
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

  /// الرفع المباشر المتزامن لكافة التقارير والأرشيف إلى جداول production_reports و archived_reports
  Future<void> directPushAllReports() async {
    try {
      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) throw Exception('المصنع غير محدد (يجب تسجيل الدخول)');

      final prodBox = Hive.isBoxOpen('inkReports')
          ? Hive.box('inkReports')
          : await Hive.openBox('inkReports');

      final flexoArchiveBox = Hive.isBoxOpen('flexoArchive')
          ? Hive.box('flexoArchive')
          : await Hive.openBox('flexoArchive');
      final lineArchiveBox = Hive.isBoxOpen('lineArchive')
          ? Hive.box('lineArchive')
          : await Hive.openBox('lineArchive');

      if (prodBox.isEmpty && flexoArchiveBox.isEmpty && lineArchiveBox.isEmpty) {
        debugPrint('⚠️ [directPushAllReports] الصناديق المحلية للتقارير والأرشيف فارغة.');
        return;
      }

      // ─── 1. تجميع وتنظيف تقارير الإنتاج (production_reports) ───
      final rawProdRecords = <Map<String, dynamic>>[];
      for (final key in prodBox.keys) {
        final item = prodBox.get(key);
        if (item is! Map) continue;
        final payload = _normalizeReportPayload(Map<String, dynamic>.from(item), factoryId);
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
      for (final archiveBox in [flexoArchiveBox, lineArchiveBox]) {
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
      if (productionReportsList.isNotEmpty) {
        debugPrint('📤 [directPushAllReports] جاري رفع ${productionReportsList.length} تقرير إنتاج إلى production_reports...');
        await _safeUpsertReports('production_reports', productionReportsList);
        debugPrint('✅ [directPushAllReports] تم رفع ${productionReportsList.length} تقرير إنتاج بنجاح!');
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
            (item['table']?.toString() == 'production_reports' ||
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
