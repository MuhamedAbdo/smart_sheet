import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import 'package:smart_sheet/models/day_schedule.dart';
import 'worker_action_model.dart';

part 'worker_model.g.dart';

@HiveType(typeId: 1)
class Worker extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late String phone;

  @HiveField(2)
  late String job;

  @HiveField(3)
  // ignore: experimental_member_use
  HiveList<WorkerAction>? _actions;

  // ignore: experimental_member_use
  HiveList<WorkerAction> get actions {
    if (_actions == null) {
      if (Hive.isBoxOpen('worker_actions')) {
        final box = Hive.box<WorkerAction>('worker_actions');
        // ignore: experimental_member_use
        _actions = HiveList(box);
      } else {
        debugPrint('❌ Error: worker_actions box is closed. Returning temporary empty HiveList container.');
      }
    }
    return _actions ?? (throw StateError('worker_actions box must be open to access actions.'));
  }

  // ignore: experimental_member_use
  set actions(HiveList<WorkerAction> value) => _actions = value;

  @HiveField(4)
  late bool hasMedicalInsurance;

  @HiveField(5)
  late String? factoryId;

  @HiveField(6)
  late String? id; // Unique ID for Supabase sync

  @HiveField(7)
  late String department; // flexo, production_line, die_cutting, staples, stores, silicates

  @HiveField(8)
  late bool canAdd;

  @HiveField(9)
  late bool canEdit;

  @HiveField(10)
  late bool canDelete;

  @HiveField(11)
  late String? email;

  /// Alias for [id] — kept for backward compatibility with SyncService
  String? get syncId => id;

  Worker({
    this.id,
    required this.name,
    required this.phone,
    required this.job,
    List<WorkerAction>? actions,
    this.hasMedicalInsurance = false,
    this.factoryId,
    this.department = 'flexo',
    this.canAdd = false,
    this.canEdit = false,
    this.canDelete = false,
    this.email,
  }) {
    // Generate valid UUID v4 if not provided or invalid (fixes 22P02 error in Supabase)
    if (id == null || !id!.contains('-')) {
      id = _generateV4Uuid();
    }
    _initializeActions(actions);
  }

  static String _generateV4Uuid() {
    final Random random = Random();
    final List<int> values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant 10
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  void _initializeActions(List<WorkerAction>? actionsList) {
    try {
      if (Hive.isBoxOpen('worker_actions')) {
        final box = Hive.box<WorkerAction>('worker_actions');
        // ignore: experimental_member_use
        _actions = HiveList(box, objects: actionsList ?? []);
      } else {
        debugPrint(
            "⚠️ Warning: worker_actions box is not open during Worker initialization.");
      }
    } catch (e) {
      debugPrint("⚠️ Error initializing actions: $e");
    }
  }

  void reconnectActionsBox() {
    try {
      if (Hive.isBoxOpen('worker_actions')) {
        final box = Hive.box<WorkerAction>('worker_actions');
        // ignore: experimental_member_use
        final currentObjects = _actions?.toList() ?? [];
        // ignore: experimental_member_use
        _actions = HiveList(box, objects: currentObjects);
      }
    } catch (e) {
      debugPrint("⚠️ Error reconnecting actions box: $e");
    }
  }

  /// Returns the currently active live-session action (leave/absence/permission/etc
  /// with no returnDate), or null if the worker is present.
  WorkerAction? get activeAction {
    try {
      return actions.cast<WorkerAction?>().firstWhere(
            (a) => a != null && a.isActive,
            orElse: () => null,
          );
    } catch (_) {
      return null;
    }
  }

  /// Returns true if the worker is currently out (on leave, absence, etc.).
  bool get isOut => activeAction != null;

  /// Closes all active hourly actions (permissions, health insurance) that have passed their shift end time.
  static Future<void> autoCloseHourlyActionsGlobal() async {
    if (!Hive.isBoxOpen('workers') || !Hive.isBoxOpen('factory_schedule') || !Hive.isBoxOpen('settings')) return;
    
    final workersBox = Hive.box<Worker>('workers');
    final scheduleBox = Hive.box<DaySchedule>('factory_schedule');
    final settingsBox = Hive.box('settings');

    final String defaultShiftEndStr = settingsBox.get('shift_end', defaultValue: '17:00');
    final parts = defaultShiftEndStr.split(':');
    final defaultShiftEndHour = int.tryParse(parts[0]) ?? 17;
    final defaultShiftEndMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final TimeOfDay defaultShiftEnd = TimeOfDay(hour: defaultShiftEndHour, minute: defaultShiftEndMinute);

    final now = DateTime.now();

    for (final worker in workersBox.values) {
      final activeAction = worker.activeAction;
      if (activeAction != null && activeAction.isTimeBased && activeAction.returnDate == null) {
        // Find shift end for the action's date
        final dayName = _weekdayName(activeAction.date.weekday);
        final schedule = scheduleBox.get(dayName);
        
        TimeOfDay shiftEnd = defaultShiftEnd;
        if (schedule != null) {
          shiftEnd = _parseTime(schedule.shiftEnd);
        }

        final shiftEndDateTime = DateTime(
          activeAction.date.year,
          activeAction.date.month,
          activeAction.date.day,
          shiftEnd.hour,
          shiftEnd.minute,
        );

        if (now.isAfter(shiftEndDateTime)) {
          debugPrint('🔄 Auto-closing action for ${worker.name} (action type: ${activeAction.type})');
          activeAction.returnDate = activeAction.date;
          activeAction.endTimeHour = shiftEnd.hour;
          activeAction.endTimeMinute = shiftEnd.minute;

          if (activeAction.isInBox) {
            await activeAction.save();
          }
          await worker.save();
        }
      }
    }
  }

  static String _weekdayName(int weekday) {
    const map = {
      1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday',
      5: 'Friday', 6: 'Saturday', 7: 'Sunday',
    };
    return map[weekday] ?? 'Monday';
  }

  static TimeOfDay _parseTime(String timeString) {
    try {
      final parts = timeString.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      
      if (parts.length > 1) {
        final period = parts[1].toUpperCase();
        if (period == 'PM' && hour != 12) {
          hour += 12;
        } else if (period == 'AM' && hour == 12) {
          hour = 0;
        }
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 17, minute: 0);
    }
  }

  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> actionsJson = [];
    try {
      // Use the private field to avoid getter throw if box is closed
      if (_actions != null) {
        actionsJson = _actions!.map((action) => action.toJson()).toList();
      }
    } catch (e) {
      debugPrint("⚠️ Error serializing actions in toJson: $e");
    }

    return {
      'id': id,
      'sync_id': id, // Alias for compatibility with some schemas
      'name': name,
      'phone': phone,
      'job': job,
      'has_medical_insurance': hasMedicalInsurance,
      'factory_id': factoryId,
      'actions': actionsJson,
      'department': department,
      'can_add': canAdd,
      'can_edit': canEdit,
      'can_delete': canDelete,
      'email': email,
    };
  }

  factory Worker.fromJson(Map<String, dynamic> map) {
    List<dynamic> actionsList = map['actions'] ?? [];
    List<WorkerAction> actions =
        actionsList.map((a) => WorkerAction.fromJson(a)).toList();

    return Worker(
      id: (map['id'] ?? map['sync_id'])?.toString(),
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      job: map['job'] ?? '',
      actions: actions,
      hasMedicalInsurance: map['has_medical_insurance'] ?? false,
      factoryId: map['factory_id'],
      department: map['department'] ?? 'flexo',
      canAdd: map['can_add'] ?? map['canAdd'] ?? false,
      canEdit: map['can_edit'] ?? map['canEdit'] ?? false,
      canDelete: map['can_delete'] ?? map['canDelete'] ?? false,
      email: map['email']?.toString(),
    );
  }
}
