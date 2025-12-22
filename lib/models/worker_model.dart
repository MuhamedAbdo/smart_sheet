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
  late HiveList<WorkerAction> actions;

  @HiveField(4)
  late bool hasMedicalInsurance;

  Worker({
    required this.name,
    required this.phone,
    required this.job,
    List<WorkerAction>? actions, // جعلناها اختيارية
    this.hasMedicalInsurance = false,
  }) {
    // تم نقل تهيئة الـ HiveList لضمان عدم استدعاء الصندوق قبل فتحه
    final box = Hive.isBoxOpen('worker_actions')
        ? Hive.box<WorkerAction>('worker_actions')
        : null;

    if (box != null) {
      this.actions = HiveList(box, objects: actions ?? []);
    }
  }

  // دالة لإعادة الربط يدوياً إذا لزم الأمر
  void reconnectActionsBox() {
    if (Hive.isBoxOpen('worker_actions')) {
      actions = HiveList(Hive.box<WorkerAction>('worker_actions'),
          objects: actions.toList());
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'job': job,
      'has_medical_insurance': hasMedicalInsurance,
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
    );
  }
}
