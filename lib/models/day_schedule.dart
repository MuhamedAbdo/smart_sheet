// lib/models/day_schedule.dart
//
// موديل جدول الأيام — يخزّن إعدادات كل يوم من أيام الأسبوع:
// • هل اليوم عمل أم عطلة رسمية؟
// • ما وقت بداية ونهاية الوردية لهذا اليوم تحديداً؟
//
// يُحفظ في Hive Box مسمى 'factory_schedule' بمفتاح = dayName.

import 'package:hive_flutter/hive_flutter.dart';

part 'day_schedule.g.dart';

@HiveType(typeId: 26)
class Shift extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String startTime;

  @HiveField(2)
  String endTime;

  Shift({
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
      };

  factory Shift.fromJson(Map<String, dynamic> map) => Shift(
        name: map['name'] ?? 'الوردية الأولى',
        startTime: map['start_time'] ?? '08:00 AM',
        endTime: map['end_time'] ?? '05:00 PM',
      );
}

@HiveType(typeId: 18)
class DaySchedule extends HiveObject {
  /// اسم اليوم بالإنجليزية (Saturday, Sunday, … Friday)
  @HiveField(0)
  String dayName;

  /// true = يوم عمل عادي / false = عطلة رسمية أسبوعية
  @HiveField(1)
  bool isWorkingDay;

  /// وقت بداية الوردية (الافتراضية)
  @HiveField(2)
  String shiftStart;

  /// وقت نهاية الوردية (الافتراضية)
  @HiveField(3)
  String shiftEnd;

  /// قائمة الورديات المتعددة لهذا اليوم (اختياري للحفاظ على التوافقية)
  @HiveField(4)
  List<Shift>? shifts;

  /// قائمة أسماء الورديات كحل مبدئي أسهل
  @HiveField(5)
  List<String>? shiftNames;

  DaySchedule({
    required this.dayName,
    required this.isWorkingDay,
    required this.shiftStart,
    required this.shiftEnd,
    this.shifts,
    this.shiftNames,
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

  /// الإعداد الافتراضي للمصنع
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
        'shifts': shifts?.map((s) => s.toJson()).toList(),
        'shift_names': shiftNames,
      };

  factory DaySchedule.fromJson(Map<String, dynamic> map) => DaySchedule(
        dayName: map['day_name'] ?? 'Saturday',
        isWorkingDay: map['is_working_day'] ?? true,
        shiftStart: map['shift_start'] ?? '08:00 AM',
        shiftEnd: map['shift_end'] ?? '05:00 PM',
        shifts: map['shifts'] != null
            ? (map['shifts'] as List).map((s) => Shift.fromJson(s)).toList()
            : null,
        shiftNames: map['shift_names'] != null
            ? List<String>.from(map['shift_names'])
            : null,
      );

  /// اسم اليوم العربي
  String get arabicName => arabicNames[dayName] ?? dayName;
}
