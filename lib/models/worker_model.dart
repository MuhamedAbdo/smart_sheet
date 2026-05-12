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
  late HiveList<WorkerAction> actions;

  @HiveField(4)
  late bool hasMedicalInsurance;

  @HiveField(5)
  late String? factoryId;

  Worker({
    required this.name,
    required this.phone,
    required this.job,
    List<WorkerAction>? actions,
    this.hasMedicalInsurance = false,
    this.factoryId,
  }) {
    _initializeActions(actions);
  }

  void _initializeActions(List<WorkerAction>? actions) {
    if (Hive.isBoxOpen('worker_actions')) {
      try {
        final box = Hive.box<WorkerAction>('worker_actions');
        // ignore: experimental_member_use
        this.actions = HiveList(box, objects: actions ?? []);
      } catch (e) {
        debugPrint("⚠️ Error initializing HiveList: $e");
        // Create empty list as fallback
        // ignore: experimental_member_use
        this.actions = HiveList(Hive.box<WorkerAction>('worker_actions'));
      }
    } else {
      // This should not happen if boxes are opened in correct order
      debugPrint(
          "⚠️ Critical: worker_actions box is not open during Worker initialization");
      // Try to open it as fallback
      try {
        // ignore: experimental_member_use
        this.actions = HiveList(Hive.box<WorkerAction>('worker_actions'));
      } catch (e) {
        debugPrint("❌ Failed to create HiveList fallback: $e");
      }
    }
  }

  void reconnectActionsBox() {
    if (Hive.isBoxOpen('worker_actions')) {
      try {
        final box = Hive.box<WorkerAction>('worker_actions');
        // ignore: experimental_member_use
        actions = HiveList(box, objects: actions.toList());
      } catch (e) {
        debugPrint("⚠️ Error reconnecting actions box: $e");
      }
    } else {
      debugPrint("⚠️ Cannot reconnect: worker_actions box is not open");
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
    return {
      'name': name,
      'phone': phone,
      'job': job,
      'has_medical_insurance': hasMedicalInsurance,
      'factory_id': factoryId,
      // ignore: experimental_member_use
      'actions': actions.map((action) => action.toJson()).toList(),
    };
  }

  factory Worker.fromJson(Map<String, dynamic> map) {
    List<dynamic> actionsList = map['actions'] ?? [];
    List<WorkerAction> actions =
        actionsList.map((a) => WorkerAction.fromJson(a)).toList();

    return Worker(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      job: map['job'] ?? '',
      actions: actions,
      hasMedicalInsurance: map['has_medical_insurance'] ?? false,
      factoryId: map['factory_id'],
    );
  }
}
