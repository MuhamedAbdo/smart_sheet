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
        await box.put(existingKey, FlexoMachine(id: stableKey, name: r['name']?.toString() ?? ''));
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
      if (stableKey == null) { debugPrint('⚠️ [machines] لا يوجد sync_id أو id!'); return; }

      if (isDelete) {
        dynamic existingKey;
        for (var i = 0; i < box.length; i++) {
          final m = box.getAt(i);
          if (m != null && m.id == stableKey) { existingKey = box.keyAt(i); break; }
        }
        if (existingKey != null) {
          await box.delete(existingKey);
          debugPrint('🗑️ [machines] hُذفت محلياً: $stableKey');
        } else if (box.containsKey(stableKey)) {
          await box.delete(stableKey);
          debugPrint('🗑️ [machines] hُذفت بالمفتاح المباشر: $stableKey');
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
}
