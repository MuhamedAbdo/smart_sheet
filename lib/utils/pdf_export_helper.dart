// lib/src/utils/pdf_export_helper.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart'
    show
        SnackBar,
        BuildContext,
        Colors,
        Text,
        SnackBarAction,
        Row,
        Icon,
        Icons,
        SizedBox,
        TextStyle,
        Expanded;
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/globals.dart';
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:smart_sheet/utils/arabic_pdf_helper.dart';

/// ✅ الدالة الجديدة: توليد بيانات PDF وإرجاعها كـ Bytes لاستخدامها في FilePicker
/// هذه الدالة تحل مشكلة الخطأ "method not defined" في ملف الشاشة
Future<Uint8List?> generateProductionReportPdfBytes(
    List<Map<String, dynamic>> records) async {
  if (records.isEmpty) return null;

  try {
    // تحميل الخطوط لدعم اللغة العربية
    final fontData = await rootBundle.load("assets/fonts/Amiri-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Amiri-Bold.ttf");

    final Uint8List fontBytes = fontData.buffer
        .asUint8List(fontData.offsetInBytes, fontData.lengthInBytes);
    final Uint8List boldFontBytes = boldFontData.buffer
        .asUint8List(boldFontData.offsetInBytes, boldFontData.lengthInBytes);

    // تجهيز البيانات
    final safeRecords = records.map((r) => toSerializableMap(r)).toList();

    // تشغيل المعالجة في Isolate لضمان سلاسة التطبيق
    final Uint8List pdfBytes = await compute(_generateConsolidatedPdfBytes, {
      'records': safeRecords,
      'font': fontBytes,
      'bold': boldFontBytes,
    });

    return pdfBytes;
  } catch (e) {
    debugPrint('❌ خطأ في generateProductionReportPdfBytes: $e');
    return null;
  }
}

/// تحويل Map إلى تنسيق آمن (قابل للتسلسل عبر Isolate)
Map<String, dynamic> toSerializableMap(Map<String, dynamic> input) {
  final output = <String, dynamic>{};
  input.forEach((key, value) {
    if (value is DateTime) {
      output[key] = value.toIso8601String();
    } else if (value is Map) {
      final safeMap = <String, dynamic>{};
      (value).forEach((k, v) {
        safeMap[k.toString()] = v is DateTime ? v.toIso8601String() : v;
      });
      output[key] = safeMap;
    } else if (value is List) {
      output[key] = (value).map((item) {
        if (item is Map) {
          final safeMap = <String, dynamic>{};
          (item).forEach((k, v) {
            safeMap[k.toString()] = v is DateTime ? v.toIso8601String() : v;
          });
          return safeMap;
        } else if (item is DateTime) {
          return item.toIso8601String();
        }
        return item;
      }).toList();
    } else {
      output[key] = value;
    }
  });
  return output;
}

/// ✅ تنسيق التاريخ ليكون yyyy-MM-dd فقط
String _formatDate(String dateStr) {
  if (dateStr.isEmpty) return '---';
  try {
    DateTime? date = DateTime.tryParse(dateStr);
    if (date == null && dateStr.contains(' ')) {
      final parts = dateStr.split(' ');
      date = DateTime.tryParse(parts[0]);
    }
    if (date != null) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  } catch (e) {
    debugPrint('❌ خطأ في تنسيق التاريخ: $dateStr - $e');
  }
  return dateStr;
}

Future<void> savePdfToDevice(
    BuildContext context, List<Map<String, dynamic>> records) async {
  if (records.isEmpty) {
    UIUtils.showInfoSnackBar(
      message: "لا توجد تقارير لحفظها",
      backgroundColor: Colors.orange,
      icon: Icons.warning_amber_rounded,
    );
    return;
  }

  var status = await Permission.storage.status;
  if (!status.isGranted) {
    status = await Permission.storage.request();
  }

  final hasPermission = status.isGranted;

  // إذا لم يتوفر إذن التخزين الخارجي سنحفظ داخلياً
  final Uint8List? pdfBytes = await generateProductionReportPdfBytes(records);
  if (pdfBytes == null) return;

  try {
    String filePath;
    if (hasPermission && Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final appDir = Directory('${directory.path}/SmartSheet/Reports');
        if (!await appDir.exists()) await appDir.create(recursive: true);
        final fileName =
            'تقارير_الإنتاج_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${appDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        filePath = file.path;
      } else {
        filePath = await _saveToInternalStorage(pdfBytes);
      }
    } else {
      filePath = await _saveToInternalStorage(pdfBytes);
    }

    if (context.mounted) {
      _showSuccessSnackBar(context, filePath, pdfBytes);
    }
  } catch (e) {
    debugPrint('❌ خطأ في حفظ PDF: $e');
  }
}

