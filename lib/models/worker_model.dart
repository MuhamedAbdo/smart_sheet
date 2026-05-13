import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
        // We can't return a HiveList without a box.
        // As a last resort, throw a more helpful error or return a nullable.
        // For now, let's try to open it or at least handle the crash in toJson.
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

  Worker({
    this.id,
    required this.name,
    required this.phone,
    required this.job,
    List<WorkerAction>? actions,
    this.hasMedicalInsurance = false,
    this.factoryId,
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
    );
  }
}
