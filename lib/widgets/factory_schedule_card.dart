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
import 'package:smart_sheet/services/supabase_manager.dart';

class FactoryScheduleCard extends StatelessWidget {
  final bool isAdmin;

  const FactoryScheduleCard({super.key, required this.isAdmin});

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

  // جلب الورديات الأساسية
  List<Shift> _getMasterShifts(Box settingsBox, Box<DaySchedule> scheduleBox) {
    final raw = settingsBox.get('master_shifts');
    if (raw != null && raw is List) {
      return raw.map((e) => Shift.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    // Fallback: جلب من أول يوم عمل متاح (كإعداد افتراضي مبدئي)
    for (var dayName in DaySchedule.orderedDays) {
      final schedule = scheduleBox.get(dayName);
      if (schedule != null && schedule.shifts != null && schedule.shifts!.isNotEmpty) {
        return schedule.shifts!
            .map((e) => Shift(name: e.name, startTime: e.startTime, endTime: e.endTime))
            .toList();
      }
    }
    return [
      Shift(name: 'الوردية الأولى', startTime: '08:00 AM', endTime: '04:00 PM')
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!Hive.isBoxOpen('factory_schedule') || !Hive.isBoxOpen('settings')) {
      return const SizedBox.shrink();
    }

    final scheduleBox = Hive.box<DaySchedule>('factory_schedule');
    final settingsBox = Hive.box('settings');

    return ValueListenableBuilder<Box>(
      valueListenable: settingsBox.listenable(keys: ['master_shifts']),
      builder: (context, settings, _) {
        return ValueListenableBuilder<Box<DaySchedule>>(
          valueListenable: scheduleBox.listenable(),
          builder: (context, scheduleBox, _) {
            final masterShifts = _getMasterShifts(settingsBox, scheduleBox);

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
                        const Icon(Icons.calendar_month,
                            color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'جدول وردية أيام الأسبوع',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isAdmin)
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

                    if (!isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'يمكنك رؤية الجدول فقط، لا يحق لك تعديله.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ),

                    const Divider(),

                    // ─── قسم الورديات الأساسية للمدير ─────────────────────────────────
                    if (isAdmin) ...[
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'الورديات الأساسية',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.done_all, size: 16, color: Colors.orange),
                            label: const Text('فرض على الكل',
                                style: TextStyle(fontSize: 12, color: Colors.orange)),
                            onPressed: () => _forceMasterShiftsToAllDays(
                                context, masterShifts, scheduleBox),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('إضافة وردية',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () => _showAddMasterShiftDialog(
                                context, masterShifts, settingsBox, scheduleBox),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...masterShifts.map((ms) => _buildMasterShiftItem(
                          context, ms, masterShifts, settingsBox, scheduleBox)),
                      const SizedBox(height: 16),
                      const Divider(thickness: 2),
                      const SizedBox(height: 8),
                    ],

                    const Text(
                      'تخصيص الأيام والاستثناءات',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    // ─── قائمة الأيام السبعة ─────────────────────────────────
                    ...DaySchedule.orderedDays.map((dayName) {
                      final DaySchedule? schedule = scheduleBox.get(dayName);
                      if (schedule == null) return const SizedBox.shrink();
                      return _DayRow(
                        schedule: schedule,
                        isAdmin: isAdmin,
                        onToggleWorkDay: (val) {
                          schedule.isWorkingDay = val;
                          schedule.save();
                          _upsertToSupabase(schedule);
                        },
                        onSave: () {
                          schedule.save();
                          _upsertToSupabase(schedule);
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── بناء عنصر الوردية الأساسية ─────────────────────────────
  Widget _buildMasterShiftItem(
      BuildContext context,
      Shift shift,
      List<Shift> currentMasterShifts,
      Box settingsBox,
      Box<DaySchedule> scheduleBox) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              flex: 3,
              child: Text(shift.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 4),
          Expanded(
              flex: 4,
              child: _TimeChip(
                label: 'الافتراضي (بداية)',
                value: shift.startTime,
                enabled: true,
                onTap: () => _pickTimeForMasterShift(
                    context, shift, true, currentMasterShifts, settingsBox, scheduleBox),
              )),
          const SizedBox(width: 6),
          const Text('→', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 6),
          Expanded(
              flex: 4,
              child: _TimeChip(
                label: 'الافتراضي (نهاية)',
                value: shift.endTime,
                enabled: true,
                onTap: () => _pickTimeForMasterShift(
                    context, shift, false, currentMasterShifts, settingsBox, scheduleBox),
              )),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              final newList = List<Shift>.from(currentMasterShifts)..remove(shift);
              _saveMasterShifts(newList, settingsBox, scheduleBox);
            },
          )
        ]));
  }

  Future<void> _pickTimeForMasterShift(
      BuildContext context,
      Shift shift,
      bool isStart,
      List<Shift> currentMasterShifts,
      Box settingsBox,
      Box<DaySchedule> scheduleBox) async {
    final current = FactoryScheduleCard._parseTime(
        isStart ? shift.startTime : shift.endTime);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;

    if (isStart) {
      shift.startTime = FactoryScheduleCard._fmtTime(picked);
    } else {
      shift.endTime = FactoryScheduleCard._fmtTime(picked);
    }
    _saveMasterShifts(currentMasterShifts, settingsBox, scheduleBox);
  }

  Future<void> _showAddMasterShiftDialog(BuildContext context,
      List<Shift> currentMasterShifts, Box settingsBox, Box<DaySchedule> scheduleBox) async {
    final nameCtrl = TextEditingController();
    TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 16, minute: 0);

    await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setState) {
            return AlertDialog(
                title: const Text('إضافة وردية أساسية جديدة'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'اسم الوردية (مثال: الصباحية)'),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: _TimeChip(
                            label: 'بداية',
                            value: FactoryScheduleCard._fmtTime(start),
                            enabled: true,
                            onTap: () async {
                              final p = await showTimePicker(
                                  context: ctx, initialTime: start);
                              if (p != null) setState(() => start = p);
                            })),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _TimeChip(
                            label: 'نهاية',
                            value: FactoryScheduleCard._fmtTime(end),
                            enabled: true,
                            onTap: () async {
                              final p = await showTimePicker(
                                  context: ctx, initialTime: end);
                              if (p != null) setState(() => end = p);
                            }))
                  ])
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء')),
                  ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final newShift = Shift(
                        name: nameCtrl.text.trim(),
                        startTime: FactoryScheduleCard._fmtTime(start),
                        endTime: FactoryScheduleCard._fmtTime(end),
                      );

                      // إغلاق النافذة فوراً قبل الحفظ لتجنب أي أخطاء متعلقة بالـ Context
                      Navigator.pop(ctx);

                      final newList = List<Shift>.from(currentMasterShifts)..add(newShift);
                      _saveMasterShifts(newList, settingsBox, scheduleBox);
                    },
                    child: const Text('إضافة'),
                  )
                ]);
          });
        });
  }

  Future<void> _saveMasterShifts(
      List<Shift> masterShifts, Box settingsBox, Box<DaySchedule> scheduleBox) async {
    
    // قراءة الورديات الأساسية القديمة قبل التحديث لمعرفة ما إذا كان اليوم قد تم تعديله يدوياً أم لا
    final oldData = settingsBox.get('master_shifts');
    final oldMasterShifts = <Shift>[];
    if (oldData != null) {
      for (var item in oldData) {
        oldMasterShifts.add(Shift.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    // 1. حفظ الورديات الأساسية محلياً في settings
    await settingsBox.put(
        'master_shifts', masterShifts.map((e) => e.toJson()).toList());

    // 2. توزيع الورديات الأساسية على جميع الأيام
    for (var dayName in DaySchedule.orderedDays) {
      final schedule = scheduleBox.get(dayName);
      if (schedule != null) {
        final currentShifts = schedule.shifts ?? [];
        final newShifts = <Shift>[];
        
        for (var ms in masterShifts) {
          final existingList = currentShifts.where((s) => s.name == ms.name).toList();
          final existing = existingList.isNotEmpty ? existingList.first : null;
          
          final oldMasterList = oldMasterShifts.where((s) => s.name == ms.name).toList();
          final oldMaster = oldMasterList.isNotEmpty ? oldMasterList.first : null;

          if (existing != null) {
            // التحقق مما إذا كان المستخدم قد عدل هذا اليوم يدوياً (استثناء) 
            // إذا كان الوقت في اليوم يطابق وقت الـ Master القديم، فهذا يعني أنه لم يعدله يدوياً
            bool wasUnmodified = true;
            if (oldMaster != null) {
              if (existing.startTime != oldMaster.startTime || existing.endTime != oldMaster.endTime) {
                wasUnmodified = false; 
              }
            }
            
            if (wasUnmodified) {
              // تحديث اليوم بوقت الـ Master الجديد
              newShifts.add(Shift(
                  name: ms.name,
                  startTime: ms.startTime,
                  endTime: ms.endTime));
            } else {
              // الاحتفاظ بالتعديل اليدوي الخاص باليوم
              newShifts.add(Shift(
                  name: existing.name,
                  startTime: existing.startTime,
                  endTime: existing.endTime));
            }
          } else {
            // وردية جديدة تضاف
            newShifts.add(Shift(
                name: ms.name,
                startTime: ms.startTime,
                endTime: ms.endTime));
          }
        }

        schedule.shifts = newShifts;
        schedule.shiftNames = newShifts.map((e) => e.name).toList();
        if (newShifts.isNotEmpty) {
          schedule.shiftStart = newShifts.first.startTime;
          schedule.shiftEnd = newShifts.first.endTime;
        } else {
          schedule.shiftStart = '08:00 AM';
          schedule.shiftEnd = '04:00 PM';
        }
        await schedule.save();
        _upsertToSupabase(schedule); // عدم انتظار الرفع للسحاب لعدم تجميد الواجهة
      }
    }
  }

  // ─── رفع صف يوم واحد إلى Supabase (upsert) ─────────────────────────────
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
        'shifts': schedule.shifts?.map((e) => e.toJson()).toList(),
        'shift_names': schedule.shiftNames,
      };
      await Supabase.instance.client
          .from('factory_schedule')
          .upsert(payload, onConflict: 'day_name');
      debugPrint(
          '✅ [factory_schedule] تم رفع ${schedule.dayName} إلى Supabase.');
    } catch (e) {
      debugPrint('❌ [factory_schedule] فشل الرفع: $e');
    }
  }

  // ─── فرض الورديات الأساسية على كل الأيام ──────────────────────────────
  Future<void> _forceMasterShiftsToAllDays(
      BuildContext context,
      List<Shift> masterShifts,
      Box<DaySchedule> scheduleBox) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد'),
        content: const Text(
            'هل أنت متأكد من فرض أوقات الورديات الأساسية على جميع أيام الأسبوع؟ سيؤدي هذا إلى مسح أي استثناءات قمت بتخصيصها للأيام يدوياً.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('تطبيق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (var dayName in DaySchedule.orderedDays) {
      final schedule = scheduleBox.get(dayName);
      if (schedule != null) {
        final newShifts = <Shift>[];
        for (var ms in masterShifts) {
          newShifts.add(Shift(
              name: ms.name, startTime: ms.startTime, endTime: ms.endTime));
        }

        schedule.shifts = newShifts;
        schedule.shiftNames = newShifts.map((e) => e.name).toList();
        if (newShifts.isNotEmpty) {
          schedule.shiftStart = newShifts.first.startTime;
          schedule.shiftEnd = newShifts.first.endTime;
        } else {
          schedule.shiftStart = '08:00 AM';
          schedule.shiftEnd = '04:00 PM';
        }
        await schedule.save();
        _upsertToSupabase(schedule);
      }
    }
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تطبيق الورديات على جميع الأيام بنجاح.')),
      );
    }
  }
}

