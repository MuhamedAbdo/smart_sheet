// lib/src/models/finished_product_model.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'finished_product_model.g.dart';

@HiveType(typeId: 5)
class FinishedProduct extends HiveObject {
  @HiveField(0)
  String? clientName;

  @HiveField(1)
  String? productName;

  @HiveField(2)
  String? operationOrder;

  @HiveField(3)
  String? productCode;

  @HiveField(4)
  double? length;

  @HiveField(5)
  double? width;

  @HiveField(6)
  double? height;

  @HiveField(7)
  int? count;

  @HiveField(8)
  List<String>? imagePaths;

  @HiveField(9)
  String? technician;

  @HiveField(10)
  String? notes;

  @HiveField(11)
  String? dateBacker;

  @HiveField(12)
  String? factoryId;

  @HiveField(13)
  String? id; // تم الإضافة للمزامنة

  FinishedProduct({
    this.clientName,
    this.productName,
    this.operationOrder,
    this.productCode,
    this.length,
    this.width,
    this.height,
    this.count,
    this.imagePaths,
    this.technician,
    this.notes,
    this.dateBacker,
    this.factoryId,
    this.id,
  }) {
    id ??= const Uuid().v4(); // توليد معرف تلقائي لو لم يوجد
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sync_id': id,
      'client_name': clientName,
      'product_name': productName,
      'operation_order': operationOrder,
      'product_code': productCode,
      'length': length,
      'width': width,
      'height': height,
      'count': count,
      'image_paths': imagePaths,
      'technician': technician,
      'notes': notes,
      'date_backer': dateBacker,
      'factory_id': factoryId,
    };
  }

  factory FinishedProduct.fromJson(Map<String, dynamic> map) {
    return FinishedProduct(
      id: map['sync_id'] ?? map['id'],
      clientName: map['client_name'] ?? map['clientName'],
      productName: map['product_name'] ?? map['productName'],
      operationOrder: map['operation_order'] ?? map['operationOrder'],
      productCode: map['product_code'] ?? map['productCode'],
      length: (map['length'] as num?)?.toDouble(),
      width: (map['width'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      count: map['count'] is int
          ? map['count']
          : int.tryParse(map['count'].toString()) ?? 0,
      imagePaths:
          List<String>.from(map['image_paths'] ?? map['imagePaths'] ?? []),
      technician: map['technician'],
      notes: map['notes'],
      dateBacker: map['date_backer'] ?? map['dateBacker'],
      factoryId: map['factory_id'] ?? map['factoryId'],
    );
  }
}
