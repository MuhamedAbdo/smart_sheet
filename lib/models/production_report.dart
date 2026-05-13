// lib/models/production_report.dart

import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';

part 'production_report.g.dart';

@HiveType(typeId: 3)
class ProductionReport extends HiveObject {
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
  final String? orderNumber;

  @HiveField(10)
  final String? startTime;

  @HiveField(11)
  final String? endTime;

  @HiveField(12)
  final int? lineWaste;

  @HiveField(13)
  final int? printWaste;

  @HiveField(14)
  final String? downtimeStart;

  @HiveField(15)
  final String? downtimeEnd;

  @HiveField(16)
  final String? machineName;

  @HiveField(17)
  final String? technicianName;

  @HiveField(18)
  final String? factoryId;

  ProductionReport({
    String? id,
    required this.date,
    required this.clientName,
    required this.product,
    required this.productCode,
    required this.dimensions,
    required this.colors,
    required this.quantity,
    this.notes,
    this.orderNumber,
    this.startTime,
    this.endTime,
    this.lineWaste,
    this.printWaste,
    this.downtimeStart,
    this.downtimeEnd,
    this.machineName,
    this.technicianName,
    this.factoryId,
  }) : id = (id == null || !id.contains('-')) ? _generateV4Uuid() : id;

  static String _generateV4Uuid() {
    final Random random = Random();
    final List<int> values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant 10
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'client_name': clientName,
      'product': product,
      'product_code': productCode,
      'dimensions': dimensions,
      'colors': colors,
      'quantity': quantity,
      'notes': notes,
      'order_number': orderNumber,
      'start_time': startTime,
      'end_time': endTime,
      'line_waste': lineWaste,
      'print_waste': printWaste,
      'downtime_start': downtimeStart,
      'downtime_end': downtimeEnd,
      'machine_name': machineName,
      'technician_name': technicianName,
      'factory_id': factoryId,
    };
  }

  factory ProductionReport.fromJson(Map<String, dynamic> map) {
    List<dynamic> colorsList = map['colors'] ?? [];

    List<Map<String, double>> parsedColors = colorsList
        .map<Map<String, double>>((item) => Map<String, double>.from(
            (item as Map)
                .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))))
        .toList();

    return ProductionReport(
      id: map['id'] ?? '',
      date: map['date'] ?? '',
      clientName: map['clientName'] ?? map['client_name'] ?? '',
      product: map['product'] ?? '',
      productCode: map['productCode'] ?? map['product_code'] ?? '',
      dimensions: map['dimensions'] is Map
          ? Map<String, dynamic>.from(map['dimensions'])
          : {},
      colors: parsedColors,
      quantity: map['quantity'] is int
          ? map['quantity']
          : int.tryParse(map['quantity'].toString()) ?? 0,
      notes: map['notes'],
      orderNumber: map['orderNumber'] ?? map['order_number'],
      startTime: map['startTime'] ?? map['start_time'],
      endTime: map['endTime'] ?? map['end_time'],
      lineWaste: map['lineWaste'] is int
          ? map['lineWaste']
          : (map['line_waste'] is int ? map['line_waste'] : int.tryParse(map['line_waste']?.toString() ?? '')),
      printWaste: map['printWaste'] is int
          ? map['printWaste']
          : (map['print_waste'] is int ? map['print_waste'] : int.tryParse(map['print_waste']?.toString() ?? '')),
      downtimeStart: map['downtimeStart'] ?? map['downtime_start'],
      downtimeEnd: map['downtimeEnd'] ?? map['downtime_end'],
      machineName: map['machineName'] ?? map['machine_name'],
      technicianName: map['technicianName'] ?? map['technician_name'],
      factoryId: map['factoryId'] ?? map['factory_id'],
    );
  }
}
