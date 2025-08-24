import 'package:hive_flutter/hive_flutter.dart';

part 'color_quantity.g.dart';

@HiveType(typeId: 6)
class ColorQuantity extends HiveObject {
  @HiveField(0)
  late String color;

  @HiveField(1)
  late double quantity;

  ColorQuantity({required this.color, required this.quantity});

  Map<String, dynamic> toMap() {
    return {
      'color': color,
      'quantity': quantity,
    };
  }

  factory ColorQuantity.fromMap(Map<dynamic, dynamic> map) {
    return ColorQuantity(
      color: map['color']?.toString() ?? '',
      quantity: (map['quantity'] is num)
          ? (map['quantity'] as num).toDouble()
          : double.tryParse(map['quantity']?.toString() ?? '') ?? 0.0,
    );
  }
}
