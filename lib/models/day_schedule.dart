// lib/models/day_schedule.dart
//
// موديل جدول الأيام — يخزّن إعدادات كل يوم من أيام الأسبوع:
// • هل اليوم عمل أم عطلة رسمية؟
// • ما وقت بداية ونهاية الوردية لهذا اليوم تحديداً؟
//
// يُحفظ في Hive Box مسمى 'factory_schedule' بمفتاح = dayName.

import 'package:hive_flutter/hive_flutter.dart';

part 'day_schedule.g.dart';

@HiveType(typeId: 18)
class DaySchedule extends HiveObject {
  /// اسم اليوم بالإنجليزية (Saturday, Sunday, … Friday)
  @HiveField(0)
  String dayName;

  /// true = يوم عمل عادي / false = عطلة رسمية أسبوعية
  @HiveField(1)
  bool isWorkingDay;

  /// وقت بداية الوردية لهذا اليوم، مثال: '08:00 AM'
  @HiveField(2)
  String shiftStart;

  /// وقت نهاية الوردية لهذا اليوم، مثال: '05:00 PM'
  @HiveField(3)
  String shiftEnd;

  DaySchedule({
    required this.dayName,
    required this.isWorkingDay,
    required this.shiftStart,
    required this.shiftEnd,
  });

  // ─── أسماء الأيام المرتبة من الأحد إلى السبت ───────────────────────────
  static const List<String> orderedDays = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  /// الأسماء العربية المقابلة للأيام
  static const Map<String, String> arabicNames = {
    'Saturday': 'السبت',
    'Sunday': 'الأحد',
    'Monday': 'الاثنين',
    'Tuesday': 'الثلاثاء',
    'Wednesday': 'الأربعاء',
    'Thursday': 'الخميس',
    'Friday': 'الجمعة',
  };

  /// الإعداد الافتراضي للمصنع (الجمعة عطلة، الخميس وردية أقصر)
  static List<DaySchedule> get defaults => [
        DaySchedule(
            dayName: 'Saturday',
            isWorkingDay: true,
            shiftStart: '08:00 AM',
            shiftEnd: '05:00 PM'),
        DaySchedule(
            dayName: 'Sunday',
            isWorkingDay: true,
            shiftStart: '08:00 AM',
            shiftEnd: '05:00 PM'),
        DaySchedule(
            dayName: 'Monday',
            isWorkingDay: true,
            shiftStart: '08:00 AM',
            shiftEnd: '05:00 PM'),
        DaySchedule(
            dayName: 'Tuesday',
            isWorkingDay: true,
            shiftStart: '08:00 AM',
            shiftEnd: '05:00 PM'),
        DaySchedule(
            dayName: 'Wednesday',
            isWorkingDay: true,
            shiftStart: '08:00 AM',
            shiftEnd: '05:00 PM'),
        DaySchedule(
            dayName: 'Thursday',
            isWorkingDay: true,
            shiftStart: '08:00 AM',
            shiftEnd: '02:00 PM'),
        DaySchedule(
            dayName: 'Friday',
            isWorkingDay: false,
            shiftStart: '08:00 AM',
            shiftEnd: '05:00 PM'),
      ];

  // ─── تحويل من/إلى JSON لدعم المزامنة مستقبلاً ──────────────────────────
  Map<String, dynamic> toJson() => {
        'day_name': dayName,
        'is_working_day': isWorkingDay,
        'shift_start': shiftStart,
        'shift_end': shiftEnd,
      };

  factory DaySchedule.fromJson(Map<String, dynamic> map) => DaySchedule(
        dayName: map['day_name'] ?? 'Saturday',
        isWorkingDay: map['is_working_day'] ?? true,
        shiftStart: map['shift_start'] ?? '08:00 AM',
        shiftEnd: map['shift_end'] ?? '05:00 PM',
      );

  /// اسم اليوم العربي
  String get arabicName => arabicNames[dayName] ?? dayName;
}
