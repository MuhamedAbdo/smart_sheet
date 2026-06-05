// lib/utils/absence_calculator.dart
//
// حاسبة أيام الغياب الفعلية — Smart Sheet
//
// الغرض:
//   حساب عدد أيام الغياب الحقيقية بين [absenceDate] (تاريخ بدء الغياب)
//   و[returnDate] (تاريخ العودة للعمل) بالاعتماد على إعدادات أيام العمل
//   المحفوظة في Hive Box 'factory_schedule' (جدول وردية أيام الأسبوع).
//
// القاعدة الأساسية:
//   • يُحتسَب [absenceDate] كيوم غياب إذا كان يوم عمل فعلياً.
//   • لا يُحتسَب [returnDate] (يوم العودة لا يُعدّ يوم غياب).
//   • أيام العطل الرسمية (isWorkingDay == false) تُتخطّى ولا تُحتسَب.
//
// السيناريوهات الثلاثة:
//   ① غاب يوم 1 وعاد يوم 2  → 1 يوم غياب
//   ② غاب يوم 1 وعاد يوم 3  (يوم 2 يوم عمل) → 2 يوم غياب
//   ③ غاب يوم 1 وعاد يوم 3  (يوم 2 عطلة رسمية) → 1 يوم غياب
//
// التكامل مع المشروع:
//   استورد الدالة في أي controller أو screen:
//     import 'package:smart_sheet/utils/absence_calculator.dart';
//
//   ثم استدعِها مباشرةً:
//     final days = calculateAbsenceDays(
//       absenceDate: DateTime(2025, 1, 10),
//       returnDate:  DateTime(2025, 1, 12),
//     );

import 'package:flutter/foundation.dart'; // debugPrint
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/day_schedule.dart';

// ─────────────────────────────────────────────────────────────────────────────
// الدالة الرئيسية
// ─────────────────────────────────────────────────────────────────────────────

