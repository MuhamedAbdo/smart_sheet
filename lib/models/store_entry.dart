// lib/src/models/store_entry.dart

import 'package:hive_flutter/hive_flutter.dart';

part 'store_entry.g.dart';

@HiveType(typeId: 4)
class StoreEntry extends HiveObject {
  @HiveField(0)
  final String date;

  @HiveField(1)
  final String type;

  @HiveField(2)
  final String unit;

  @HiveField(3)
  final int count;

  @HiveField(4)
  final String? notes;

  StoreEntry({
    required this.date,
    required this.type,
    required this.unit,
    required this.count,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'type': type,
      'unit': unit,
      'count': count,
      'notes': notes,
    };
  }

  factory StoreEntry.fromJson(Map<String, dynamic> map) {
    return StoreEntry(
      date: map['date'] ?? '',
      type: map['type'] ?? '',
      unit: map['unit'] ?? '',
      count: map['count'] is int
          ? map['count']
          : int.tryParse(map['count'].toString()) ?? 0,
      notes: map['notes'],
    );
  }
}
