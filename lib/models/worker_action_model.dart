// lib/src/models/worker_action_model.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'worker_action_model.g.dart';

@HiveType(typeId: 11)
class WorkerAction extends HiveObject {
  @HiveField(0)
  final String type;

  @HiveField(1)
  final double days;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String? notes;

  @HiveField(4)
  final DateTime? returnDate;

  @HiveField(5)
  final int? startTimeHour;
  @HiveField(6)
  final int? startTimeMinute;
  @HiveField(7)
  final int? endTimeHour;
  @HiveField(8)
  final int? endTimeMinute;

  @HiveField(9)
  final double? amount; // للمكافأة/الجزاء (جنيه)

  @HiveField(10)
  final double? bonusDays; // للمكافأة/الجزاء (أيام)

  WorkerAction({
    required this.type,
    required this.days,
    required this.date,
    this.notes,
    this.returnDate,
    this.startTimeHour,
    this.startTimeMinute,
    this.endTimeHour,
    this.endTimeMinute,
    this.amount,
    this.bonusDays,
  });

  TimeOfDay? get startTime {
    if (startTimeHour == null || startTimeMinute == null) return null;
    return TimeOfDay(hour: startTimeHour!, minute: startTimeMinute!);
  }

  TimeOfDay? get endTime {
    if (endTimeHour == null || endTimeMinute == null) return null;
    return TimeOfDay(hour: endTimeHour!, minute: endTimeMinute!);
  }

  String? get duration {
    if (startTime == null || endTime == null) return null;
    final startMin = startTime!.hour * 60 + startTime!.minute;
    final endMin = endTime!.hour * 60 + endTime!.minute;
    final diff = endMin - startMin;
    if (diff <= 0) return "00:00";
    final h = (diff ~/ 60).toString().padLeft(2, '0');
    final m = (diff % 60).toString().padLeft(2, '0');
    return "$h:$m";
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'days': days,
      'date': date.toIso8601String(),
      'notes': notes,
      'return_date': returnDate?.toIso8601String(),
      'start_time_hour': startTimeHour,
      'start_time_minute': startTimeMinute,
      'end_time_hour': endTimeHour,
      'end_time_minute': endTimeMinute,
      'amount': amount,
      'bonus_days': bonusDays,
    };
  }

  factory WorkerAction.fromJson(Map<String, dynamic> map) {
    return WorkerAction(
      type: map['type'] ?? 'إجازة',
      days: (map['days'] as num?)?.toDouble() ?? 1.0,
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      notes: map['notes'],
      returnDate: map['return_date'] != null
          ? DateTime.tryParse(map['return_date'])
          : null,
      startTimeHour: map['start_time_hour'],
      startTimeMinute: map['start_time_minute'],
      endTimeHour: map['end_time_hour'],
      endTimeMinute: map['end_time_minute'],
      amount: map['amount'] is num ? (map['amount'] as num).toDouble() : null,
      bonusDays: map['bonus_days'] is num
          ? (map['bonus_days'] as num).toDouble()
          : null,
    );
  }
}
