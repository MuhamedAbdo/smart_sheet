import 'package:hive/hive.dart';

part 'flexo_machine.g.dart';

@HiveType(typeId: 15)
class FlexoMachine extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  FlexoMachine({
    required this.id,
    required this.name,
  });
}
