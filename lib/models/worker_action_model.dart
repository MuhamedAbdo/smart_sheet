// lib/src/models/worker_action_model.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'worker_action_model.g.dart';

@HiveType(typeId: 11)
class WorkerAction extends HiveObject {
  @HiveField(0)
  String type;

  @HiveField(1)
  double? days;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String? notes;

  @HiveField(4)
  DateTime? returnDate;

  @HiveField(5)
  final int? startTimeHour;
  @HiveField(6)
  final int? startTimeMinute;
  @HiveField(7)
  int? endTimeHour;
  @HiveField(8)
  int? endTimeMinute;

  @HiveField(9)
  final double? amount; // للمكافأة/الجزاء (جنيه)

  @HiveField(10)
  final double? bonusDays; // للمكافأة/الجزاء (أيام)

  @HiveField(11)
  final String? factoryId;

  WorkerAction({
    required this.type,
    this.days,
    required this.date,
    this.notes,
    this.returnDate,
    this.startTimeHour,
    this.startTimeMinute,
    this.endTimeHour,
    this.endTimeMinute,
    this.amount,
    this.bonusDays,
    this.factoryId,
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

    final startDateTime = DateTime(
        date.year, date.month, date.day, startTime!.hour, startTime!.minute);
    
    final endBaseDate = returnDate ?? date;
    final endDateTime = DateTime(endBaseDate.year, endBaseDate.month,
        endBaseDate.day, endTime!.hour, endTime!.minute);

    final diff = endDateTime.difference(startDateTime);
    if (diff.isNegative || diff.inMinutes == 0) return "0 دقيقة";

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    final parts = <String>[];
    if (days > 0) parts.add("$days يوم");
    if (hours > 0) parts.add("$hours ساعة");
    if (minutes > 0) parts.add("$minutes دقيقة");

    return parts.join(" و ");
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
      'factory_id': factoryId,
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
      factoryId: map['factory_id'],
    );
  }
}