/// يحسب عدد أيام الغياب الفعلية بين [absenceDate] (شامل) و[returnDate] (غير شامل).
///
/// المعاملات:
/// • [absenceDate]  — أول يوم غياب للعامل.
/// • [returnDate]   — تاريخ عودة العامل للعمل (لا يُحتسَب ضمن الغياب).
/// • [workingDaysSettings] — خريطة اختيارية (Map<int, bool>) حيث المفتاح هو
///   DateTime.weekday (1=الاثنين … 7=الأحد) والقيمة true لأيام العمل.
///   إذا تُركت null تُقرأ الإعدادات تلقائياً من Hive Box 'factory_schedule'.
///
/// العائد:
/// • عدد صحيح يمثّل أيام الغياب الفعلية (0 إذا كانت جميع الأيام عطلاً).
///
/// مثال الاستخدام:
/// ```dart
/// final days = calculateAbsenceDays(
///   absenceDate: DateTime(2025, 6, 1),   // الأحد
///   returnDate:  DateTime(2025, 6, 3),   // الثلاثاء
/// );
/// // إذا كان الاثنين عطلة رسمية → days == 1
/// // إذا كان الاثنين يوم عمل   → days == 2
/// ```
int calculateAbsenceDays({
  required DateTime absenceDate,
  required DateTime returnDate,
  Map<int, bool>? workingDaysSettings,
}) {
  // ── 1. تجريد مكوّن الوقت من كلا التاريخين (نقيّم أيام تقويمية فقط) ────────
  final DateTime from = _toDateOnly(absenceDate);
  final DateTime to   = _toDateOnly(returnDate);

  // ── 2. التحقق من صحة النطاق ───────────────────────────────────────────────
  // يجب أن يكون تاريخ العودة بعد أو مساوياً لتاريخ الغياب.
  // إذا كان العكس، نعيد 0 مع تحذير في وضع التطوير.
  if (!to.isAfter(from)) {
    debugPrint(
      '⚠️ [AbsenceCalculator] returnDate ($to) يجب أن يكون بعد absenceDate ($from). '
      'النتيجة: 0 يوم.',
    );
    return 0;
  }

  // ── 3. بناء خريطة أيام العمل من المصدر المناسب ────────────────────────────
  // الأولوية: المعامل المُمرَّر → Hive Box → الافتراضي (كل الأيام عمل)
  final Map<int, bool> schedule = workingDaysSettings ?? _loadFromHive();

  // ── 4. المرور على كل يوم في النطاق [from, to) وعدّ أيام العمل فقط ─────────
  int absenceDays = 0;
  DateTime cursor = from;

  while (cursor.isBefore(to)) {
    // DateTime.weekday: 1=الاثنين, 2=الثلاثاء, … 7=الأحد
    final bool isWorking = schedule[cursor.weekday] ?? true;
    // إذا كان اليوم يوم عمل فعلي → نحتسبه ضمن الغياب
    if (isWorking) {
      absenceDays++;
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  debugPrint(
    '📅 [AbsenceCalculator] من $from إلى $to → $absenceDays يوم غياب فعلي.',
  );

  return absenceDays;
}

// ─────────────────────────────────────────────────────────────────────────────
// دوال مساعدة خاصة
// ─────────────────────────────────────────────────────────────────────────────

/// يُزيل مكوّن الوقت من [dt] ويُعيد تاريخاً نقياً (منتصف الليل).
DateTime _toDateOnly(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day);

/// يقرأ إعدادات أيام العمل من Hive Box 'factory_schedule' ويُعيدها
/// كخريطة Map<int, bool> متوافقة مع DateTime.weekday.
///
/// تعيين DateTime.weekday ↔ DaySchedule.dayName:
///   1 Monday    → 'Monday'
///   2 Tuesday   → 'Tuesday'
///   3 Wednesday → 'Wednesday'
///   4 Thursday  → 'Thursday'
///   5 Friday    → 'Friday'
///   6 Saturday  → 'Saturday'
///   7 Sunday    → 'Sunday'
Map<int, bool> _loadFromHive() {
  // إذا لم يكن الصندوق مفتوحاً (مثلاً في وقت الاختبار)، نعيد افتراضيات
  if (!Hive.isBoxOpen('factory_schedule')) {
    debugPrint(
      '⚠️ [AbsenceCalculator] Hive box "factory_schedule" غير مفتوح. '
      'سيُعامَل كل الأيام كأيام عمل.',
    );
    return {
      DateTime.monday:    true,
      DateTime.tuesday:   true,
      DateTime.wednesday: true,
      DateTime.thursday:  true,
      DateTime.friday:    true,
      DateTime.saturday:  true,
      DateTime.sunday:    true,
    };
  }

  final box = Hive.box<DaySchedule>('factory_schedule');

  // جدول التحويل: اسم اليوم الإنجليزي → رقم DateTime.weekday
  const Map<String, int> nameToWeekday = {
    'Monday':    DateTime.monday,     // 1
    'Tuesday':   DateTime.tuesday,    // 2
    'Wednesday': DateTime.wednesday,  // 3
    'Thursday':  DateTime.thursday,   // 4
    'Friday':    DateTime.friday,     // 5
    'Saturday':  DateTime.saturday,   // 6
    'Sunday':    DateTime.sunday,     // 7
  };

  final Map<int, bool> result = {};

  for (final entry in nameToWeekday.entries) {
    final DaySchedule? schedule = box.get(entry.key);
    // إذا لم يُجد إعداد لليوم، نفترض أنه يوم عمل (سلوك آمن افتراضياً)
    result[entry.value] = schedule?.isWorkingDay ?? true;
  }

  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// دالة مساعدة: بناء workingDaysSettings من Hive (للاستخدام الخارجي)
// ─────────────────────────────────────────────────────────────────────────────

/// يُصدِّر إعدادات أيام العمل الحالية من Hive كخريطة Map<int, bool>.
///
/// مفيد عند الحاجة إلى تمرير الخريطة يدوياً إلى [calculateAbsenceDays]
/// أو إلى أي منطق حساب آخر يحتاج معرفة أيام العمل.
///
/// مثال:
/// ```dart
/// final settings = buildWorkingDaysSettings();
/// final days = calculateAbsenceDays(
///   absenceDate: myStart,
///   returnDate:  myEnd,
///   workingDaysSettings: settings,
/// );
/// ```
Map<int, bool> buildWorkingDaysSettings() => _loadFromHive();
