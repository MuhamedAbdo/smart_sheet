import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../models/worker_action_model.dart';
import '../../models/worker_model.dart';
import '../../widgets/worker_action_card.dart';
import '../../widgets/active_absence_card.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/models/day_schedule.dart';

/// Helper class for factory shift-based time calculations
class ShiftTimeCalculator {
  /// Calculate total shift duration in hours
  static double calculateShiftDuration(
      TimeOfDay shiftStart, TimeOfDay shiftEnd) {
    double shiftHours = shiftEnd.hour +
        shiftEnd.minute / 60.0 -
        (shiftStart.hour + shiftStart.minute / 60.0);
    if (shiftHours <= 0) shiftHours += 24;
    return shiftHours;
  }

  /// Calculate action duration in hours between departure and return times
  static double calculateActionDuration(
    DateTime departureDate,
    TimeOfDay? departureTime,
    DateTime? returnDate,
    TimeOfDay? returnTime,
    TimeOfDay defaultShiftStart,
    TimeOfDay defaultShiftEnd,
  ) {
    final depHour = departureTime?.hour ?? defaultShiftStart.hour;
    final depMinute = departureTime?.minute ?? defaultShiftStart.minute;

    final retHour = returnTime?.hour ?? defaultShiftEnd.hour;
    final retMinute = returnTime?.minute ?? defaultShiftEnd.minute;

    final startDateTime = DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
      depHour,
      depMinute,
    );

    final endBaseDate = returnDate ?? departureDate;
    final endDateTime = DateTime(
      endBaseDate.year,
      endBaseDate.month,
      endBaseDate.day,
      retHour,
      retMinute,
    );

    final diffMinutes = endDateTime.difference(startDateTime).inMinutes;
    if (diffMinutes <= 0) return 0.0;

