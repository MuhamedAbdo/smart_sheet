// lib/services/sync/factory_sync.dart
//
// Mixin: FactorySync on SyncServiceBase
// المسؤولية: مزامنة بيانات المصنع من Supabase:
//   1️⃣  أوقات الوردية العامة  → جدول factories       → ThemeProvider
//   2️⃣  جدول أيام الأسبوع    → جدول factory_schedule → Hive 'factory_schedule'
//
// ⚠️  لا تعدّل هذا الملف إلا عند تغيير منطق وردية المصنع حصراً.
//
// 🔑  part of sync_service.dart — نفس الـ library → يرى جميع الـ private.
//     mixin on SyncServiceBase → يرى _supabase + _scheduleReconnect + _reconnectAttempts.
//
// 🔒  ضمان عدم الحلقة التكرارية (Infinite Loop Guard):
//     _applyShiftTimes تستدعي setShiftStart/End (Hive + notifyListeners فقط).
//     الرفع إلى Supabase يتم حصراً من onTap الأدمن داخل factory_schedule_card.dart.

part of '../sync_service.dart';

mixin FactorySync on SyncServiceBase {
  // ─── حقول القنوات ────────────────────────────────────────────────
  RealtimeChannel? _factoryChannel;
  RealtimeChannel? _scheduleChannel; // قناة factory_schedule

  // ==============================================================
  // Initial Sync — factories (shift times)
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

    // ─── تحميل جدول الأيام الأسبوعية بعد أوقات الوردية ──────────
    await _initFactorySchedule(factoryId);
  }

  // ==============================================================
  // Initial Sync — factory_schedule (per-day config)
  // ==============================================================

  /// تنزيل جدول أيام الأسبوع من Supabase عند بدء التشغيل وكتابتها في Hive.
  Future<void> _initFactorySchedule(String factoryId) async {
    try {
      final rows = await _supabase
          .from('factory_schedule')
          .select()
          .eq('factory_id', factoryId);

      if (rows.isEmpty) {
        debugPrint('⚠️ FactorySync: لا توجد بيانات factory_schedule للمصنع $factoryId');
        return;
      }

      await _applyScheduleRows(rows.cast<Map<String, dynamic>>());
      debugPrint('✅ FactorySync: تم تحميل ${rows.length} أيام من factory_schedule.');
    } catch (e) {
      debugPrint('❌ FactorySync._initFactorySchedule: $e');
    }
  }

  // ==============================================================
  // Channel Setup & Teardown — factories
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

    // ─── قناة factory_schedule بجانب قناة factories ──────────────
    _setupScheduleChannel(factoryId);
  }

  // ==============================================================
  // Channel Setup & Teardown — factory_schedule
  // ==============================================================

  /// إعداد قناة Realtime لـ factory_schedule مصفاة بـ factory_id.
  /// عند أي INSERT / UPDATE تُكتَب الصفوف فوراً في Hive 'factory_schedule'.
  void _setupScheduleChannel(String factoryId) {
    if (_scheduleChannel != null) return;

    _scheduleChannel = _supabase
        .channel('rt_factory_schedule_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'factory_schedule',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'factory_id',
            value: factoryId,
          ),
          callback: (payload) {
            debugPrint(
                '📥 [factory_schedule] event=${payload.eventType} new=${payload.newRecord}');
            _onScheduleChange(payload);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → factory_schedule (factory: $factoryId)');
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → factory_schedule — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → factory_schedule: $error');
            _scheduleReconnect();
          } else {
            debugPrint('📡 factory_schedule: $status ${error ?? ""}');
          }
        });
  }

  /// إغلاق قناة المصنع وتحريرها من الذاكرة.
  Future<void> _tearDownFactoryChannel() async {
    if (_factoryChannel != null) {
      await _supabase.removeChannel(_factoryChannel!);
      _factoryChannel = null;
    }
    await _tearDownScheduleChannel();
  }

  Future<void> _tearDownScheduleChannel() async {
    if (_scheduleChannel != null) {
      await _supabase.removeChannel(_scheduleChannel!);
      _scheduleChannel = null;
    }
  }

  // ==============================================================
  // Real-time Callbacks — factories
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
  // Real-time Callbacks — factory_schedule
  // ==============================================================

  /// معالجة حدث INSERT/UPDATE لصف يوم واحد من factory_schedule.
  /// يكتب الصف مباشرةً في Hive → يُحدِّث ValueListenableBuilder على الفور.
  void _onScheduleChange(PostgresChangePayload payload) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;
      if (record.isEmpty) return;

      await _applyScheduleRows([record]);
      debugPrint('🔄 [factory_schedule] تم تحديث ${record["day_name"]} من السيرفر.');
    } catch (e) {
      debugPrint('❌ _onScheduleChange: $e');
    }
  }

  // ==============================================================
  // Helpers — apply rows into Hive
  // ==============================================================

  /// يكتب قائمة صفوف factory_schedule داخل Hive 'factory_schedule'.
  /// المفتاح = day_name (مثل 'Friday') لضمان التطابق مع _initDefaultSchedule.
  Future<void> _applyScheduleRows(List<Map<String, dynamic>> rows) async {
    if (!Hive.isBoxOpen('factory_schedule')) {
      debugPrint('⚠️ FactorySync: صندوق factory_schedule مغلق، تجاهل التحديث.');
      return;
    }
    final box = Hive.box<DaySchedule>('factory_schedule');
    for (final row in rows) {
      final dayName = row['day_name']?.toString();
      if (dayName == null || dayName.isEmpty) continue;

      final existing = box.get(dayName);
      if (existing != null) {
        // تحديث القيم في الكائن الموجود (يُفعِّل ValueListenable)
        existing.isWorkingDay = row['is_working_day'] as bool? ?? true;
        existing.shiftStart = row['shift_start']?.toString() ?? existing.shiftStart;
        existing.shiftEnd   = row['shift_end']?.toString()   ?? existing.shiftEnd;
        await existing.save();
      } else {
        // صف جديد لم يكن موجوداً محلياً
        final newDay = DaySchedule(
          dayName: dayName,
          isWorkingDay: row['is_working_day'] as bool? ?? true,
          shiftStart: row['shift_start']?.toString() ?? '08:00 AM',
          shiftEnd:   row['shift_end']?.toString()   ?? '05:00 PM',
        );
        await box.put(dayName, newDay);
      }
    }
  }

  // ==============================================================
  // Helpers — shift times (factories table)
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

