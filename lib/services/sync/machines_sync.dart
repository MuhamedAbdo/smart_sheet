// lib/services/sync/machines_sync.dart
//
// Mixin: MachinesSync on SyncServiceBase
// المسؤولية: مزامنة جدول machines
//   • القناة: _machinesChannel
//   • الـ Callback: _onMachineChange
//   • المزامنة المبدئية: _initMachines
//
// ⚠️ لا تعدّل هذا الملف إلا عند تغيير منطق الماكينات حصراً.
//
// 🔑 part of sync_service.dart — نفس الـ library → يرى جميع الـ private.
//    mixin on SyncServiceBase → يرى _supabase + _scheduleReconnect + _reconnectAttempts.

part of '../sync_service.dart';

mixin MachinesSync on SyncServiceBase {
  // ─── حقول القنوات ────────────────────────────────────────────────
  RealtimeChannel? _machinesChannel;

  // ==============================================================
  // Initial Sync
  // ==============================================================

  /// المزامنة المبدئية لجدول machines → Hive box: flexo_machines
  Future<void> _initMachines(String factoryId) async {
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
        final dept = r['department']?.toString() ?? 'flexo';
        final dbId = r['id']?.toString();
        await box.put(
            existingKey,
            FlexoMachine(
                id: stableKey,
                name: r['name']?.toString() ?? '',
                department: dept,
                dbId: dbId));
      }
      debugPrint('✅ MachinesSync: تم استرجاع ${res.length} machines.');
    } catch (e) {
      debugPrint('❌ MachinesSync.initialize(machines): $e');
    }
  }

  // ==============================================================
  // Channel Setup & Teardown
  // ==============================================================

  /// إعداد قناة Real-time الخاصة بالماكينات
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
            _reconnectAttempts['machines_channel'] = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → machines — جدولة إعادة الاتصال...');
            _scheduleReconnect('machines_channel', () async {
              await _tearDownMachinesChannel();
              _setupMachinesChannel(factoryId);
            });
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → machines: $error');
            _scheduleReconnect('machines_channel', () async {
              await _tearDownMachinesChannel();
              _setupMachinesChannel(factoryId);
            });
          } else {
            debugPrint('📡 machines: $status ${error ?? ""}');
          }
        });
  }

  /// إغلاق قناة الماكينات وتحريرها
  Future<void> _tearDownMachinesChannel() async {
    if (_machinesChannel != null) {
      await _supabase.removeChannel(_machinesChannel!);
      _machinesChannel = null;
    }
  }

  // ==============================================================
  // Real-time Callbacks
  // ==============================================================

  // ─── machines → flexo_machines ─────────────────────────────────
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

      if (isDelete) {
        final deletedId = record['id']?.toString();
        final deletedSyncId = record['sync_id']?.toString();

        FlexoMachine? machineToDelete;
        dynamic keyToDelete;
        for (var i = 0; i < box.length; i++) {
          final m = box.getAt(i);
          if (m != null) {
            if ((deletedSyncId != null &&
                    deletedSyncId.isNotEmpty &&
                    m.id == deletedSyncId) ||
                (deletedId != null &&
                    deletedId.isNotEmpty &&
                    (m.id == deletedId || m.dbId == deletedId))) {
              machineToDelete = m;
              keyToDelete = box.keyAt(i);
              break;
            }
          }
        }

        if (keyToDelete != null) {
          await box.delete(keyToDelete);
          debugPrint(
              '🗑️ [machines] حُذفت الماكينة "${machineToDelete?.name}" محلياً بنجاح (key=$keyToDelete)');
        } else if (deletedSyncId != null &&
            deletedSyncId.isNotEmpty &&
            box.containsKey(deletedSyncId)) {
          await box.delete(deletedSyncId);
          debugPrint(
              '🗑️ [machines] حُذفت بالمفتاح المباشر (sync_id=$deletedSyncId)');
        } else if (deletedId != null &&
            deletedId.isNotEmpty &&
            box.containsKey(deletedId)) {
          await box.delete(deletedId);
          debugPrint('🗑️ [machines] حُذفت بالمفتاح المباشر (id=$deletedId)');
        } else {
          debugPrint(
              'ℹ️ [machines] الماكينة غير موجودة محلياً (قد تكون حُذفت بالفعل عند إجراء الحذف من هذا الجهاز): id=$deletedId | sync_id=$deletedSyncId');
        }
        return;
      }

      if (stableKey == null) {
        debugPrint('⚠️ [machines] لا يوجد sync_id أو id للتحديث!');
        return;
      }

      final machineName = record['name']?.toString() ?? '';
      dynamic existingKey = stableKey;
      for (var i = 0; i < box.length; i++) {
        final m = box.getAt(i);
        if (m != null && m.id == stableKey) {
          existingKey = box.keyAt(i);
          break;
        }
      }
      final dept = record['department']?.toString() ?? 'flexo';
      final dbId = record['id']?.toString();
      await box.put(
          existingKey,
          FlexoMachine(
              id: stableKey, name: machineName, department: dept, dbId: dbId));
      debugPrint(
          '✅ [machines] تم حفظ/تحديث: $machineName | dept=$dept (key=$existingKey)');
    } catch (e) {
      debugPrint('❌ _onMachineChange: $e');
    }
  }
}
