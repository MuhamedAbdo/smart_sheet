import 'package:hive/hive.dart';

part 'flexo_machine.g.dart';

@HiveType(typeId: 15)
class FlexoMachine extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2, defaultValue: 'flexo')
  final String department;

  @HiveField(3)
  final String? dbId;

  FlexoMachine({
    required this.id,
    required this.name,
    this.department = 'flexo',
    this.dbId,
  });

  factory FlexoMachine.fromJson(Map<String, dynamic> json) {
    return FlexoMachine(
      id: json['sync_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      department: json['department']?.toString() ?? 'flexo',
      dbId: json['id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'sync_id': id,
      'name': name,
      'department': department,
    };
    if (id.isNotEmpty && !id.contains('_machine_')) {
      map['id'] = id;
    }
    return map;
  }

  factory FlexoMachine.fromMap(Map<String, dynamic> map) =>
      FlexoMachine.fromJson(map);
  Map<String, dynamic> toMap() => toJson();

  /// جلب ماكينات قسم معين مع تطبيق المنطق الافتراضي (Fallback Logic) لخط الإنتاج
  /// إذا كانت قائمة ماكينات خط الإنتاج فارغة، يتم إنشاء ماكينة وهمية باسم 'خط الإنتاج' للـ UI
  static List<FlexoMachine> getMachinesForDepartment(String department) {
    if (!Hive.isBoxOpen('flexo_machines')) {
      if (department == 'production_line') {
        return [
          FlexoMachine(
            id: 'dummy_production_line',
            name: 'خط الإنتاج',
            department: 'production_line',
          )
        ];
      }
      return [];
    }

    final box = Hive.box<FlexoMachine>('flexo_machines');
    final machines = box.values.where((m) {
      final mDept = m.department;
      if (department == 'flexo') {
        return mDept == 'flexo' || mDept.isEmpty;
      }
      return mDept == department;
    }).toList();

    // Fallback Logic: إذا كانت قائمة ماكينات خط الإنتاج فارغة، أنشئ ماكينة وهمية للواجهة
    if (department == 'production_line' && machines.isEmpty) {
      return [
        FlexoMachine(
          id: 'dummy_production_line',
          name: 'خط الإنتاج',
          department: 'production_line',
        )
      ];
    }

    return machines;
  }
}
