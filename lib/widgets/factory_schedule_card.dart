// lib/widgets/factory_schedule_card.dart
//
// كارت "جدول وردية أيام الأسبوع" في شاشة الإعدادات.
//
// • السوبر أدمن (mohamedabdo9999933@gmail.com) يستطيع التعديل.
// • بقية المستخدمين: عرض قراءة فقط (Read-Only / Disabled).
// • ValueListenableBuilder يستمع لـ Hive.box('factory_schedule').listenable()
//   → تحديث فوري على جميع الأجهزة بلا إعادة تشغيل.

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/models/day_schedule.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:smart_sheet/services/supabase_manager.dart';

class FactoryScheduleCard extends StatelessWidget {
  const FactoryScheduleCard({super.key});

  // ─── تحويل '08:00 AM' → TimeOfDay ──────────────────────────────────────
  static TimeOfDay _parseTime(String raw) {
    try {
      final parts = raw.split(' ');
      final hm = parts[0].split(':');
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      final isPm = parts.length > 1 && parts[1].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  // ─── تحويل TimeOfDay → '08:00 AM' ──────────────────────────────────────
  static String _fmtTime(TimeOfDay t) {
    final period = t.hour < 12 ? 'AM' : 'PM';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    if (!Hive.isBoxOpen('factory_schedule')) {
      return const SizedBox.shrink();
    }

    final box = Hive.box<DaySchedule>('factory_schedule');

    return ValueListenableBuilder<Box<DaySchedule>>(
      valueListenable: box.listenable(),
      builder: (context, scheduleBox, _) {
        final bool isSuperAdmin = PermissionHelper.isSuperAdmin;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── عنوان الكارت ───────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'جدول وردية أيام الأسبوع',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isSuperAdmin)
                      const Tooltip(
                        message: 'أنت مسجّل كمسؤول — يمكنك التعديل',
                        child: Icon(Icons.admin_panel_settings,
                            size: 16, color: Colors.orange),
                      )
                    else
                      Tooltip(
                        message: 'عرض فقط — التعديل محظور على هذا الجهاز',
                        child: Icon(Icons.lock_outline,
                            size: 16, color: Colors.grey.shade400),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                if (!isSuperAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'يمكنك رؤية الجدول فقط، لا يحق لك تعديله.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),

                const Divider(),

                // ─── قائمة الأيام السبعة ─────────────────────────────────
                ...DaySchedule.orderedDays.map((dayName) {
                  final DaySchedule? schedule = scheduleBox.get(dayName);
                  if (schedule == null) return const SizedBox.shrink();
                  return _DayRow(
                    schedule: schedule,
                    isSuperAdmin: isSuperAdmin,
                    onToggleWorkDay: (val) async {
                      schedule.isWorkingDay = val;
                      await schedule.save();
                      await _upsertToSupabase(schedule);
                    },
                    onPickStart: () async =>
                        _pickTime(context, schedule, isStart: true),
                    onPickEnd: () async =>
                        _pickTime(context, schedule, isStart: false),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTime(BuildContext context, DaySchedule schedule,
      {required bool isStart}) async {
    final current =
        _parseTime(isStart ? schedule.shiftStart : schedule.shiftEnd);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked == null) return;
    if (isStart) {
      schedule.shiftStart = _fmtTime(picked);
    } else {
      schedule.shiftEnd = _fmtTime(picked);
    }
    await schedule.save();
    await _upsertToSupabase(schedule);
  }

  // ─── رفع صف يوم واحد إلى Supabase (upsert) ─────────────────────────────
  /// يُستدعَى فقط من حساب الأدمن بعد أي تعديل ناجح في Hive.
  /// على باقي الأجهزة، التحديث يصل عبر Realtime channel.
  static Future<void> _upsertToSupabase(DaySchedule schedule) async {
    try {
      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) {
        debugPrint('⚠️ FactoryScheduleCard: لا factory_id — تم تخطي الرفع.');
        return;
      }
      final payload = {
        'factory_id': factoryId,
        'day_name': schedule.dayName,
        'is_working_day': schedule.isWorkingDay,
        'shift_start': schedule.shiftStart,
        'shift_end': schedule.shiftEnd,
      };
      await Supabase.instance.client
          .from('factory_schedule')
          .upsert(payload, onConflict: 'day_name');
      debugPrint('✅ [factory_schedule] تم رفع ${schedule.dayName} إلى Supabase.');
    } catch (e) {
      debugPrint('❌ [factory_schedule] فشل الرفع: $e');
    }
  }
}

// ─── صف يوم واحد ────────────────────────────────────────────────────────────
class _DayRow extends StatelessWidget {
  final DaySchedule schedule;
  final bool isSuperAdmin;
  final ValueChanged<bool> onToggleWorkDay;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DayRow({
    required this.schedule,
    required this.isSuperAdmin,
    required this.onToggleWorkDay,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isOff = !schedule.isWorkingDay;
    final disabledColor = Colors.grey.shade400;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              // ── اسم اليوم ─────────────────────────────────────────────
              SizedBox(
                width: 72,
                child: Text(
                  schedule.arabicName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOff ? disabledColor : null,
                  ),
                ),
              ),

              // ── Switch: يوم عمل / عطلة ───────────────────────────────
              Transform.scale(
                scale: 0.80,
                child: Switch(
                  value: schedule.isWorkingDay,
                  onChanged: isSuperAdmin ? onToggleWorkDay : null,
                  activeTrackColor: Colors.teal,
                  inactiveThumbColor: disabledColor,
                ),
              ),

              if (isOff) ...[
                const SizedBox(width: 8),
                Text(
                  'عطلة رسمية',
                  style: TextStyle(
                      fontSize: 12,
                      color: disabledColor,
                      fontStyle: FontStyle.italic),
                ),
              ] else ...[
                // ── وقت البداية ─────────────────────────────────────────
                Expanded(
                  child: _TimeChip(
                    label: 'بداية',
                    value: schedule.shiftStart,
                    enabled: isSuperAdmin,
                    onTap: onPickStart,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('→',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 6),
                // ── وقت النهاية ─────────────────────────────────────────
                Expanded(
                  child: _TimeChip(
                    label: 'نهاية',
                    value: schedule.shiftEnd,
                    enabled: isSuperAdmin,
                    onTap: onPickEnd,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

// ─── شريحة وقت قابلة للضغط ──────────────────────────────────────────────────
class _TimeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  const _TimeChip({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3)
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: enabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey)),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: enabled ? null : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
