import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'worker_action_model.dart';
import 'package:uuid/uuid.dart';

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

  @HiveField(6)
  late String? syncId; // UUID فريد لتعريف العامل عبر الأجهزة

  Worker({
    required this.name,
    required this.phone,
    required this.job,
    List<WorkerAction>? actions,
    this.hasMedicalInsurance = false,
    this.factoryId,
    String? syncId,
  }) : syncId = syncId ?? const Uuid().v4() {
    if (Hive.isBoxOpen('worker_actions')) {
      final box = Hive.box<WorkerAction>('worker_actions');
      // ignore: experimental_member_use
      this.actions = HiveList(box, objects: actions ?? []);
    } else {
      // تجنب حدوث خطأ إذا لم يفتح الصندوق بعد
      debugPrint("⚠️ Warning: worker_actions box is not open yet.");
    }
  }

  void reconnectActionsBox() {
    if (Hive.isBoxOpen('worker_actions')) {
      final box = Hive.box<WorkerAction>('worker_actions');
      // ignore: experimental_member_use
      actions = HiveList(box, objects: actions.toList());
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'sync_id': syncId ?? const Uuid().v4(),
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
      syncId: map['sync_id']?.toString(),
    );
  }
}