Future<String> _saveToInternalStorage(Uint8List pdfBytes) async {
  final directory = await getApplicationDocumentsDirectory();
  final appDir = Directory('${directory.path}/SmartSheet/Reports');
  if (!await appDir.exists()) await appDir.create(recursive: true);
  final fileName =
      'تقارير_الإنتاج_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final file = File('${appDir.path}/$fileName');
  await file.writeAsBytes(pdfBytes);
  return file.path;
}

void _showSuccessSnackBar(
    BuildContext context, String filePath, Uint8List bytes) {
  final fileName = filePath.split('/').last;
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تم حفظ PDF بنجاح\n$fileName',
              style: const TextStyle(
                fontFamily: 'Amiri',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'فتح',
        textColor: Colors.yellowAccent,
        onPressed: () => OpenFile.open(filePath),
      ),
    ),
  );
}

/// تصدير ومشاركة PDF
Future<void> exportReportsToPdf(
    BuildContext context, List<Map<String, dynamic>> records) async {
  final pdfBytes = await generateProductionReportPdfBytes(records);
  if (pdfBytes != null) {
    final fileName =
        'تقارير_الإنتاج_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }
}

/// تصدير تقرير واحد
Future<void> exportReportToPdf(BuildContext context,
    Map<String, dynamic> record, List<String> imagePaths) async {
  try {
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final Uint8List fontBytes = fontData.buffer.asUint8List();
    final Uint8List boldFontBytes = boldFontData.buffer.asUint8List();

    final pdfBytes = await compute(_generateSingleReportPdfBytes, {
      'record': toSerializableMap(record),
      'font': fontBytes,
      'bold': boldFontBytes,
    });

    await Printing.sharePdf(bytes: pdfBytes, filename: 'تقرير_فردي.pdf');
  } catch (e) {
    debugPrint('❌ خطأ: $e');
  }
}

// ---------------------------------
// دوال المساعدة و Isolate (تنسيق الجدول)
// ---------------------------------

String _getDimensionsOnly(Map<String, dynamic> record) {
  final dimensions = record['dimensions'];
  if (dimensions is! Map) return '---';

  String formatNumber(String value) {
    if (value.isEmpty) return '0';
    if (value.contains('.')) {
      final parts = value.split('.');
      if (parts.length > 1 && parts[1] == '0') return parts[0];
      return value
          .replaceAll(RegExp(r'0*$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    return value;
  }

  final fL = formatNumber(dimensions['length']?.toString() ?? '');
  final fW = formatNumber(dimensions['width']?.toString() ?? '');
  final fH = formatNumber(dimensions['height']?.toString() ?? '');

  if (fL == '0' || fW == '0') return '---';

  // صياغة النص بناءً على نوع الصنف
  if (record['isSheet'] == true) {
    return '$fL / $fW';
  } else {
    return '$fL / $fW / $fH';
  }
}

Future<Uint8List> _generateConsolidatedPdfBytes(Map<String, dynamic> params) async {
  try {
    final List<dynamic> records = params['records'];
    final arabicFont = pw.Font.ttf(params['font'].buffer.asByteData());
    final arabicBoldFont = pw.Font.ttf(params['bold'].buffer.asByteData());

    // 1. استخراج الألوان الفريدة
    final Set<String> uniqueColorsSet = {};
    for (var record in records) {
      final List<dynamic> colors = record['colors'] ?? [];
      for (var c in colors) {
        final colorData = c is Map ? c : {};
        final colorName = colorData['color']?.toString() ?? '';
        if (colorName.isNotEmpty && colorName != '---') {
          uniqueColorsSet.add(colorName);
        }
      }
    }
    final List<String> uniqueColors = uniqueColorsSet.toList()..sort();

    final pdf = pw.Document();
    const int recordsPerPage = 13;
    final int totalPages = (records.length / recordsPerPage).ceil();

    const double masterHeaderHeight = 18.0;
    const double subHeaderHeight = 17.0;
    const double totalHeaderHeight = masterHeaderHeight + subHeaderHeight;
    const double dataRowHeight = 30.0;

    // توزيع المساحة المتبقية على العميل والصنف والملاحظات مع تفادي الأخطاء الكسرية
    final double remainingWidth = 810 - (20 + 55 + 48 + 60 + 45 + 35 + 70 + 50 + 70) - (uniqueColors.length * 30.0);
    final double flexibleColWidth = (remainingWidth / 3).floorToDouble();

    // دالة موحدة لبناء خلايا البيانات لضمان استقامة الخطوط
    pw.Widget buildTableDataCell(String text, double width, {bool isRightMost = false, bool isSectionEnd = false}) {
      return pw.Container(
        width: width,
        height: dataRowHeight,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: const pw.BorderSide(width: 0.5),
            left: pw.BorderSide(width: isSectionEnd ? 1.5 : 0.5, color: PdfColors.black),
            right: isRightMost ? const pw.BorderSide(width: 0.5) : pw.BorderSide.none,
          ),
        ),
        child: pw.Text(ArabicPDFHelper.fixArabic(text), 
          style: pw.TextStyle(font: arabicFont, fontSize: 7.5), 
          softWrap: true, textAlign: pw.TextAlign.center),
      );
    }

    // بناء خلية الحبر المقسمة (إسم اللون فوق الكمية)
    pw.Widget buildStackedInkCell(String colorName, String quantity, double width, {bool isSectionEnd = false}) {
      return pw.Container(
        width: width,
        height: dataRowHeight,
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: const pw.BorderSide(width: 0.5),
            left: pw.BorderSide(width: isSectionEnd ? 1.5 : 0.5, color: PdfColors.black),
          ),
        ),
        child: pw.Column(children: [
          pw.Container(
            height: dataRowHeight / 2,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
            child: pw.Text(ArabicPDFHelper.fixArabic(colorName), style: pw.TextStyle(font: arabicFont, fontSize: 6.5)),
          ),
          pw.Container(
            height: dataRowHeight / 2,
            alignment: pw.Alignment.center,
            child: pw.Text(ArabicPDFHelper.fixArabic(quantity), style: pw.TextStyle(font: arabicFont, fontSize: 7)),
          ),
        ]),
      );
    }

    for (int page = 0; page < totalPages; page++) {
      final int startIndex = page * recordsPerPage;
      final int endIndex = (page + 1) * recordsPerPage < records.length
          ? (page + 1) * recordsPerPage
          : records.length;

      final List<dynamic> pageRecords = records.sublist(startIndex, endIndex);
      final List<pw.Widget> pageRows = [];

      for (int i = 0; i < pageRecords.length; i++) {
        final record = pageRecords[i] as Map<String, dynamic>;
        
        pageRows.add(
          pw.Row(children: [
            buildTableDataCell('${startIndex + i + 1}', 20, isRightMost: true),
            buildTableDataCell(_formatDate(record['date']?.toString() ?? '---'), 55),
            buildTableDataCell(record['clientName']?.toString() ?? '---', flexibleColWidth),
            buildTableDataCell(record['product']?.toString() ?? '---', flexibleColWidth),
            buildTableDataCell(record['productCode']?.toString() ?? '---', 48),
            buildTableDataCell(_getDimensionsOnly(record), 60),
            buildTableDataCell(record['orderNumber']?.toString() ?? '---', 45),
            buildTableDataCell(record['quantity']?.toString() ?? '---', 35),
            // وقت التشغيل
            buildTableDataCell(record['startTime']?.toString() ?? '---', 35),
            buildTableDataCell(record['endTime']?.toString() ?? '---', 35, isSectionEnd: true),
            // الهالك
            buildTableDataCell(record['lineWaste']?.toString() ?? '---', 25),
            buildTableDataCell(record['printWaste']?.toString() ?? '---', 25, isSectionEnd: true),
            // الأعطال
            buildTableDataCell(record['downtimeStart']?.toString() ?? '---', 35),
            buildTableDataCell(record['downtimeEnd']?.toString() ?? '---', 35, isSectionEnd: true),
            // الأحبار المقسمة (تعبئة من اليمين لليسار حسب ألوان السجل الفعلي)
            ...List.generate(uniqueColors.length, (j) {
              final recordColors = record['colors'] as List? ?? [];
              
              // سحب اللون حسب الترتيب في هذا السجل تحديداً
              String displayedName = '---';
              String displayedQty = '---';
              
              if (j < recordColors.length) {
                final colorEntry = recordColors[j];
                displayedName = colorEntry['color']?.toString() ?? '---';
                displayedQty = colorEntry['quantity']?.toString() ?? '---';
              }
              
              return buildStackedInkCell(
                displayedName,
                displayedQty,
                30,
                isSectionEnd: true, // تلبية لطلب جعل كل لون ينتهي بخط سميك
              );
            }),
            buildTableDataCell(record['notes']?.toString() ?? '---', flexibleColWidth),
          ]),
        );
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(children: [
            pw.Text(ArabicPDFHelper.fixArabic('تقرير إنتاج الطباعة'), 
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 16)),
            pw.SizedBox(height: 10),
            _buildManualHeader(
              uniqueColors: uniqueColors,
              flexibleWidth: flexibleColWidth,
              font: arabicBoldFont,
              headerHeight: totalHeaderHeight,
              masterHeight: masterHeaderHeight,
              subHeight: subHeaderHeight,
            ),
            pw.Column(children: pageRows),
          ]),
        ),
      ));
    }
    return await pdf.save();
  } catch (e) {
    debugPrint('❌ خطأ في _generateConsolidatedPdfBytes: $e');
    return Uint8List(0);
  }
}

