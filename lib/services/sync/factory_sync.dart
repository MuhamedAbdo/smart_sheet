// lib/services/sync/factory_sync.dart
//
// Mixin: FactorySync on SyncServiceBase
// المسؤولية: مزامنة أوقات الوردية من جدول factories
//   • القناة  : _factoryChannel
//   • Callback: _onFactoryChange
//   • المزامنة المبدئية: _initFactorySettings
//   • المساعدان: _applyShiftTimes + _parseShiftTime
//
// ⚠️  لا تعدّل هذا الملف إلا عند تغيير منطق وردية المصنع حصراً.
//
// 🔑  part of sync_service.dart — نفس الـ library → يرى جميع الـ private.
//     mixin on SyncServiceBase → يرى _supabase + _scheduleReconnect + _reconnectAttempts.
//
// 🔒  ضمان عدم الحلقة التكرارية (Infinite Loop Guard):
//     _applyShiftTimes تستدعي setShiftStart/End (Hive + notifyListeners فقط).
//     الرفع إلى Supabase يتم حصراً من onTap الأدمن داخل settings_screen.dart.

part of '../sync_service.dart';

mixin FactorySync on SyncServiceBase {
  // ─── حقول القنوات ────────────────────────────────────────────────
  RealtimeChannel? _factoryChannel;

  // ==============================================================
  // Initial Sync
  // ==============================================================

  /// المزامنة المبدئية لأوقات الوردية من جدول factories عند بدء التشغيل.
  /// يُطبَّق التغيير محلياً عبر ThemeProvider (Hive + notifyListeners).
  Future<void> _initFactorySettings(
      String factoryId, ThemeProvider themeProvider) async {
    try {
      final res = await _supabase
          .from('factories')
          .select('shift_start_time, shift_end_time')
          .eq('factory_id', factoryId)
          .maybeSingle();

      if (res == null) {
        debugPrint(
            '⚠️ FactorySync: لا توجد بيانات وردية للمصنع $factoryId');
        return;
      }

      await _applyShiftTimes(res, themeProvider);
      debugPrint(
          '✅ FactorySync: تم تحميل بيانات الوردية للمصنع $factoryId.');
    } catch (e) {
      debugPrint('❌ FactorySync._initFactorySettings: $e');
    }
  }

  // ==============================================================
  // Channel Setup & Teardown
  // ==============================================================

  /// إعداد قناة Real-time للاستماع لأي تحديث على وردية المصنع.
  /// الفلتر: id == factoryId (المفتاح الأساسي لجدول factories).
  void _setupFactoryChannel(
      String factoryId, ThemeProvider themeProvider) {
    if (_factoryChannel != null) {
      debugPrint('📡 FactorySync: القناة نشطة بالفعل للمصنع $factoryId. تم تخطي الاشتراك.');
      return;
    }
    _factoryChannel = _supabase
        .channel('rt_factory_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'factories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'factory_id',
            value: factoryId,
          ),
          callback: (payload) {
            debugPrint(
                '📥 [factories] event=${payload.eventType} new=${payload.newRecord}');
            _onFactoryChange(payload, themeProvider);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint(
                '✅ SUBSCRIBED → factories (factory: $factoryId)');
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint(
                '⏱️ TIMEOUT → factories — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → factories: $error');
            _scheduleReconnect();
          } else {
            debugPrint('📡 factories: $status ${error ?? ""}');
          }
        });
  }

  /// إغلاق قناة المصنع وتحريرها من الذاكرة.
  Future<void> _tearDownFactoryChannel() async {
    if (_factoryChannel != null) {
      await _supabase.removeChannel(_factoryChannel!);
      _factoryChannel = null;
    }
  }

  // ==============================================================
  // Real-time Callback
  // ==============================================================

  /// معالجة حدث UPDATE الوارد من Supabase Realtime.
  /// يطبّق الأوقات الجديدة محلياً دون أي رفع مرتد لـ Supabase.
  void _onFactoryChange(
      PostgresChangePayload payload, ThemeProvider themeProvider) async {
    try {
      final record = payload.newRecord;
      if (record.isEmpty) {
        debugPrint('⚠️ [factories] payload فارغ!');
        return;
      }
      await _applyShiftTimes(record, themeProvider);
      debugPrint('🔄 [factories] تم تحديث الوردية من السيرفر.');
    } catch (e) {
      debugPrint('❌ _onFactoryChange: $e');
    }
  }

  // ==============================================================
  // Helpers
  // ==============================================================

  /// تطبيق أوقات الوردية على ThemeProvider.
  ///
  /// 🔒 Infinite Loop Guard: هذه الدالة تستدعي setShiftStart/End
  /// التي تحدث Hive و notifyListeners فقط، دون أي رفع إلى Supabase.
  /// الرفع حصراً من onTap الأدمن في settings_screen.dart.
  Future<void> _applyShiftTimes(
      Map<String, dynamic> record, ThemeProvider themeProvider) async {
    final startRaw = record['shift_start_time']?.toString();
    final endRaw = record['shift_end_time']?.toString();

    final startTime = _parseShiftTime(startRaw);
    final endTime = _parseShiftTime(endRaw);

    if (startTime != null) await themeProvider.setShiftStart(startTime);
    if (endTime != null) await themeProvider.setShiftEnd(endTime);
  }

  /// تحويل نص الوقت "HH:MM" أو "HH:MM:SS" (صيغة PostgreSQL TIME) إلى TimeOfDay.
  /// يُعيد null عند أي خطأ في الصيغة بدلاً من الانهيار.
  TimeOfDay? _parseShiftTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final parts = raw.split(':');
      if (parts.length < 2) return null;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      debugPrint('⚠️ FactorySync: فشل تحليل الوقت "$raw"');
      return null;
    }
  }
}
