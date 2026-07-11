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

  FlexoMachine({
    required this.id,
    required this.name,
    this.department = 'flexo',
  });

  factory FlexoMachine.fromJson(Map<String, dynamic> json) {
    return FlexoMachine(
      id: json['sync_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      department: json['department']?.toString() ?? 'flexo',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'department': department,
    };
  }

  factory FlexoMachine.fromMap(Map<String, dynamic> map) =>
      FlexoMachine.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}
