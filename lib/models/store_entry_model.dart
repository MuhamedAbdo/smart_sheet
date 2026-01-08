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

  StoreEntry({
    required this.date,
    required this.product,
    required this.unit,
    required this.quantity,
    this.notes,
  });
}
