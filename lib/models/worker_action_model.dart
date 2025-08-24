import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'worker_action_model.g.dart';

@HiveType(typeId: 2)
class WorkerAction extends HiveObject {
  @HiveField(0)
  final String type; // إجازة، غياب، مكافئة، جزاء، إذن، تأمين صحي

  @HiveField(1)
  final double days;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String? notes;

  @HiveField(4)
  final DateTime? returnDate; // تاريخ العودة (للإجازة)

  @HiveField(5)
  final int? startTimeHour; // ⏰ وقت الخروج (ساعة)

  @HiveField(6)
  final int? startTimeMinute; // ⏰ وقت الخروج (دقيقة)

  @HiveField(7)
  final int? endTimeHour; // 🔙 وقت العودة (ساعة)

  @HiveField(8)
  final int? endTimeMinute; // 🔙 وقت العودة (دقيقة)

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
  });

  TimeOfDay? get startTime {
    if (startTimeHour == null || startTimeMinute == null) return null;
    return TimeOfDay(hour: startTimeHour!, minute: startTimeMinute!);
  }

  TimeOfDay? get endTime {
    if (endTimeHour == null || endTimeMinute == null) return null;
    return TimeOfDay(hour: endTimeHour!, minute: endTimeMinute!);
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
      startTimeHour: map['start_time_hour'],
      startTimeMinute: map['start_time_minute'],
      endTimeHour: map['end_time_hour'],
      endTimeMinute: map['end_time_minute'],
    );
  }
}
