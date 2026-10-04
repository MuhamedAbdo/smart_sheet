// lib/controllers/worker_leave_controller.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/worker_details_screen.dart';

/// خيارات التعامل مع تأخر العامل عن العودة من الإجازة المجدولة
enum OverdueLeaveAction {
  /// تمديد الإجازة: (احتساب أيام التأخير كإجازة اعتيادية ممتدة).
  extendLeave,

  /// غياب بدون إذن: (احتساب مدة الإجازة الأصلية كإجازة، واحتساب أيام التأخير فقط كغياب).
  absenceWithoutPermission,

  /// تحويل كامل المدة إلى غياب: (إلغاء الإجازة واحتساب المدة من يوم المغادرة حتى اليوم كغياب).
  convertAllToAbsence,
}

/// متحكم منطق الأعمال (Business Logic Controller) الخاص بإجازات العمال وتأخر العودة
class WorkerLeaveController {
  /// التحقق مما إذا كان العامل متأخراً عن موعد العودة المتوقع
  static bool isOverdue(WorkerAction action, [DateTime? currentDate]) {
    final erd = action.expectedReturnDate;
    if (erd == null || action.returnDate != null) return false;
    final now = currentDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expectedDay = DateTime(erd.year, erd.month, erd.day);
    return today.isAfter(expectedDay);
  }

  /// احتساب عدد أيام التأخير عن موعد العودة المتوقع
  static int calculateDelayDays(WorkerAction action, [DateTime? currentDate]) {
    final erd = action.expectedReturnDate;
    if (erd == null) return 0;
    final now = currentDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expectedDay = DateTime(erd.year, erd.month, erd.day);
    final diff = today.difference(expectedDay).inDays;
    return diff > 0 ? diff : 0;
  }

  /// تسجيل العودة الطبيعية والصامتة (عندما لا يوجد تأخير: اليوم <= العودة المتوقعة)
  static Future<void> processNormalReturn({
    required Worker worker,
    required WorkerAction action,
    DateTime? returnDate,
    TimeOfDay? returnTime,
    ThemeProvider? themeProvider,
  }) async {
    final now = DateTime.now();
    final finalReturnDate =
        returnDate ?? DateTime(now.year, now.month, now.day);
    final finalReturnTime =
        returnTime ?? TimeOfDay(hour: now.hour, minute: now.minute);

    final shiftStart = themeProvider != null
        ? ShiftTimeCalculator.getShiftStartForAction(
            action.shiftName, action.date, themeProvider, action.startTime)
        : const TimeOfDay(hour: 8, minute: 0);

    final shiftEnd = themeProvider != null
        ? ShiftTimeCalculator.getShiftEndForAction(
            action.shiftName, action.date, themeProvider, action.startTime)
        : const TimeOfDay(hour: 17, minute: 0);

    final days = WorkingDayCalculator.calculateExactAbsenceDays(
      action.date,
      action.startTime,
      finalReturnDate,
      finalReturnTime,
      shiftStart,
      shiftEnd,
    );

    action.returnDate = finalReturnDate;
    action.days = days > 0 ? days : 1.0;
    action.endTimeHour = finalReturnTime.hour;
    action.endTimeMinute = finalReturnTime.minute;

    final factoryId = await SupabaseManager.getFactoryId();
    action.factoryId = factoryId ?? action.factoryId;

    if (action.isInBox) {
      await action.save();
    }
    await worker.save();

    final actionData = action.toJson();
    actionData['factory_id'] = factoryId;
    SyncService.instance.pushToQueue('worker_actions', actionData);
  }