// ─── صف يوم واحد (مع الاستثناءات) ────────────────────────────────────────────
class _DayRow extends StatelessWidget {
  final DaySchedule schedule;
  final bool isAdmin;
  final ValueChanged<bool> onToggleWorkDay;
  final VoidCallback onSave;

  const _DayRow({
    required this.schedule,
    required this.isAdmin,
    required this.onToggleWorkDay,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isOff = !schedule.isWorkingDay;
    final disabledColor = Colors.grey.shade400;
    final currentShifts = schedule.shifts ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
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
              Transform.scale(
                scale: 0.80,
                child: Switch(
                  value: schedule.isWorkingDay,
                  onChanged: isAdmin ? onToggleWorkDay : null,
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
              ]
            ],
          ),
        ),
        if (!isOff)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Column(
              children: currentShifts
                  .map((shift) => _buildShiftItem(context, shift, currentShifts))
                  .toList(),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildShiftItem(
      BuildContext context, Shift shift, List<Shift> allShifts) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              flex: 3,
              child: Text(shift.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 4),
          Expanded(
              flex: 4,
              child: _TimeChip(
                label: 'بداية',
                value: shift.startTime,
                enabled: isAdmin,
                onTap: () => _pickTimeForShift(context, shift, true, allShifts),
              )),
          const SizedBox(width: 6),
          const Text('→', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 6),
          Expanded(
              flex: 4,
              child: _TimeChip(
                label: 'نهاية',
                value: shift.endTime,
                enabled: isAdmin,
                onTap: () => _pickTimeForShift(context, shift, false, allShifts),
              )),
        ]));
  }

  Future<void> _pickTimeForShift(BuildContext context, Shift shift,
      bool isStart, List<Shift> allShifts) async {
    final current = FactoryScheduleCard._parseTime(
        isStart ? shift.startTime : shift.endTime);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;

    if (isStart) {
      shift.startTime = FactoryScheduleCard._fmtTime(picked);
    } else {
      shift.endTime = FactoryScheduleCard._fmtTime(picked);
    }
    
    schedule.shifts = allShifts;
    if (allShifts.isNotEmpty) {
      schedule.shiftStart = allShifts.first.startTime;
      schedule.shiftEnd = allShifts.first.endTime;
    }
    onSave();
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
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
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
