// lib/src/models/worker_action_model.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'worker_action_model.g.dart';

@HiveType(typeId: 11)
class WorkerAction extends HiveObject {
  @HiveField(0)
  String type;

  @HiveField(12)
  String? id;

  @HiveField(1)
  double? days;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  String? notes;

  @HiveField(4)
  DateTime? returnDate;

  @HiveField(5)
  int? startTimeHour;
  @HiveField(6)
  int? startTimeMinute;
  @HiveField(7)
  int? endTimeHour;
  @HiveField(8)
  int? endTimeMinute;

  @HiveField(9)
  double? amount; // للمكافأة/الجزاء (جنيه)

  @HiveField(10)
  double? bonusDays; // للمكافأة/الجزاء (أيام)

  @HiveField(11)
  String? factoryId;

  @HiveField(13)
  String? workerName;

  @HiveField(14)
  String? workerId;

  @HiveField(15)
  String? createdByDeviceId;

  @HiveField(16)
  String? shiftName;

  /// تاريخ العودة المتوقع (اختياري) — يُحدَّد مسبقاً عند إنشاء الإجازة
  /// يُستخدم للتنبيه البصري عند التأخر عن العودة
  @HiveField(17)
  DateTime? expectedReturnDate;

  WorkerAction({
    this.id,
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
    this.workerName,
    this.workerId,
    this.createdByDeviceId,
    this.shiftName,
    this.expectedReturnDate,
  }) {
    // Generate valid UUID v4 if not provided or invalid (fixes 22P02 error in Supabase)
    if (id == null || !id!.contains('-')) {
      id = _generateV4Uuid();
    }
  }

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

  /// Returns true if this action is an **ongoing** live session right now.
  /// An action is active only when:
  ///   1. It is a live-type action (leave / absence / permission / insurance)
  ///   2. No returnDate has been registered yet
  ///   3. The startDate (date) is today or in the past — i.e. the worker has
  ///      already departed. A *future* startDate means the leave is scheduled
  ///      but hasn't started yet, so the worker is still present.
  bool get isActive {
    const liveTypes = ['إجازة', 'أجازة عارضة', 'غياب', 'إذن', 'تأمين صحي'];
    if (!liveTypes.contains(type) || returnDate != null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(date.year, date.month, date.day);

    // Scheduled leave (future startDate) → worker is still present
    if (startDay.isAfter(today)) return false;

    // Consider actions older than 30 days as inactive (Presence assumed)
    final diff = today.difference(startDay).inDays;
    return diff <= 30;
  }

  /// Returns true when the leave is scheduled for a future date
  /// (startDate > today) and no returnDate has been set yet.
  bool get isScheduled {
    const liveTypes = ['إجازة', 'أجازة عارضة', 'غياب'];
    if (!liveTypes.contains(type) || returnDate != null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(date.year, date.month, date.day);
    return startDay.isAfter(today);
  }

  /// Returns true if this action type is time-based (permission/insurance)
  bool get isTimeBased => type == 'إذن' || type == 'تأمين صحي';

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
    // الضمان النهائي: لا ترسل id كـ null أبداً
    final finalId = (id != null && id!.isNotEmpty) ? id : _generateV4Uuid();
    return {
      'id': finalId,
      'sync_id': finalId, // Alias for compatibility with some schemas
      'type': type,
      'days': days,
      'date': date.toIso8601String(),
      'notes': notes,
      'return_date': returnDate?.toIso8601String(),
      'expected_return_date': expectedReturnDate?.toIso8601String(),
      'start_time_hour': startTimeHour,
      'start_time_minute': startTimeMinute,
      'end_time_hour': endTimeHour,
      'end_time_minute': endTimeMinute,
      'amount': amount,
      'bonus_days': bonusDays,
      'factory_id': factoryId,
      'worker_name': workerName,
      'worker_id': workerId,
      'created_by_device_id': createdByDeviceId,
      'shift_name': shiftName,
    };
  }

  factory WorkerAction.fromJson(Map<String, dynamic> map) {
    return WorkerAction(
      id: (map['sync_id'] ?? map['id'])?.toString(),
      type: map['type'] ?? 'إجازة',
      days: (map['days'] as num?)?.toDouble() ?? 1.0,
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      notes: map['notes'],
      returnDate: map['return_date'] != null
          ? DateTime.tryParse(map['return_date'])
          : null,
      expectedReturnDate: map['expected_return_date'] != null
          ? DateTime.tryParse(map['expected_return_date'])
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
      workerName: map['worker_name'],
      workerId: (map['worker_id'] ?? map['workerId'])?.toString(),
      createdByDeviceId: map['created_by_device_id']?.toString(),
      shiftName: map['shift_name'],
    );
  }

  String? get syncId => id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkerAction && id != null && id == other.id;

  @override
  int get hashCode => id?.hashCode ?? 0;
}