  /// معالجة عودة العامل المتأخر بناءً على القرار الإداري للمسؤول
  static Future<void> processOverdueReturn({
    required Worker worker,
    required WorkerAction action,
    required OverdueLeaveAction decision,
    DateTime? returnDate,
    TimeOfDay? returnTime,
    ThemeProvider? themeProvider,
  }) async {
    final now = DateTime.now();
    final finalReturnDate =
        returnDate ?? DateTime(now.year, now.month, now.day);
    final finalReturnTime =
        returnTime ?? TimeOfDay(hour: now.hour, minute: now.minute);
    final delayDays = calculateDelayDays(action, finalReturnDate);

    final shiftStart = themeProvider != null
        ? ShiftTimeCalculator.getShiftStartForAction(
            action.shiftName, action.date, themeProvider, action.startTime)
        : const TimeOfDay(hour: 8, minute: 0);

    final shiftEnd = themeProvider != null
        ? ShiftTimeCalculator.getShiftEndForAction(
            action.shiftName, action.date, themeProvider, action.startTime)
        : const TimeOfDay(hour: 17, minute: 0);

    final factoryId = await SupabaseManager.getFactoryId();

    switch (decision) {
      case OverdueLeaveAction.extendLeave:
        // 1. تمديد الإجازة: (احتساب أيام التأخير كإجازة اعتيادية ممتدة)
        final totalDays = WorkingDayCalculator.calculateExactAbsenceDays(
          action.date,
          action.startTime,
          finalReturnDate,
          finalReturnTime,
          shiftStart,
          shiftEnd,
        );

        action.returnDate = finalReturnDate;
        action.days = totalDays > 0 ? totalDays : 1.0;
        action.endTimeHour = finalReturnTime.hour;
        action.endTimeMinute = finalReturnTime.minute;
        action.factoryId = factoryId ?? action.factoryId;

        final extensionNote = 'تم تمديد الإجازة $delayDays أيام تأخير';
        action.notes = (action.notes != null && action.notes!.isNotEmpty)
            ? '${action.notes} ($extensionNote)'
            : extensionNote;

        if (action.isInBox) {
          await action.save();
        }
        await worker.save();

        final actionData = action.toJson();
        actionData['factory_id'] = factoryId;
        SyncService.instance.pushToQueue('worker_actions', actionData);
        break;

      case OverdueLeaveAction.absenceWithoutPermission:
        // 2. غياب بدون إذن: (احتساب مدة الإجازة الأصلية كإجازة، واحتساب أيام التأخير فقط كغياب)
        final erd = action.expectedReturnDate ?? finalReturnDate;

        // أ) إنهاء الإجازة الأصلية عند موعد العودة المتوقع
        final leaveDays = WorkingDayCalculator.calculateExactAbsenceDays(
          action.date,
          action.startTime,
          erd,
          shiftEnd,
          shiftStart,
          shiftEnd,
        );

        action.returnDate = erd;
        action.days = leaveDays > 0 ? leaveDays : 1.0;
        action.endTimeHour = shiftEnd.hour;
        action.endTimeMinute = shiftEnd.minute;
        action.factoryId = factoryId ?? action.factoryId;

        if (action.isInBox) {
          await action.save();
        }

        final leaveData = action.toJson();
        leaveData['factory_id'] = factoryId;
        SyncService.instance.pushToQueue('worker_actions', leaveData);

        // ب) إنشاء حركة غياب جديدة لأيام التأخير فقط وتكون منتهية بالعودة اليوم
        final delayAbsenceDays = WorkingDayCalculator.calculateExactAbsenceDays(
          erd,
          shiftStart,
          finalReturnDate,
          finalReturnTime,
          shiftStart,
          shiftEnd,
        );

        final absenceAction = WorkerAction(
          type: 'غياب',
          days: delayAbsenceDays > 0 ? delayAbsenceDays : delayDays.toDouble(),
          date: erd,
          returnDate: finalReturnDate,
          startTimeHour: shiftStart.hour,
          startTimeMinute: shiftStart.minute,
          endTimeHour: finalReturnTime.hour,
          endTimeMinute: finalReturnTime.minute,
          notes:
              'غياب بدون إذن (تأخر عن العودة من الإجازة بمقدار $delayDays أيام)',
          workerName: worker.name,
          workerId: worker.id,
          factoryId: factoryId ?? worker.factoryId,
          shiftName: action.shiftName,
        );

        final actionBox = Hive.isBoxOpen('worker_actions')
            ? Hive.box<WorkerAction>('worker_actions')
            : await Hive.openBox<WorkerAction>('worker_actions');

        await actionBox.put(absenceAction.id, absenceAction);
        final savedAbsence = actionBox.get(absenceAction.id);
        if (savedAbsence != null) {
          worker.actions.add(savedAbsence);
        }
        await worker.save();

        final newAbsenceData = absenceAction.toJson();
        newAbsenceData['factory_id'] = factoryId;
        SyncService.instance.pushToQueue('worker_actions', newAbsenceData);
        break;

      case OverdueLeaveAction.convertAllToAbsence:
        // 3. تحويل كامل المدة إلى غياب: (إلغاء الإجازة واحتساب المدة من يوم المغادرة حتى اليوم كغياب)
        final totalAbsenceDays = WorkingDayCalculator.calculateExactAbsenceDays(
          action.date,
          action.startTime,
          finalReturnDate,
          finalReturnTime,
          shiftStart,
          shiftEnd,
        );

        action.type = 'غياب';
        action.returnDate = finalReturnDate;
        action.days = totalAbsenceDays > 0 ? totalAbsenceDays : 1.0;
        action.endTimeHour = finalReturnTime.hour;
        action.endTimeMinute = finalReturnTime.minute;
        action.factoryId = factoryId ?? action.factoryId;

        final convertNote =
            'تم إلغاء الإجازة وتحويل كامل المدة إلى غياب لتأخر $delayDays أيام عن العودة';
        action.notes = (action.notes != null && action.notes!.isNotEmpty)
            ? '${action.notes} ($convertNote)'
            : convertNote;

        if (action.isInBox) {
          await action.save();
        }
        await worker.save();

        final convertedData = action.toJson();
        convertedData['factory_id'] = factoryId;
        SyncService.instance.pushToQueue('worker_actions', convertedData);
        break;
    }
  }
}
