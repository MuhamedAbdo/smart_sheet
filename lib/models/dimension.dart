import 'package:hive_flutter/hive_flutter.dart';

part 'dimension.g.dart';

@HiveType(typeId: 5)
class Dimension extends HiveObject {
  @HiveField(0)
  late double length;

  @HiveField(1)
  late double width;

  @HiveField(2)
  late double height;

  Dimension({required this.length, required this.width, required this.height});

  Map<String, dynamic> toMap() {
    return {
      'length': length,
      'width': width,
      'height': height,
    };
  }

  factory Dimension.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return Dimension(length: 0, width: 0, height: 0);
    }

    return Dimension(
      length: (map['length'] is num)
          ? (map['length'] as num).toDouble()
          : double.tryParse(map['length']?.toString() ?? '') ?? 0.0,
      width: (map['width'] is num)
          ? (map['width'] as num).toDouble()
          : double.tryParse(map['width']?.toString() ?? '') ?? 0.0,
      height: (map['height'] is num)
          ? (map['height'] as num).toDouble()
          : double.tryParse(map['height']?.toString() ?? '') ?? 0.0,
    );
  }
}
