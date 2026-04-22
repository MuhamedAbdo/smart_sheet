// lib/src/models/store_entry_model.dart

import 'package:hive/hive.dart';

part 'store_entry_model.g.dart';

@HiveType(typeId: 4)
class StoreEntry {
  @HiveField(0)
  final String date;

  @HiveField(1)
  final String
      product; // ← تم تغييره من 'type' إلى 'product' ليتوافق مع الواجهة

  @HiveField(2)
  final String unit;

  @HiveField(3)
  final int quantity;

  @HiveField(4)
  final String? notes;

  @HiveField(5)
  final String? factoryId;

  StoreEntry({
    required this.date,
    required this.product,
    required this.unit,
    required this.quantity,
    this.notes,
    this.factoryId,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'product': product,
      'unit': unit,
      'quantity': quantity,
      'notes': notes,
      'factory_id': factoryId,
    };
  }

  factory StoreEntry.fromJson(Map<String, dynamic> map) {
    return StoreEntry(
      date: map['date'] ?? '',
      product: map['product'] ?? '',
      unit: map['unit'] ?? '',
      quantity: map['quantity'] ?? 0,
      notes: map['notes'],
      factoryId: map['factory_id'],
    );
  }
}