    return diffMinutes / 60.0;
  }

  /// Smart 50% day calculation with +/- 1 hour margin
  /// Returns the calculated days with proper fractional day adjustment
  static double calculateDaysWithSmart50Rule(
    double actionDurationHours,
    double shiftDurationHours,
  ) {
    final totalHours = actionDurationHours;
    final fullDays = (totalHours / 24).floor();
    final remainingHours = totalHours % 24;

    // Calculate 50% threshold with +/- 1 hour margin
    final halfShift = shiftDurationHours / 2;
    final lowerMargin = halfShift - 1.0;
    final upperMargin = halfShift + 1.0;

    double partialDay = 0.0;

    // Full day threshold (within 1 hour of full shift)
    if (remainingHours >= shiftDurationHours - 1.0) {
      partialDay = 1.0;
    }
    // 50% rule: within +/- 1 hour of half shift
    else if (remainingHours >= lowerMargin && remainingHours <= upperMargin) {
      partialDay = 0.5;
    }
    // More than 50% but less than full day
    else if (remainingHours > upperMargin) {
      partialDay = 0.5;
    }
    // Less than 50% threshold
    else {
      partialDay = 0.0;
    }

    return fullDays + partialDay;
  }

  /// Get default departure time (shift start)
  static TimeOfDay getDefaultDepartureTime(ThemeProvider themeProvider) {
    return themeProvider.shiftStart;
  }

  /// Get default return time for ending a live session (shift start)
  static TimeOfDay getDefaultReturnTime(ThemeProvider themeProvider) {
    return themeProvider.shiftStart;
  }

  /// Get shift start time for a specific action, falling back to default if not found
  static TimeOfDay getShiftStartForAction(String? shiftName, DateTime date, ThemeProvider themeProvider, [TimeOfDay? actionStartTime]) {
    if (shiftName == null && actionStartTime != null) {
      shiftName = _guessShiftNameFromTime(actionStartTime, date);
    }
    if (shiftName == null || !Hive.isBoxOpen('factory_schedule')) {
      return themeProvider.shiftStart;
    }
    
    return _parseShiftTime(shiftName, date, true, themeProvider.shiftStart);
  }

  /// Get shift end time for a specific action, falling back to default if not found
  static TimeOfDay getShiftEndForAction(String? shiftName, DateTime date, ThemeProvider themeProvider, [TimeOfDay? actionStartTime]) {
    if (shiftName == null && actionStartTime != null) {
      shiftName = _guessShiftNameFromTime(actionStartTime, date);
    }
    if (shiftName == null || !Hive.isBoxOpen('factory_schedule')) {
      return themeProvider.shiftEnd;
    }
    
    return _parseShiftTime(shiftName, date, false, themeProvider.shiftEnd);
  }

  static String? _guessShiftNameFromTime(TimeOfDay time, DateTime date) {
    if (!Hive.isBoxOpen('factory_schedule')) return null;
    const map = {
      1: 'Monday', 2: 'Tuesday', 3: 'Wednesday',
      4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday',
    };
    final dayName = map[date.weekday] ?? 'Monday';
    final schedule = Hive.box<DaySchedule>('factory_schedule').get(dayName);
    if (schedule != null && schedule.shifts != null) {
      for (var shift in schedule.shifts!) {
        try {
          final parts = shift.startTime.split(' ');
          final timeParts = parts[0].split(':');
          int hour = int.parse(timeParts[0]);
          final int minute = int.parse(timeParts[1]);
          if (parts.length > 1) {
            final ampm = parts[1].toLowerCase();
            if (ampm == 'pm' && hour < 12) hour += 12;
            if (ampm == 'am' && hour == 12) hour = 0;
          }
          if (hour == time.hour && (minute - time.minute).abs() <= 30) {
            return shift.name;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  static TimeOfDay _parseShiftTime(String shiftName, DateTime date, bool isStart, TimeOfDay fallback) {
    const map = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    final dayName = map[date.weekday] ?? 'Monday';
    final schedule = Hive.box<DaySchedule>('factory_schedule').get(dayName);
    
    if (schedule != null && schedule.shifts != null) {
      try {
        final shift = schedule.shifts!.firstWhere((s) => s.name == shiftName);
        final timeString = isStart ? shift.startTime : shift.endTime;
        final parts = timeString.split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final int minute = int.parse(timeParts[1]);
        if (parts.length > 1) {
          final ampm = parts[1].toLowerCase();
          if (ampm == 'pm' && hour < 12) hour += 12;
          if (ampm == 'am' && hour == 12) hour = 0;
        }
        return TimeOfDay(hour: hour, minute: minute);
      } catch (e) {
        // Fallback
      }
    }
    return fallback;
  }
}

// ─── مساعد حساب أيام العمل الفعلية (يتجاهل عطل نهاية الأسبوع) ────────────────
class WorkingDayCalculator {
  /// Calculate precise absence days taking into account the shift start, shift end,
  /// ignoring non-working days, and rounding to nearest 0.25 days.
  static double calculateExactAbsenceDays(
    DateTime fromDate,
    TimeOfDay? fromTime,
    DateTime toDate,
    TimeOfDay? toTime,
    TimeOfDay shiftStart,
    TimeOfDay shiftEnd,
  ) {
    DateTime startUtc =
        DateTime.utc(fromDate.year, fromDate.month, fromDate.day);
    DateTime endUtc = DateTime.utc(toDate.year, toDate.month, toDate.day);

    final shiftStartMinutes = shiftStart.hour * 60 + shiftStart.minute;
    final shiftEndMinutes = shiftEnd.hour * 60 + shiftEnd.minute;

    int shiftDurationMinutes = shiftEndMinutes > shiftStartMinutes
        ? shiftEndMinutes - shiftStartMinutes
        : (shiftEndMinutes + 24 * 60) - shiftStartMinutes;

    if (shiftDurationMinutes <= 0) return 0.0; // avoid division by zero

    int totalAbsenceMinutes = 0;
    DateTime cursor = startUtc;
    final box = Hive.isBoxOpen('factory_schedule')
        ? Hive.box<DaySchedule>('factory_schedule')
        : null;

    while (!cursor.isAfter(endUtc)) {
      final dayName = _weekdayName(cursor.weekday);
      final schedule = box?.get(dayName);
      final isWorkingDay = schedule == null || schedule.isWorkingDay;

      if (isWorkingDay) {
        int dayStartAbsence = shiftStartMinutes;
        int dayEndAbsence = shiftEndMinutes;

        // If this is the departure day, check if they left after shift started
        if (cursor.isAtSameMomentAs(startUtc) && fromTime != null) {
          final fromMinutes = fromTime.hour * 60 + fromTime.minute;
          if (fromMinutes > dayStartAbsence) {
            dayStartAbsence = fromMinutes;
          }
        }

        // If this is the return day, check if they returned before shift ended
        if (cursor.isAtSameMomentAs(endUtc) && toTime != null) {
          final toMinutes = toTime.hour * 60 + toTime.minute;
          if (toMinutes < dayEndAbsence) {
            dayEndAbsence = toMinutes;
          }
        }

        if (dayStartAbsence < dayEndAbsence) {
          int diff = dayEndAbsence - dayStartAbsence;
          // cap just in case
          if (diff > shiftDurationMinutes) diff = shiftDurationMinutes;
          totalAbsenceMinutes += diff;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    double totalDays = totalAbsenceMinutes / shiftDurationMinutes;

    // التقريب لأقرب ربع يوم (0.25) بناءً على طلب الإدارة لتسهيل الحسابات المالية
    return (totalDays * 4).round() / 4.0;
  }

  /// تحويل DateTime.weekday (1=Monday … 7=Sunday) إلى اسم DaySchedule
  static String _weekdayName(int weekday) {
    const map = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return map[weekday] ?? 'Monday';
  }
}

class WorkerDetailsScreen extends StatefulWidget {
  final Worker worker;
  final Box<Worker> box;

  const WorkerDetailsScreen({
    super.key,
    required this.worker,
    required this.box,
  });

  @override
  State<WorkerDetailsScreen> createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen> {
  StreamSubscription? _hiveSubscription;
  late Worker _worker;
  String? _currentDeviceId; // معرف الجهاز الحالي لتحديد ملكية الإجراء

  @override
  void initState() {
    super.initState();
    Worker.autoCloseHourlyActionsGlobal();
    _worker =
        (widget.worker.isInBox ? widget.box.get(widget.worker.key) : null) ??
            widget.worker;
    _cleanupActions();
    // تحميل device_id من صندوق الإعدادات لتحديد ملكية الإجراءات
    if (Hive.isBoxOpen('settings')) {
      _currentDeviceId = Hive.box('settings').get('device_id')?.toString();
    }
    // SyncService يتولى مزامنة worker_actions عبر _onAttendanceLogChange
    // الذي يُحدِّث Hive ثم يستدعي w.save() — يكفي الاستماع لـ Hive فقط.
    _setupHiveListener();
    // ✅ جلب حالة ارتباط الجهاز من Supabase (الـ Hive المحلي قد يكون قديماً)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncDeviceLinkStatus();
    });
  }

  /// جلب is_device_linked و device_id الحقيقية من Supabase سواء بالـ id أو بالـ email
  /// لتحديث الـ UI بالحالة الفعلية — يتجاوز بيانات Hive القديمة.
  Future<void> _syncDeviceLinkStatus() async {
    final workerId = _worker.id;
    final workerEmail = _worker.email;
    if (!mounted) return;
    try {
      Map<String, dynamic>? res;
      if (workerId != null && workerId.isNotEmpty) {
        res = await Supabase.instance.client
            .from('workers')
            .select('is_device_linked, device_id')
            .eq('id', workerId)
            .maybeSingle();
      }
      if (res == null && workerEmail != null && workerEmail.isNotEmpty) {
        res = await Supabase.instance.client
            .from('workers')
            .select('is_device_linked, device_id')
            .eq('email', workerEmail)
            .maybeSingle();
      }
      if (res != null && mounted) {
        final isLinked = res['is_device_linked'] as bool? ?? false;
        final deviceId = res['device_id']?.toString();
        if (_worker.isDeviceLinked != isLinked ||
            _worker.deviceId != deviceId) {
          setState(() {
            _worker.isDeviceLinked = isLinked;
            _worker.deviceId = deviceId;
          });
          debugPrint(
              '📱 WorkerDetails: حُدِّثت حالة الجهاز → isLinked=$isLinked, deviceId=$deviceId');
        }
      }
    } catch (e) {
      debugPrint('⚠️ WorkerDetails._syncDeviceLinkStatus: $e');
    }
  }

  @override
  void dispose() {
    _hiveSubscription?.cancel();
    super.dispose();
  }

  void _setupHiveListener() {
    if (!widget.box.isOpen) return;
    // نُثبِّت المفتاح فوراً قبل أي إعادة تهيئة للـ Hive قد تُبطل المرجع القديم.
    // بعد استدعاء _initWorkers() عند resume، يُستبدَل Worker القديم بجديد
    // ويفقد القديم مفتاحه من الـ keystore → widget.worker.key يصبح null.
    final watchKey = widget.worker.key;
    if (watchKey == null) {
      debugPrint(
          '⚠️ WorkerDetails: worker key is null, Hive listener skipped.');
      return;
    }
    _hiveSubscription = widget.box.watch(key: watchKey).listen((event) {
      if (mounted) {
        final freshWorker =
            widget.box.get(watchKey); // استخدام المفتاح المُثبَّت
        if (freshWorker != null) {
          setState(() {
            _worker = freshWorker;
          });
        }
      }
    });
  }

  void _cleanupActions() async {
    // Remove ghost/null keys from HiveList and remove duplicates by ID
    final initialCount = _worker.actions.length;
    final rawActions = _worker.actions.whereType<WorkerAction>().toList();

    final uniqueMap = <String, WorkerAction>{};
    for (var action in rawActions) {
      if (action.id != null) {
        uniqueMap[action.id!] = action;
      }
    }

    final validList = uniqueMap.values.toList();

    if (validList.length != initialCount) {
      _worker.actions.clear();
      _worker.actions.addAll(validList);
      await _worker.save();
      if (mounted) setState(() {});
    }
  }

  void _refresh() => setState(() {});

  /// تحديد ما إذا كان الجهاز الحالي هو مالك هذا الإجراء.
  /// • إذا كان [createdByDeviceId] فارغ (إجراءات قديمة لا تحمل device_id)،
  ///   نفترض التوافق للجهاز الحالي حتى لا نكسر التحكم في الإجراءات السابقة.
  bool _isActionOwner(WorkerAction action) {
    final actionDevice = action.createdByDeviceId;
    if (actionDevice == null || actionDevice.isEmpty) {
      return true; // backward compat
    }
    if (_currentDeviceId == null || _currentDeviceId!.isEmpty) {
      return true; // device not identified
    }
    return _currentDeviceId == actionDevice;
  }

  String _f(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _copyPhoneToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _worker.phone));

    UIUtils.showInfoSnackBar(
      message: "تم نسخ الرقم بنجاح",
      backgroundColor: Colors.green,
      icon: Icons.content_copy_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = !kIsWeb && Platform.isWindows;
    final bool isSuperAdmin = PermissionHelper.isSuperAdmin;
    final Worker? cw = PermissionHelper.currentWorker;
    final bool canManageActions = isSuperAdmin || (cw?.canEditWorker == true);

    bool canManageForThisWorker(bool Function(Worker) checkPerm) {
      final Worker? cw = PermissionHelper.currentWorker;
      if (cw == null) return false;
      final bool isSupervisor = cw.job == 'مشرف' || cw.job == 'رئيس قسم';
      final bool sameDept = cw.department == _worker.department;
      return isSupervisor && sameDept && checkPerm(cw);
    }

    final bool canEditThisWorker =
        isSuperAdmin || canManageForThisWorker((cw) => cw.canEdit);
    final bool canDeleteThisWorker =
        isSuperAdmin || canManageForThisWorker((cw) => cw.canDelete);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text("👤 ${_worker.name}"),
        centerTitle: true,
        actions: [
          // ─── قائمة اتصال مدمجة في AppBar ────────────────────────
          PopupMenuButton<String>(
            icon: const Icon(Icons.phone_outlined),
            tooltip: 'خيارات الاتصال',
            onSelected: (value) {
              if (value == 'call') {
                _launchURL('tel:${_worker.phone}');
              } else if (value == 'whatsapp') {
                _launchWhatsApp(_worker.phone);
              } else if (value == 'copy') {
                _copyPhoneToClipboard();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'call',
                child: Row(
                  children: [
                    Icon(Icons.phone, color: Colors.green, size: 20),
                    SizedBox(width: 10),
                    Text('اتصال'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'whatsapp',
                child: Row(
                  children: [
                    Icon(Icons.message, color: Color(0xFF25D366), size: 20),
                    SizedBox(width: 10),
                    Text('واتساب'),
                  ],
                ),
              ),
              if (isWindows)
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Text('نسخ الرقم'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Worker Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // الجانب الأيمن (بيانات العامل)
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            child: Icon(
                              Icons.person,
                              size: 26,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "🛠 ${_worker.job}",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildWorkerStatusChip(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.history, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "📜 سجل الحركات",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Builder(builder: (context) {
                  final rawActions =
                      _worker.actions.whereType<WorkerAction>().toList();
                  final uniqueCount =
                      rawActions.map((a) => a.id).toSet().length;
                  return Text(
                    "$uniqueCount حركة",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  );
                }),
              ],
            ),
            const Divider(),
            _buildActiveAbsenceSection(),
            Expanded(
              child: Builder(
                builder: (context) {
                  // Filter out ghost keys (nulls) and ensure stability
                  final rawActions =
                      _worker.actions.whereType<WorkerAction>().toList();

                  // تنظيف القائمة لمنع التكرار (Unique filter by ID)
                  final uniqueActionsMap = <String, WorkerAction>{};
                  for (var action in rawActions) {
                    if (action.id != null) {
                      uniqueActionsMap[action.id!] = action;
                    }
                  }
                  final validActions = uniqueActionsMap.values.toList();

                  if (validActions.isEmpty) {
                    return const Center(
                        child: Text("لا توجد حركات لهذا العامل بعد"));
                  }

                  // Sort actions by date descending
                  final sortedActions = List<WorkerAction>.from(validActions)
                    ..sort((a, b) => b.date.compareTo(a.date));

                  return ListView.builder(
                    itemCount: sortedActions.length,
                    itemBuilder: (context, index) {
                      if (index >= sortedActions.length) {
                        return const SizedBox.shrink();
                      }
                      final displayedAction = sortedActions[index];

                      // Find original index using ID for reliability
                      int originalIndex = -1;
                      if (displayedAction.id != null) {
                        originalIndex = _worker.actions.indexWhere((a) =>
                            (a as WorkerAction?)?.id == displayedAction.id);
                      }
                      if (originalIndex == -1) {
                        originalIndex =
                            _worker.actions.indexOf(displayedAction);
                      }

                      final bool isOwner = _isActionOwner(displayedAction);

                      return WorkerActionCard(
                        action: displayedAction,
                        showEditButton: canManageActions || canEditThisWorker || isOwner,
                        showDeleteButton:
                            canManageActions || canDeleteThisWorker || isOwner,
                        onRefresh: _refresh,
                        onEdit: () async {
                          if (originalIndex != -1) {
                            _editAction(
                                _worker.actions[originalIndex], originalIndex);
                            _refresh();
                          }
                        },
                        onDelete: () {
                          UIUtils.showDeleteConfirmation(
                            context: context,
                            title: "حذف الحركة",
                            content: "هل أنت متأكد من حذف هذه الحركة؟",
                            onConfirm: () async {
                              final messenger = ScaffoldMessenger.of(context);

                              // Safely capture action to delete before any awaits
                              // Use ID search for maximum reliability in case of list shifts
                              final String? targetId = displayedAction.id;

                              if (targetId == null) return;

                              // Re-locate the action safely
                              final actionToDelete = _worker.actions
                                  .cast<WorkerAction?>()
                                  .firstWhere(
                                    (a) => a?.id == targetId,
                                    orElse: () => null,
                                  );

                              if (actionToDelete == null) {
                                // Already deleted or shifted
                                _refresh();
                                return;
                              }

                              final actionJson = actionToDelete.toJson();

                              // Deleting from HiveList, HiveBox, and Syncing to Supabase
                              _worker.actions.remove(actionToDelete);
                              await _worker.save();

                              // Delete from box
                              if (actionToDelete.isInBox) {
                                await actionToDelete.delete();
                              }

                              // Sync deletion to Supabase
                              SyncService.instance.pushToQueue(
                                  'worker_actions', actionJson,
                                  operation: 'delete');

                              if (!context.mounted) return;

                              messenger.clearSnackBars();
                              UIUtils.showUndoSnackBar(
                                context: context,
                                message: "تم حذف الحركة",
                                onUndo: () async {
                                  final actionBox =
                                      Hive.box<WorkerAction>('worker_actions');
                                  final restoredAction =
                                      WorkerAction.fromJson(actionJson);

                                  // Use put with ID instead of add
                                  await actionBox.put(
                                      restoredAction.id, restoredAction);
                                  final saved =
                                      actionBox.get(restoredAction.id);

                                  if (saved != null) {
                                    _worker.actions.add(saved);
                                    await _worker.save();
                                    // Sync back to Supabase
                                    SyncService.instance.pushToQueue(
                                        'worker_actions', saved.toJson());
                                    _refresh();
                                  }
                                },
                              );

                              _refresh();
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // ─── FAB: محمي بـ ValueListenableBuilder لسحب الصلاحيات فورياً ───
      floatingActionButton: ValueListenableBuilder<Box<Worker>>(
        valueListenable: widget.box.listenable(),
        builder: (context, _, __) {
          final bool isSuperAdmin = PermissionHelper.isSuperAdmin;
          final Worker? cw = PermissionHelper.currentWorker;
          final bool canManageActions =
              isSuperAdmin || (cw?.canEditWorker == true);

          // شروط المشرف / رئيس القسم:
          // نفس القسم كالعامل المعروض + صلاحية canAdd
          bool canAddForThisWorker() {
            final Worker? cw = PermissionHelper.currentWorker;
            if (cw == null) return false;
            final bool isSupervisor = cw.job == 'مشرف' || cw.job == 'رئيس قسم';
            final bool sameDept = cw.department == _worker.department;
            return isSupervisor && sameDept && cw.canAdd;
          }

          final bool showFab = PermissionHelper.canAddWorkerAction ||
              canManageActions ||
              canAddForThisWorker();
          if (!showFab) return const SizedBox.shrink();

          return FloatingActionButton(
            heroTag: "worker_details_fab",
            onPressed: () => _showAddActionDialog(context),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  Widget _buildActiveAbsenceSection() {
    final activeAction = _worker.activeAction;
    // Skip scheduled (future) leaves — they should NOT show the card yet
    // Skip old actions (more than 30 days ago) to keep the view clean
    if (activeAction == null ||
        activeAction.isScheduled ||
        DateTime.now().difference(activeAction.date).inDays > 30) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: 190,
        child: Builder(builder: (context) {
          final bool isOwner = _isActionOwner(activeAction);
          final bool isSuperAdmin = PermissionHelper.isSuperAdmin;
          final Worker? cw = PermissionHelper.currentWorker;
          final bool canManageActions =
              isSuperAdmin || (cw?.canEditWorker == true);

          bool canManageForThisWorker(bool Function(Worker) checkPerm) {
            final Worker? cw = PermissionHelper.currentWorker;
            if (cw == null) return false;
            final bool isSupervisor = cw.job == 'مشرف' || cw.job == 'رئيس قسم';
            final bool sameDept = cw.department == _worker.department;
            return isSupervisor && sameDept && checkPerm(cw);
          }

          final bool canEditThisWorker =
              isSuperAdmin || canManageForThisWorker((cw) => cw.canEdit);
          final bool canDeleteThisWorker =
              isSuperAdmin || canManageForThisWorker((cw) => cw.canDelete);

          return ActiveAbsenceCard(
            worker: _worker,
            action: activeAction,
            showEditButton: canManageActions || canEditThisWorker || isOwner,
            showDeleteButton:
                canManageActions || canDeleteThisWorker || isOwner,
            onRefresh: _refresh,
            onEdit: () {
              final idx = _worker.actions.indexOf(activeAction);
              _editAction(activeAction, idx);
            },
          );
        }),
      ),
    );
  }

  void _showAddActionDialog(BuildContext context) => _showActionBottomSheet();

  void _editAction(WorkerAction action, int index) =>
      _showActionBottomSheet(existingAction: action, index: index);

  void _showActionBottomSheet({WorkerAction? existingAction, int? index}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final actionType = ValueNotifier<String>(existingAction?.type ?? 'إجازة');
    final date =
        ValueNotifier<DateTime>(existingAction?.date ?? DateTime.now());
    final calculatedDays = ValueNotifier<double>(existingAction?.days ?? 1.0);
    final expectedReturnDate =
        ValueNotifier<DateTime?>(existingAction?.expectedReturnDate);

    // Default time initialization based on factory shift
    final defaultDepartureTime =
        ShiftTimeCalculator.getDefaultDepartureTime(themeProvider);
    final defaultReturnTime =
        ShiftTimeCalculator.getDefaultReturnTime(themeProvider);

    bool userModifiedStartTime = false;
    bool userModifiedEndTime = false;

    // Set default departure time to shift start for new actions
    final startTime = ValueNotifier<TimeOfDay?>(
        existingAction?.startTime ?? defaultDepartureTime);

    // Set default return time to shift start when ending a live session (returnDate is set)
    final endTime =
        ValueNotifier<TimeOfDay?>(existingAction?.endTime ?? defaultReturnTime);

    final rewardType = ValueNotifier<String>(
        existingAction?.amount != null ? 'amount' : 'days');
    final amountController =
        TextEditingController(text: existingAction?.amount?.toString() ?? '');
    final bonusDays = ValueNotifier<double?>(existingAction?.bonusDays);
    final notesController =
        TextEditingController(text: existingAction?.notes ?? '');
    final returnDate = ValueNotifier<DateTime?>(existingAction?.returnDate);

    final selectedShiftName = ValueNotifier<String?>(existingAction?.shiftName);

    void updateCalculatedDays() {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      TimeOfDay shiftStart = themeProvider.shiftStart;
      TimeOfDay shiftEnd = themeProvider.shiftEnd;

      if (Hive.isBoxOpen('factory_schedule')) {
        const map = {
          1: 'Monday',
          2: 'Tuesday',
          3: 'Wednesday',
          4: 'Thursday',
          5: 'Friday',
          6: 'Saturday',
          7: 'Sunday',
        };
        final dayName = map[date.value.weekday] ?? 'Monday';
        final schedule = Hive.box<DaySchedule>('factory_schedule').get(dayName);
        if (schedule != null &&
            schedule.shifts != null &&
            schedule.shifts!.isNotEmpty) {
          final shift = schedule.shifts!.firstWhere(
            (s) => s.name == selectedShiftName.value,
            orElse: () => schedule.shifts!.first,
          );

          TimeOfDay parseTime(String raw) {
            try {
              final parts = raw.split(' ');
              final timeParts = parts[0].split(':');
              int hour = int.parse(timeParts[0]);
              final int minute = int.parse(timeParts[1]);
              if (parts.length > 1) {
                final ampm = parts[1].toLowerCase();
                if (ampm == 'pm' && hour < 12) hour += 12;
                if (ampm == 'am' && hour == 12) hour = 0;
              }
              return TimeOfDay(hour: hour, minute: minute);
            } catch (e) {
              return const TimeOfDay(hour: 8, minute: 0);
            }
          }

          shiftStart = parseTime(shift.startTime);
          shiftEnd = parseTime(shift.endTime);
        }
      }

      // تحديد ما إذا كان الإجراء يوم كامل أو بالساعات
      final isFullDayAction = actionType.value == 'إجازة' ||
          actionType.value == 'غياب' ||
          actionType.value == 'أجازة عارضة';

      // تحديث وقت البداية والنهاية ليكون متوافقاً مع الوردية
      // في حالة الإجراءات الجديدة أو عند تغيير الوردية للإجراءات الكاملة
      if (existingAction == null || isFullDayAction) {
        if (!userModifiedStartTime) {
          startTime.value = shiftStart;
        }
        if (!userModifiedEndTime) {
          endTime.value = shiftStart; // العودة دائماً في بداية الوردية للإجازات
        }
      }



      final isHourlyAction =
          actionType.value == 'إذن' || actionType.value == 'تأمين صحي';

      if (isFullDayAction && returnDate.value != null) {
        calculatedDays.value = WorkingDayCalculator.calculateExactAbsenceDays(
          date.value,
          startTime.value,
          returnDate.value!,
          endTime.value,
          shiftStart,
          shiftEnd,
        );
      } else if (isHourlyAction &&
          startTime.value != null &&
          endTime.value != null) {
        calculatedDays.value = WorkingDayCalculator.calculateExactAbsenceDays(
          date.value,
          startTime.value,
          returnDate.value ??
              date.value, // الإذن عادةً نفس اليوم ما لم يحدد خلاف ذلك
          endTime.value,
          shiftStart,
          shiftEnd,
        );
      } else {
        // Default / Initial state
        calculatedDays.value = 0.0;
      }
    }

    // Initial calculation for existing actions
    if (existingAction != null) {
      updateCalculatedDays();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              // Handle
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
                        existingAction == null
                            ? "➕ إضافة ${actionType.value}"
                            : "🔄 تعديل الإجراء",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: actionType.value,
                        items: const [
                          DropdownMenuItem(
                              value: 'إجازة', child: Text('إجازة')),
                          DropdownMenuItem(
                              value: 'أجازة عارضة', child: Text('أجازة عارضة')),
                          DropdownMenuItem(value: 'غياب', child: Text('غياب')),
                          DropdownMenuItem(
                              value: 'مكافئة', child: Text('مكافئة')),
                          DropdownMenuItem(value: 'جزاء', child: Text('جزاء')),
                          DropdownMenuItem(value: 'إذن', child: Text('إذن')),
                          DropdownMenuItem(
                              value: 'تأمين صحي', child: Text('تأمين صحي')),
                        ],
                        onChanged: (v) {
                          setState(() => actionType.value = v ?? 'إجازة');
                          updateCalculatedDays();
                        },
                        decoration:
                            const InputDecoration(labelText: "نوع الإجراء"),
                      ),
                      if (actionType.value == 'إجازة' ||
                          actionType.value == 'غياب' ||
                          actionType.value == 'أجازة عارضة' ||
                          actionType.value == 'إذن' ||
                          actionType.value == 'تأمين صحي') ...[
                        const SizedBox(height: 12),
                        ValueListenableBuilder<DateTime>(
                          valueListenable: date,
                          builder: (context, dateVal, _) {
                            List<String> shiftOptions = [];
                            if (Hive.isBoxOpen('factory_schedule')) {
                              const map = {
                                1: 'Monday',
                                2: 'Tuesday',
                                3: 'Wednesday',
                                4: 'Thursday',
                                5: 'Friday',
                                6: 'Saturday',
                                7: 'Sunday',
                              };
                              final dayName = map[dateVal.weekday] ?? 'Monday';
                              final schedule =
                                  Hive.box<DaySchedule>('factory_schedule')
                                      .get(dayName);
                              if (schedule != null && schedule.shifts != null) {
                                shiftOptions = schedule.shifts!
                                    .map((s) => s.name)
                                    .toList();
                              }
                            }

                            if (shiftOptions.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            if (selectedShiftName.value == null ||
                                !shiftOptions
                                    .contains(selectedShiftName.value)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (selectedShiftName.value !=
                                    shiftOptions.first) {
                                  selectedShiftName.value = shiftOptions.first;
                                  updateCalculatedDays();
                                }
                              });
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: DropdownButtonFormField<String>(
                                initialValue: shiftOptions
                                        .contains(selectedShiftName.value)
                                    ? selectedShiftName.value
                                    : shiftOptions.first,
                                items: shiftOptions
                                    .map((s) => DropdownMenuItem(
                                        value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() => selectedShiftName.value = v);
                                  updateCalculatedDays();
                                },
                                decoration: const InputDecoration(
                                    labelText:
                                        "الوردية (تحدد عدد ساعات الحركة)"),
                              ),
                            );
                          },
                        ),
                        // Row 1: Start Date & Time
                        Row(
                          children: [
                            Expanded(
                                child: _buildDateField(
                                    "📅 تاريخ القيام",
                                    date as ValueNotifier<DateTime?>,
                                    context,
                                    setState,
                                    updateCalculatedDays:
                                        updateCalculatedDays)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTimeField("⏰ وقت القيام",
                                    startTime, context, setState,
                                    updateCalculatedDays: updateCalculatedDays,
                                    onUserModified: () =>
                                        userModifiedStartTime = true)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Row 2: Return Date & Time
                        Row(
                          children: [
                            Expanded(
                                child: _buildDateField("🔙 تاريخ العودة",
                                    returnDate, context, setState,
                                    isOptional: true,
                                    updateCalculatedDays:
                                        updateCalculatedDays)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTimeField(
                                    "🕒 وقت العودة", endTime, context, setState,
                                    updateCalculatedDays: updateCalculatedDays,
                                    onUserModified: () =>
                                        userModifiedEndTime = true)),
                          ],
                        ),
                        if (actionType.value == 'إجازة' ||
                            actionType.value == 'غياب' ||
                            actionType.value == 'أجازة عارضة') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.calculate_outlined,
                                        color: Colors.grey, size: 20),
                                    SizedBox(width: 8),
                                    Text("عدد الأيام المحسوب:",
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                ValueListenableBuilder<double>(
                                  valueListenable: calculatedDays,
                                  builder: (context, val, _) => Text(
                                    "$val يوم",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // حقل تاريخ العودة المتوقع (اختياري)
                          _buildDateField(
                            "📅 تاريخ العودة المتوقع",
                            expectedReturnDate,
                            context,
                            setState,
                            isOptional: true,
                          ),
                        ],
                      ] else if (actionType.value == 'مكافئة' ||
                          actionType.value == 'جزاء') ...[
                        const SizedBox(height: 12),
                        _buildDateField(
                            "📅 التاريخ",
                            date as ValueNotifier<DateTime?>,
                            context,
                            setState),
                        const SizedBox(height: 12),
                        ToggleButtons(
                          borderRadius: BorderRadius.circular(8),
                          isSelected: [
                            rewardType.value == 'amount',
                            rewardType.value == 'days'
                          ],
                          onPressed: (int index) => setState(() => rewardType
                              .value = index == 0 ? 'amount' : 'days'),
                          children: const [
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text("جنيه")),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text("أيام")),
                          ],
                        ),
                        if (rewardType.value == 'amount') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: "💰 المبلغ"),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<double>(
                            initialValue: bonusDays.value,
                            items: [
                              const DropdownMenuItem(
                                  value: 0.25, child: Text('¼ يوم')),
                              const DropdownMenuItem(
                                  value: 0.5, child: Text('½ يوم')),
                              for (var i = 1; i <= 5; i++)
                                DropdownMenuItem(
                                    value: i.toDouble(), child: Text('$i يوم')),
                            ],
                            onChanged: (v) =>
                                setState(() => bonusDays.value = v),
                            decoration:
                                const InputDecoration(labelText: "📅 الأيام"),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration:
                            const InputDecoration(labelText: "📝 ملاحظات"),
                      ),
                      const SizedBox(height: 12),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                final actionBox =
                                    Hive.box<WorkerAction>('worker_actions');
                                double? amountToSave;
                                double? bonusDaysToSave;

                                if (actionType.value == 'مكافئة' ||
                                    actionType.value == 'جزاء') {
                                  if (rewardType.value == 'amount') {
                                    amountToSave =
                                        double.tryParse(amountController.text);
                                  } else {
                                    bonusDaysToSave = bonusDays.value;
                                  }
                                }

                                final factoryId =
                                    await SupabaseManager.getFactoryId();

                                if (existingAction == null) {
                                  // جلب device_id من صندوق الإعدادات لتسجيل ملكية الإجراء
                                  final deviceId = _currentDeviceId ??
                                      (Hive.isBoxOpen('settings')
                                          ? Hive.box('settings')
                                              .get('device_id')
                                              ?.toString()
                                          : null);

                                  final newActionId = const Uuid().v4();

                                  final updatedAction = WorkerAction(
                                    id: newActionId,
                                    type: actionType.value,
                                    days: (actionType.value == 'إجازة' ||
                                            actionType.value == 'أجازة عارضة' ||
                                            actionType.value == 'غياب')
                                        ? calculatedDays.value
                                        : 0,
                                    date: date.value,
                                    returnDate: returnDate.value,
                                    expectedReturnDate: expectedReturnDate.value,
                                    notes: notesController.text,
                                    startTimeHour: startTime.value?.hour,
                                    startTimeMinute: startTime.value?.minute,
                                    endTimeHour: endTime.value?.hour,
                                    endTimeMinute: endTime.value?.minute,
                                    amount: amountToSave,
                                    bonusDays: bonusDaysToSave,
                                    factoryId: factoryId ?? _worker.factoryId,
                                    workerName: _worker.name,
                                    workerId: _worker.id,
                                    createdByDeviceId: deviceId,
                                    shiftName: selectedShiftName.value,
                                  );

                                  // Use put with ID instead of add to maintain key consistency
                                  await actionBox.put(
                                      updatedAction.id, updatedAction);
                                  final saved = actionBox.get(updatedAction.id);
                                  if (saved != null) {
                                    _worker.actions.add(saved);
                                    await _worker.save();

                                    final actionData = saved.toJson();
                                    actionData['factory_id'] = factoryId;
                                    SyncService.instance.pushToQueue(
                                        'worker_actions', actionData);
                                  }
                                } else {
                                  // Edit existing action via mutation
                                  existingAction.type = actionType.value;
                                  existingAction.days = (actionType.value ==
                                              'إجازة' ||
                                          actionType.value == 'أجازة عارضة' ||
                                          actionType.value == 'غياب')
                                      ? calculatedDays.value
                                      : 0;
                                  existingAction.date = date.value;
                                  existingAction.returnDate = returnDate.value;
                                  existingAction.expectedReturnDate =
                                      expectedReturnDate.value;
                                  existingAction.notes = notesController.text;
                                  existingAction.startTimeHour =
                                      startTime.value?.hour;
                                  existingAction.startTimeMinute =
                                      startTime.value?.minute;
                                  existingAction.endTimeHour =
                                      endTime.value?.hour;
                                  existingAction.endTimeMinute =
                                      endTime.value?.minute;
                                  existingAction.amount = amountToSave;
                                  existingAction.bonusDays = bonusDaysToSave;
                                  existingAction.shiftName =
                                      selectedShiftName.value;
                                  existingAction.factoryId =
                                      factoryId ?? existingAction.factoryId;

                                  if (existingAction.isInBox) {
                                    await existingAction.save();
                                  } else {
                                    final actionBox = Hive.box<WorkerAction>(
                                        'worker_actions');
                                    if (existingAction.id != null) {
                                      await actionBox.put(
                                          existingAction.id, existingAction);
                                    }
                                  }
                                  await _worker.save();

                                  final actionData = existingAction.toJson();
                                  actionData['factory_id'] = factoryId;
                                  SyncService.instance.pushToQueue(
                                      'worker_actions', actionData);
                                }

                                if (context.mounted) Navigator.pop(context);
                                _refresh();
                              },
                              child: Text(existingAction == null
                                  ? "✅ إضافة"
                                  : "✅ حفظ التعديلات"),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildDateField(String label, ValueNotifier<DateTime?> dateNotifier,
      BuildContext context, StateSetter setState,
      {bool isOptional = false, VoidCallback? updateCalculatedDays}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dateNotifier.value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => dateNotifier.value = picked);
              if (updateCalculatedDays != null) updateCalculatedDays();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateNotifier.value != null
                      ? _f(dateNotifier.value!)
                      : "لم يحدد",
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (isOptional && dateNotifier.value != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() => dateNotifier.value = null);
                      if (updateCalculatedDays != null) updateCalculatedDays();
                    },
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  )
                else
                  const Icon(Icons.calendar_month,
                      size: 16, color: Colors.blue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(String label, ValueNotifier<TimeOfDay?> timeNotifier,
      BuildContext context, StateSetter setState,
      {VoidCallback? updateCalculatedDays, VoidCallback? onUserModified}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
                context: context,
                initialTime: timeNotifier.value ?? TimeOfDay.now());
            if (picked != null) {
              setState(() => timeNotifier.value = picked);
              if (onUserModified != null) onUserModified();
              if (updateCalculatedDays != null) updateCalculatedDays();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeNotifier.value?.format(context) ?? "لم يحدد",
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (timeNotifier.value != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => setState(() => timeNotifier.value = null),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  )
                else
                  const Icon(Icons.access_time, size: 16, color: Colors.blue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerStatusChip() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // تحقق من وجود إجازة مجدَّلة للمستقبل
    WorkerAction? scheduledAction;
    try {
      scheduledAction = _worker.actions.cast<WorkerAction?>().firstWhere(
            (a) => a != null && a.isScheduled,
            orElse: () => null,
          );
    } catch (_) {
      scheduledAction = null;
    }

    final activeAction = _worker.activeAction;

    // متواجد حالياً بإجازة نشطة
    if (activeAction != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer, size: 14, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text(
              activeAction.isTimeBased ? "خارج العمل (${activeAction.type})" : "في ${activeAction.type}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ),
      );
    }

    // متواجد لكن هناك إجازة مجدَّلة قادمة
    if (scheduledAction != null) {
      final startDay = DateTime(
        scheduledAction.date.year,
        scheduledAction.date.month,
        scheduledAction.date.day,
      );
      final daysUntil = startDay.difference(today).inDays;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event, size: 14, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Text(
              daysUntil == 1
                  ? "متواجد (إجازة غداً)"
                  : "متواجد (إجازة بعد $daysUntil يوم)",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      );
    }

    // متواجد بشكل طبيعي
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
          const SizedBox(width: 4),
          Text(
            "متواجد",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح تطبيق الهاتف'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    try {
      // Clean phone number - remove all non-digit characters and spaces
      String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

      // Remove leading zeros and add country code if needed
      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }

      // Add Egypt country code if not present
      if (!cleanPhone.startsWith('20') && !cleanPhone.startsWith('+20')) {
        cleanPhone = '20$cleanPhone';
      }

      // Remove + if present to ensure clean format for wa.me
      if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      }

      debugPrint('Cleaned phone for WhatsApp: $cleanPhone');

      // Default message in Arabic
      const defaultMessage = 'السلام عليكم';
      final encodedMessage = Uri.encodeComponent(defaultMessage);
      final url = "https://wa.me/$cleanPhone?text=$encodedMessage";

      debugPrint('WhatsApp URL: $url');

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'لا يمكن فتح تطبيق الواتساب. يرجى التأكد من تثبيت التطبيق'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ عند فتح الواتساب: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
