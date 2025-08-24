// lib/src/models/ink_report.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'dimension.dart';
import 'color_quantity.dart';

part 'ink_report.g.dart';

@HiveType(typeId: 3)
class InkReport extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String date;

  @HiveField(2)
  late String clientName;

  @HiveField(3)
  late String product;

  @HiveField(4)
  late String productCode;

  @HiveField(5)
  late Dimension dimensions;

  @HiveField(6)
  late List<ColorQuantity> colors;

  @HiveField(7)
  late int quantity;

  @HiveField(8)
  late String? notes;

  @HiveField(9)
  late List<String> imageUrls; // للسحابة

  @HiveField(10)
  late List<String> imagePaths; // للجهاز المحلي

  InkReport({
    required this.id,
    required this.date,
    required this.clientName,
    required this.product,
    required this.productCode,
    required this.dimensions,
    required this.colors,
    required this.quantity,
    this.notes,
    required this.imageUrls,
    required this.imagePaths,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'client_name': clientName,
      'product': product,
      'product_code': productCode,
      'dimensions': dimensions.toMap(),
      'colors': colors.map((c) => c.toMap()).toList(),
      'quantity': quantity,
      'notes': notes,
      'image_urls': imageUrls,
      'imagePaths': imagePaths,
    };
  }

  factory InkReport.fromJson(Map<String, dynamic> map) {
    // 🟡 Debugging print
    print("⚠️ InkReport.fromJson input: $map");

    return InkReport(
      id: map['id']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      clientName: map['client_name']?.toString() ?? '',
      product: map['product']?.toString() ?? '',
      productCode: map['product_code']?.toString() ?? '',
      dimensions: (map['dimensions'] is Map<String, dynamic>)
          ? Dimension.fromMap(Map<String, dynamic>.from(map['dimensions']))
          : Dimension(length: 0, width: 0, height: 0),
      colors: (map['colors'] is List)
          ? (map['colors'] as List)
              .whereType<Map>()
              .map((c) => ColorQuantity.fromMap(Map<String, dynamic>.from(c)))
              .toList()
          : <ColorQuantity>[],
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      notes: map['notes']?.toString(),
      imageUrls: (map['image_urls'] is List)
          ? (map['image_urls'] as List).map((e) => e.toString()).toList()
          : <String>[],
      imagePaths: (map['imagePaths'] is List)
          ? (map['imagePaths'] as List).map((e) => e.toString()).toList()
          : <String>[],
    );
  }
}
