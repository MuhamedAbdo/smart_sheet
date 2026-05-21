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

  const ActiveAbsenceCard({
    super.key,
    required this.worker,
    required this.action,
    required this.onRefresh,
    this.onEdit,
  });

  int get elapsedDays {
    final now = DateTime.now();
    final start = action.date;
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(start.year, start.month, start.day);
    return today.difference(startDate).inDays;
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

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    primaryColor.withValues(alpha: 0.3),
                    primaryColor.withValues(alpha: 0.1)
                  ]
                : [primaryColor.withValues(alpha: 0.05), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                const SizedBox(width: 8),
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
                _buildInfoColumn(
                    isTimeBased ? "وقت الخروج" : "بدأ في",
                    isTimeBased
                        ? (action.startTime?.format(context) ?? "--")
                        : _formatDate(action.date)),
                _buildInfoColumn(
                    "المدة", isTimeBased ? "قيد التنفيذ" : "$elapsedDays يوم"),
              ],
            ),
            const Spacer(),
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
                  isTimeBased
                      ? _showTimeReturnDialog(context)
                      : _showReturnDialog(context);
                },
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text("تسجيل العودة ✅",
                    style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
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

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  Future<void> _showReturnDialog(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime start = action.date;
    final DateTime initialReturnDate = DateTime(now.year, now.month, now.day);

    final returnDateNotifier = ValueNotifier<DateTime>(initialReturnDate);

    // Get theme provider for default return time (shift start)
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final defaultReturnTime =
        ShiftTimeCalculator.getDefaultReturnTime(themeProvider);
    final returnTimeNotifier = ValueNotifier<TimeOfDay>(defaultReturnTime);

    double calcDays() {
      final startDate = DateTime(start.year, start.month, start.day);
      final rDate = DateTime(returnDateNotifier.value.year,
          returnDateNotifier.value.month, returnDateNotifier.value.day);

      // Use smart calculation with time consideration
      final shiftStart = themeProvider.shiftStart;
      final shiftEnd = themeProvider.shiftEnd;
      final shiftDuration =
          ShiftTimeCalculator.calculateShiftDuration(shiftStart, shiftEnd);

      final actionDuration = ShiftTimeCalculator.calculateActionDuration(
        start,
        action.startTime, // Use existing start time if available
        returnDateNotifier.value,
        returnTimeNotifier.value,
        shiftStart,
        shiftEnd,
      );

      if (actionDuration <= 0) {
        return rDate.difference(startDate).inDays.toDouble();
      }

      return ShiftTimeCalculator.calculateDaysWithSmart50Rule(
        actionDuration,
        shiftDuration,
      );
    }

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
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_turned_in, color: Colors.green),
                          SizedBox(width: 10),
                          Text("تسجيل عودة",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("تاريخ العودة",
                            style: TextStyle(fontSize: 14)),
                        subtitle: Text(_formatDate(returnDateNotifier.value),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.calendar_month,
                            color: Colors.blue),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: returnDateNotifier.value,
                            firstDate: action.date,
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              returnDateNotifier.value = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("وقت العودة",
                            style: TextStyle(fontSize: 14)),
                        subtitle: Text(returnTimeNotifier.value.format(context),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing:
                            const Icon(Icons.access_time, color: Colors.green),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: returnTimeNotifier.value,
                          );
                          if (picked != null) {
                            setState(() {
                              returnTimeNotifier.value = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ValueListenableBuilder<DateTime>(
                          valueListenable: returnDateNotifier,
                          builder: (context, returnDate, _) {
                            return ValueListenableBuilder<TimeOfDay>(
                              valueListenable: returnTimeNotifier,
                              builder: (context, returnTime, _) {
                                final days = calcDays();
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.calculate_outlined,
                                            color: Colors.grey, size: 20),
                                        SizedBox(width: 12),
                                        Text("عدد الأيام المحسوب:",
                                            style:
                                                TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                    Text(
                                      "${days.toStringAsFixed(1)} يوم",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
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

                                final finalDays = calcDays();

                                action.returnDate = returnDateNotifier.value;
                                action.days = finalDays;
                                action.endTimeHour =
                                    returnTimeNotifier.value.hour;
                                action.endTimeMinute =
                                    returnTimeNotifier.value.minute;

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
                                    message:
                                        "تم تسجيل عودة ${worker.name} (${action.type}) بنجاح",
                                    backgroundColor: Colors.green,
                                    icon: Icons.check_circle,
                                  );
                                }
                              },
                              child: const Text("✅ تأكيد وحفظ"),
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
