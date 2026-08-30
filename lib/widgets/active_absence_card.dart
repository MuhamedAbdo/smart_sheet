import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/worker_details_screen.dart';

class ActiveAbsenceCard extends StatelessWidget {
  final Worker worker;
  final WorkerAction action;
  final VoidCallback onRefresh;
  final VoidCallback? onEdit;
  final bool showEditButton;
  final bool showDeleteButton;

  const ActiveAbsenceCard({
    super.key,
    required this.worker,
    required this.action,
    required this.onRefresh,
    this.onEdit,
    this.showEditButton = true,
    this.showDeleteButton = true,
  });

  /// عدد أيام العمل الفعلية المنقضية من تاريخ القيام حتى الآن
  /// يستخدم WorkingDayCalculator لاستبعاد أيام الراحة
  double get elapsedWorkingDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(action.date.year, action.date.month, action.date.day);

    // إذا لم يبدأ بعد أو نفس اليوم → 0
    if (!startDay.isBefore(today)) return 0.0;

    // حساب الأيام باستخدام WorkingDayCalculator
    return WorkingDayCalculator.calculateExactAbsenceDays(
      startDay,
      action.startTime,
      today,
      null, // حتى نهاية اليوم الحالي
      const TimeOfDay(hour: 8, minute: 0),
      const TimeOfDay(hour: 17, minute: 0),
    );
  }

  /// هل تأخر العامل عن موعد العودة المتوقع؟
  bool get isOverdue {
    final erd = action.expectedReturnDate;
    if (erd == null || action.returnDate != null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expectedDay = DateTime(erd.year, erd.month, erd.day);
    return today.isAfter(expectedDay);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isTimeBased = action.type == 'إذن' || action.type == 'تأمين صحي';

    final Color primaryColor = switch (action.type) {
      'غياب' => Colors.red,
      'إذن' => Colors.blue,
      'تأمين صحي' => Colors.purple,
      'إجازة' => Colors.orange,
      'أجازة عارضة' => Colors.amber.shade700,
      _ => Colors.teal,
    };

    // لون الإطار الخارجي: أحمر عند التأخر، طبيعي عند عدمه
    final Color borderColor = isOverdue ? Colors.red.shade600 : primaryColor.withValues(alpha: 0.3);
    final double borderWidth = isOverdue ? 2.0 : 1.0;

    // حساب المدة المعروضة
    final double elapsed = elapsedWorkingDays;
    final String durationText = isTimeBased
        ? "قيد التنفيذ"
        : (elapsed == 0 ? "اليوم" : "${elapsed % 1 == 0 ? elapsed.toInt() : elapsed} يوم");

    return Card(
      elevation: isOverdue ? 8 : 6,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    isOverdue
                        ? Colors.red.withValues(alpha: 0.25)
                        : primaryColor.withValues(alpha: 0.3),
                    primaryColor.withValues(alpha: 0.1)
                  ]
                : [
                    isOverdue
                        ? Colors.red.withValues(alpha: 0.06)
                        : primaryColor.withValues(alpha: 0.05),
                    Colors.white
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شارة "تأخر عن العودة"
            if (isOverdue)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      "⚠️ تأخر عن العودة",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.2),
                  radius: 18,
                  child: Icon(_getIcon(), color: primaryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        action.type,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (showEditButton)
                  IconButton(
                    onPressed: () {
                      // 🔑 فحص حماية للمزامنة الخارجية عند التعديل
                      if (action.box == null || !action.isInBox) {
                        _showSyncWarning(context);
                        return;
                      }
                      if (onEdit != null) onEdit!();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      foregroundColor: Colors.blue,
                    ),
                    tooltip: 'تعديل الإجراء',
                  ),
                if (showEditButton && showDeleteButton)
                  const SizedBox(width: 8),
                if (showDeleteButton)
                  IconButton(
                    onPressed: () {
                      // 🔑 فحص حماية للمزامنة الخارجية عند الإلغاء المحلي
                      if (action.box == null || !action.isInBox) {
                        _showSyncWarning(context);
                        return;
                      }
                      _showDeleteConfirmation(context);
                    },
                    icon: const Icon(Icons.delete_outline, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      foregroundColor: Colors.red,
                    ),
                    tooltip: 'إلغاء الإجراء',
                  ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (action.shiftName != null && action.shiftName!.isNotEmpty)
                  _buildInfoColumn("الوردية", action.shiftName!),
                _buildInfoColumn(
                    isTimeBased ? "وقت الخروج" : "بدأ في",
                    isTimeBased
                        ? (action.startTime?.format(context) ?? "--")
                        : _formatDate(action.date)),
                _buildInfoColumn("المدة حتى الآن", durationText),
                if (action.expectedReturnDate != null)
                  _buildInfoColumn(
                    "العودة المتوقعة",
                    _formatDate(action.expectedReturnDate!),
                    valueColor: isOverdue ? Colors.red.shade700 : null,
                  ),
              ],
            ),
            const Spacer(),
            if (showEditButton)
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 🔑 حماية صخرية: منع التفاعل إذا تم إلغاء الإجراء سلفاً من جهاز آخر
                    if (action.box == null || !action.isInBox) {
                      _showSyncWarning(context);
                      return;
                    }
                    // زر تسجيل العودة يفتح دائماً مربع تأكيد (سواء time-based أو full-day)
                    isTimeBased
                        ? _showTimeReturnDialog(context)
                        : _showReturnConfirmDialog(context);
                  },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text("تسجيل العودة ✅",
                      style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOverdue ? Colors.red.shade600 : primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (action.type) {
      case 'إذن':
        return Icons.access_time;
      case 'تأمين صحي':
        return Icons.medical_services_outlined;
      case 'إجازة':
        return Icons.beach_access;
      case 'أجازة عارضة':
        return Icons.wb_sunny;
      default:
        return Icons.person_off;
    }
  }

  Widget _buildInfoColumn(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _showSyncWarning(BuildContext context) {
    UIUtils.showInfoSnackBar(
      message: "تنبيه: تم إلغاء أو تعديل هذا الإجراء من جهاز آخر!",
      backgroundColor: Colors.orange.shade800,
      icon: Icons.sync_problem,
    );
    onRefresh(); // تحديث فوري للشاشة لإخفاء الكارت الذي حُذف محلياً بكاش المزامنة
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "إلغاء الإجراء",
      content:
          "هل أنت متأكد من إلغاء ${action.type} لـ ${worker.name}؟ سيتم حذف الإجراء بالكامل.",
      onConfirm: () async {
        // فحص إضافي للتأكيد التام قبل البدء في عمليات الحذف
        if (action.box == null || !action.isInBox) {
          onRefresh();
          return;
        }

        final factoryId = await SupabaseManager.getFactoryId();

        // 1. Take a copy of the data before deletion from Hive
        final actionJson = action.toJson();
        actionJson['factory_id'] = factoryId;

        // 2. Local deletion from Flutter and Hive
        worker.actions.remove(action);
        await worker.save();
        if (action.isInBox) {
          await action.delete();
        }

        // 3. Send delete command to the central sync queue to upload to Supabase
        SyncService.instance.pushToQueue(
          'worker_actions',
          actionJson,
          operation: 'delete',
        );

        onRefresh();

        if (context.mounted) {
          UIUtils.showInfoSnackBar(
            message: "تم إلغاء ${action.type} بنجاح",
            backgroundColor: Colors.red,
            icon: Icons.delete_outline,
          );
        }
      },
    );
  }

  /// مربع حوار تسجيل العودة الرئيسي (للإجازات الكاملة)
  /// يطلب تأكيد تاريخ ووقت العودة الفعلي — افتراضياً الآن
  Future<void> _showReturnConfirmDialog(BuildContext context) async {
    final now = DateTime.now();
    final DateTime start = action.date;

    // القيم الافتراضية: الآن
    final returnDateNotifier = ValueNotifier<DateTime>(
      DateTime(now.year, now.month, now.day),
    );

    // Get theme provider for default return time
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    // استخدام الوقت الحالي كافتراضي لتسهيل نسيان التسجيل
    final returnTimeNotifier = ValueNotifier<TimeOfDay>(
      TimeOfDay(hour: now.hour, minute: now.minute),
    );

    double calcDays() {
      return WorkingDayCalculator.calculateExactAbsenceDays(
        start,
        action.startTime,
        returnDateNotifier.value,
        returnTimeNotifier.value,
        ShiftTimeCalculator.getShiftStartForAction(
            action.shiftName, action.date, themeProvider, action.startTime),
        ShiftTimeCalculator.getShiftEndForAction(
            action.shiftName, action.date, themeProvider, action.startTime),
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.assignment_turned_in, color: Colors.green, size: 26),
                SizedBox(width: 10),
                Text("تأكيد تسجيل العودة",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "العامل: ${worker.name}   |   ${action.type}",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  Text(
                    "تاريخ القيام: ${_formatDate(start)}",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // تاريخ العودة الفعلي
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("📅 تاريخ العودة الفعلي",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _formatDate(returnDateNotifier.value),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    trailing: const Icon(Icons.calendar_month, color: Colors.blue),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: returnDateNotifier.value,
                        firstDate: start,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => returnDateNotifier.value = picked);
                      }
                    },
                  ),

                  // وقت العودة الفعلي
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("⏰ وقت العودة الفعلي",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: ValueListenableBuilder<TimeOfDay>(
                      valueListenable: returnTimeNotifier,
                      builder: (context, t, _) => Text(
                        t.format(context),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    trailing: const Icon(Icons.access_time, color: Colors.green),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: returnTimeNotifier.value,
                      );
                      if (picked != null) {
                        setState(() => returnTimeNotifier.value = picked);
                      }
                    },
                  ),

                  const Divider(),
                  // ملخص الأيام المحسوبة
                  ValueListenableBuilder<DateTime>(
                    valueListenable: returnDateNotifier,
                    builder: (context, _, __) => ValueListenableBuilder<TimeOfDay>(
                      valueListenable: returnTimeNotifier,
                      builder: (context, _, __) {
                        final days = calcDays();
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.calculate_outlined,
                                      color: Colors.green, size: 20),
                                  SizedBox(width: 8),
                                  Text("عدد الأيام المحسوب:",
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                              Text(
                                "$days يوم",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("❌ إلغاء"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  // 🔑 حماية لمنع الـ Crash إذا حذف الإجراء مستخدم آخر أثناء فتح الـ dialog
                  if (action.box == null || !action.isInBox) {
                    if (context.mounted) Navigator.pop(context);
                    _showSyncWarning(context);
                    return;
                  }

                  final finalDays = calcDays();

                  action.returnDate = returnDateNotifier.value;
                  action.days = finalDays;
                  action.endTimeHour = returnTimeNotifier.value.hour;
                  action.endTimeMinute = returnTimeNotifier.value.minute;

                  final factoryId = await SupabaseManager.getFactoryId();
                  action.factoryId = factoryId ?? action.factoryId;

                  await action.save();
                  await worker.save();

                  final actionData = action.toJson();
                  actionData['factory_id'] = factoryId;
                  SyncService.instance.pushToQueue('worker_actions', actionData);

                  if (context.mounted) Navigator.pop(context);
                  onRefresh();

                  if (context.mounted) {
                    UIUtils.showInfoSnackBar(
                      message: "تم تسجيل عودة ${worker.name} بنجاح ✅",
                      backgroundColor: Colors.green,
                      icon: Icons.check_circle,
                    );
                  }
                },
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text("✅ تأكيد وحفظ"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showTimeReturnDialog(BuildContext context) async {
    final dateNotifier = ValueNotifier<DateTime>(action.date);
    final returnDateNotifier =
        ValueNotifier<DateTime>(action.returnDate ?? DateTime.now());
    final startTimeNotifier =
        ValueNotifier<TimeOfDay>(action.startTime ?? TimeOfDay.now());
    final endTimeNotifier =
        ValueNotifier<TimeOfDay>(action.endTime ?? TimeOfDay.now());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    children: [
                      Text(
                        "تعديل ${action.type}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("تاريخ الذهاب",
                            style: TextStyle(fontSize: 14)),
                        subtitle: Text(_formatDate(dateNotifier.value),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.calendar_month,
                            color: Colors.blue),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dateNotifier.value,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => dateNotifier.value = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("وقت الذهاب",
                            style: TextStyle(fontSize: 14)),
                        subtitle: Text(startTimeNotifier.value.format(context),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing:
                            const Icon(Icons.access_time, color: Colors.blue),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startTimeNotifier.value,
                          );
                          if (picked != null) {
                            setState(() => startTimeNotifier.value = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("تاريخ العودة",
                            style: TextStyle(fontSize: 14)),
                        subtitle: Text(_formatDate(returnDateNotifier.value),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.calendar_month,
                            color: Colors.green),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: returnDateNotifier.value,
                            firstDate: dateNotifier.value,
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => returnDateNotifier.value = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("وقت العودة",
                            style: TextStyle(fontSize: 14)),
                        subtitle: Text(endTimeNotifier.value.format(context),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing:
                            const Icon(Icons.access_time, color: Colors.green),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: endTimeNotifier.value,
                          );
                          if (picked != null) {
                            setState(() => endTimeNotifier.value = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("❌ إلغاء"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                // 🔑 حماية لمنع الـ Crash إذا حذف الإجراء مستخدم آخر أثناء فتح الـ BottomSheet
                                if (action.box == null || !action.isInBox) {
                                  if (context.mounted) Navigator.pop(context);
                                  _showSyncWarning(context);
                                  return;
                                }

                                action.date = dateNotifier.value;
                                action.returnDate = returnDateNotifier.value;
                                action.startTimeHour =
                                    startTimeNotifier.value.hour;
                                action.startTimeMinute =
                                    startTimeNotifier.value.minute;
                                action.endTimeHour = endTimeNotifier.value.hour;
                                action.endTimeMinute =
                                    endTimeNotifier.value.minute;

                                final factoryId =
                                    await SupabaseManager.getFactoryId();
                                action.factoryId =
                                    factoryId ?? action.factoryId;

                                await action.save();
                                await worker.save();

                                final actionData = action.toJson();
                                actionData['factory_id'] = factoryId;
                                SyncService.instance
                                    .pushToQueue('worker_actions', actionData);

                                if (context.mounted) Navigator.pop(context);
                                onRefresh();

                                if (context.mounted) {
                                  UIUtils.showInfoSnackBar(
                                    message: "تم تحديث ${action.type} بنجاح",
                                    backgroundColor: Colors.green,
                                    icon: Icons.check_circle,
                                  );
                                }
                              },
                              child: const Text("✅ حفظ التعديلات"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
