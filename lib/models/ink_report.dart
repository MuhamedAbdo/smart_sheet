// lib/src/models/ink_report.dart

import 'package:hive_flutter/hive_flutter.dart';

part 'ink_report.g.dart';

@HiveType(typeId: 3)
class InkReport extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String date;

  @HiveField(2)
  final String clientName;

  @HiveField(3)
  final String product;

  @HiveField(4)
  final String productCode;

  @HiveField(5)
  final Map<String, dynamic> dimensions;

  @HiveField(6)
  final List<Map<String, double>> colors;

  @HiveField(7)
  final int quantity;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final List<String> imageUrls;

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
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'client_name': clientName,
      'product': product,
      'product_code': productCode,
      'dimensions': dimensions,
      'colors': colors.map((c) => c).toList(),
      'quantity': quantity,
      'notes': notes,
      'image_urls': imageUrls,
    };
  }

  factory InkReport.fromJson(Map<String, dynamic> map) {
    List<dynamic> colorsList = map['colors'] ?? [];
    List<dynamic> imagesList = map['image_urls'] ?? [];

    List<Map<String, double>> parsedColors = colorsList
        .map<Map<String, double>>((item) => Map<String, double>.from(
            (item as Map)
                .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))))
        .toList();

    List<String> parsedImages =
        imagesList.map((item) => item.toString()).toList();

    return InkReport(
      id: map['id'] ?? '',
      date: map['date'] ?? '',
      clientName: map['client_name'] ?? '',
      product: map['product'] ?? '',
      productCode: map['product_code'] ?? '',
      dimensions: map['dimensions'] is Map
          ? Map<String, dynamic>.from(map['dimensions'])
          : {},
      colors: parsedColors,
      quantity: map['quantity'] is int
          ? map['quantity']
          : int.tryParse(map['quantity'].toString()) ?? 0,
      notes: map['notes'],
      imageUrls: parsedImages,
    );
  }
}
