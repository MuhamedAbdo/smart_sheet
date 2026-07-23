// lib/services/sync/die_cutting_forms_sync.dart
//
// Mixin: DieCuttingFormsSync on SyncServiceBase
// المسؤولية: مزامنة جدول die_cutting_forms
//
// 🔑 part of sync_service.dart

part of '../sync_service.dart';

mixin DieCuttingFormsSync on SyncServiceBase {
  RealtimeChannel? _dieCuttingFormsChannel;

  // ==============================================================
  // دالة المزامنة الشاملة (Push & Pull)
  // ==============================================================
  Future<void> syncDieCuttingForms(String factoryId) async {
    try {
      await _initDieCuttingForms(factoryId);
      debugPrint('✅ DieCuttingFormsSync: تمت المزامنة الشاملة بنجاح.');
    } catch (e) {
      debugPrint('❌ DieCuttingFormsSync.syncDieCuttingForms: $e');
    }
  }

  // ==============================================================
  // الرفع المباشر (Direct Push)
  // ==============================================================
  Future<void> directPushAllDieCuttingForms(String factoryId) async {
    try {
      final box = Hive.isBoxOpen('die_cutting_forms')
          ? Hive.box<DieCuttingForm>('die_cutting_forms')
          : await Hive.openBox<DieCuttingForm>('die_cutting_forms');

      if (box.isEmpty) return;

      final recordsList = <Map<String, dynamic>>[];
      for (final form in box.values) {
        final r = form.toJson();
        r['factory_id'] = factoryId;
        r['sync_id'] = form.id;
        recordsList.add(r);
      }

      await _supabase.from('die_cutting_forms').upsert(
        recordsList,
      );
      
      debugPrint('✅ DieCuttingFormsSync: تم رفع ${recordsList.length} قالب تكسير.');
    } catch (e) {
      debugPrint('❌ DieCuttingFormsSync.directPushAllDieCuttingForms: $e');
    }
  }

  // ==============================================================
  // Initial Sync (Pull)
  // ==============================================================
  Future<void> _initDieCuttingForms(String factoryId) async {
    try {
      final res = await _supabase
          .from('die_cutting_forms')
          .select()
          .eq('factory_id', factoryId);

      final box = Hive.isBoxOpen('die_cutting_forms')
          ? Hive.box<DieCuttingForm>('die_cutting_forms')
          : await Hive.openBox<DieCuttingForm>('die_cutting_forms');

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
        
        final form = DieCuttingForm.fromJson(r);
        form.id = stableKey; // Guarantee ID match
        await box.put(existingKey, form);
      }
      debugPrint('✅ DieCuttingFormsSync: تم استرجاع ${res.length} قوالب.');
    } catch (e) {
      debugPrint('❌ DieCuttingFormsSync._initDieCuttingForms: $e');
    }
  }

  // ==============================================================
  // Channel Setup & Teardown
  // ==============================================================
  void _setupDieCuttingFormsChannel(String factoryId) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'factory_id',
      value: factoryId,
    );
    _dieCuttingFormsChannel = _supabase
        .channel('rt_die_cutting_forms_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'die_cutting_forms',
          filter: filter,
          callback: (payload) {
            _onDieCuttingFormChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _reconnectAttempts['die_cutting_forms_channel'] = 0;
            debugPrint('✅ SUBSCRIBED → die_cutting_forms (factory: $factoryId)');
          } else if (status == RealtimeSubscribeStatus.timedOut || status == RealtimeSubscribeStatus.channelError) {
            _scheduleReconnect('die_cutting_forms_channel', () async {
              await _tearDownDieCuttingFormsChannel();
              _setupDieCuttingFormsChannel(factoryId);
            });
          }
        });
  }

  Future<void> _tearDownDieCuttingFormsChannel() async {
    if (_dieCuttingFormsChannel != null) {
      await _supabase.removeChannel(_dieCuttingFormsChannel!);
      _dieCuttingFormsChannel = null;
    }
  }

  // ==============================================================
  // Real-time Callbacks
  // ==============================================================
  void _onDieCuttingFormChange(PostgresChangePayload payload, String myFactoryId) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;
      debugPrint('📥 [die_cutting_forms] event=${payload.eventType} new=$record');
      if (record.isEmpty) return;

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) return;

      if (!Hive.isBoxOpen('die_cutting_forms')) await Hive.openBox<DieCuttingForm>('die_cutting_forms');
      final box = Hive.box<DieCuttingForm>('die_cutting_forms');
      final stableKey = record['sync_id']?.toString() ?? record['id']?.toString();

      if (isDelete) {
        final deletedSyncId = stableKey;
        dynamic keyToDelete;
        for (var i = 0; i < box.length; i++) {
          final m = box.getAt(i);
          if (m != null && m.id == deletedSyncId) {
            keyToDelete = box.keyAt(i);
            break;
          }
        }
        if (keyToDelete != null) await box.delete(keyToDelete);
      } else {
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final m = box.getAt(i);
          if (m != null && m.id == stableKey) {
            existingKey = box.keyAt(i);
            break;
          }
        }
        final form = DieCuttingForm.fromJson(record);
        if (stableKey != null) form.id = stableKey;
        await box.put(existingKey, form);
      }
    } catch (e) {
      debugPrint('❌ DieCuttingFormsSync._onDieCuttingFormChange error: $e');
    }
  }
}