/// بناء الرأس المطور مع ضمان مطابقة الحدود تماماً للبيانات
pw.Widget _buildManualHeader({
  required List<String> uniqueColors,
  required double flexibleWidth,
  required pw.Font font,
  required double headerHeight,
  required double masterHeight,
  required double subHeight,
}) {
  pw.Widget buildSpannedHeader(String text, double width, {bool isRightMost = false, bool isSectionEnd = false}) {
    return pw.Container(
      width: width,
      height: headerHeight,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        border: pw.Border(
          top: const pw.BorderSide(width: 0.5),
          bottom: const pw.BorderSide(width: 0.5),
          left: pw.BorderSide(width: isSectionEnd ? 1.5 : 0.5, color: PdfColors.black),
          right: isRightMost ? const pw.BorderSide(width: 0.5) : pw.BorderSide.none,
        ),
      ),
      child: pw.Text(ArabicPDFHelper.fixArabic(text), 
        style: pw.TextStyle(font: font, fontSize: 8), 
        softWrap: true, textAlign: pw.TextAlign.center),
    );
  }

  pw.Widget buildGroupedHeader(String title, List<String> subs, List<double> subWidths, {bool isSectionEnd = false}) {
    double totalWidth = subWidths.reduce((a, b) => a + b);
    return pw.Container(
      width: totalWidth,
      height: headerHeight,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        border: pw.Border(
          top: const pw.BorderSide(width: 0.5),
          bottom: const pw.BorderSide(width: 0.5),
          left: pw.BorderSide(width: isSectionEnd ? 1.5 : 0.5, color: PdfColors.black),
        ),
      ),
      child: pw.Column(children: [
        pw.Container(
          height: masterHeight,
          alignment: pw.Alignment.center,
          child: pw.Text(ArabicPDFHelper.fixArabic(title), 
            style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
        ),
        pw.Container(
          height: subHeight,
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border(top: pw.BorderSide(width: 0.5)),
          ),
          child: pw.Row(children: [
            for (int i = 0; i < subs.length; i++)
              pw.Container(
                width: subWidths[i],
                alignment: pw.Alignment.center,
                decoration: i == (subs.length - 1) 
                  ? null 
                  : const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(width: 0.5))),
                child: pw.Text(ArabicPDFHelper.fixArabic(subs[i]), 
                  style: pw.TextStyle(font: font, fontSize: 7), softWrap: true, textAlign: pw.TextAlign.center),
              ),
          ]),
        ),
      ]),
    );
  }

  return pw.Row(
    children: [
      buildSpannedHeader('م', 20, isRightMost: true),
      buildSpannedHeader('التاريخ', 55),
      buildSpannedHeader('إسم العميل', flexibleWidth),
      buildSpannedHeader('الصنف', flexibleWidth),
      buildSpannedHeader('كود الصنف', 48),
      buildSpannedHeader('المقاس', 60),
      buildSpannedHeader('أمر التشغيل', 45),
      buildSpannedHeader('الإنتاج', 35),
      buildGroupedHeader('وقت التشغيل', ['من', 'إلى'], [35, 35], isSectionEnd: true),
      buildGroupedHeader('الهالك', ['خ', 'ط'], [25, 25], isSectionEnd: true),
      buildGroupedHeader('الأعطال', ['من', 'إلى'], [35, 35], isSectionEnd: true),
      if (uniqueColors.isNotEmpty)
        buildSpannedHeader(
          'كمية الحبر بالليتر', 
          uniqueColors.length * 30.0, 
          isSectionEnd: true,
        ),
      buildSpannedHeader('الملاحظات', flexibleWidth),
    ],
  );
}

// الدوال المساعدة للبناء بتنسيق مطور مع دعم الـ SoftWrap والتوسيط الكامل

// دالة توليد تقرير فردي لـ Isolate
Future<Uint8List> _generateSingleReportPdfBytes(
    Map<String, dynamic> params) async {
  // نفس منطق Consolidated ولكن لسجل واحد فقط (مختصر)
  return await compute(_generateConsolidatedPdfBytes, {
    'records': [params['record']],
    'font': params['font'],
    'bold': params['bold']
  });
}
