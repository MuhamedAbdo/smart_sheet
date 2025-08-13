// lib/src/models/worker_action_model.dart

import 'package:hive_flutter/hive_flutter.dart';

part 'worker_action_model.g.dart';

@HiveType(typeId: 2)
class WorkerAction extends HiveObject {
  @HiveField(0)
  final String type; // إجازة، غياب، مكافئة، جزاء...

  @HiveField(1)
  final double days;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String? notes;

  @HiveField(4)
  final DateTime? returnDate; // تاريخ العودة (في حالة الإجازة)

  WorkerAction({
    required this.type,
    required this.days,
    required this.date,
    this.notes,
    this.returnDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'days': days,
      'date': date.toIso8601String(),
      'notes': notes,
      'return_date': returnDate?.toIso8601String(),
    };
  }

  factory WorkerAction.fromJson(Map<String, dynamic> map) {
    return WorkerAction(
      type: map['type'] ?? '',
      days: (map['days'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      notes: map['notes'],
      returnDate: map['return_date'] != null
          ? DateTime.parse(map['return_date'])
          : null,
    );
  }
}
