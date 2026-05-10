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
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:smart_sheet/utils/arabic_pdf_helper.dart';

// ---------------------------------
// توليد الـ Bytes
// ---------------------------------

Future<Uint8List?> generateProductionReportPdfBytes(List<Map<String, dynamic>> records) async {
  if (records.isEmpty) return null;
  try {
    final fontData = await rootBundle.load("assets/fonts/Amiri-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Amiri-Bold.ttf");
    final Uint8List fontBytes = fontData.buffer.asUint8List();
    final Uint8List boldFontBytes = boldFontData.buffer.asUint8List();
    final safeRecords = records.map((r) => toSerializableMap(r)).toList();

    return await compute(_generateConsolidatedProductionPdfBytes, {
      'records': safeRecords,
      'font': fontBytes,
      'bold': boldFontBytes,
    });
  } catch (e) {
    debugPrint('❌ خطأ في generateProductionReportPdfBytes: $e');
    return null;
  }
}

Future<Uint8List?> generatePrintingReportPdfBytes(List<Map<String, dynamic>> records) async {
  if (records.isEmpty) return null;
  try {
    final fontData = await rootBundle.load("assets/fonts/Amiri-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Amiri-Bold.ttf");
    final Uint8List fontBytes = fontData.buffer.asUint8List();
    final Uint8List boldFontBytes = boldFontData.buffer.asUint8List();
    final safeRecords = records.map((r) => toSerializableMap(r)).toList();

    return await compute(_generateConsolidatedPrintingPdfBytes, {
      'records': safeRecords,
      'font': fontBytes,
      'bold': boldFontBytes,
    });
  } catch (e) {
    debugPrint('❌ خطأ في generatePrintingReportPdfBytes: $e');
    return null;
  }
}

Map<String, dynamic> toSerializableMap(Map<String, dynamic> input) {
  final output = <String, dynamic>{};
  input.forEach((key, value) {
    if (value is DateTime) {
      output[key] = value.toIso8601String();
    } else if (value is Map) {
      final safeMap = <String, dynamic>{};
      value.forEach((k, v) {
        safeMap[k.toString()] = v is DateTime ? v.toIso8601String() : v;
      });
      output[key] = safeMap;
    } else if (value is List) {
      output[key] = value.map((item) {
        if (item is Map) {
          final safeMap = <String, dynamic>{};
          item.forEach((k, v) {
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

// ---------------------------------
// الحفظ على الجهاز
// ---------------------------------

Future<void> saveProductionPdfToDevice(BuildContext context, List<Map<String, dynamic>> records) async {
  await _savePdfCommon(context, records, generateProductionReportPdfBytes, 'تقرير_إنتاج');
}

Future<void> savePrintingPdfToDevice(BuildContext context, List<Map<String, dynamic>> records) async {
  await _savePdfCommon(context, records, generatePrintingReportPdfBytes, 'تقرير_طباعة');
}

Future<void> _savePdfCommon(
  BuildContext context,
  List<Map<String, dynamic>> records,
  Future<Uint8List?> Function(List<Map<String, dynamic>>) generateFn,
  String prefix
) async {
  if (records.isEmpty) {
    UIUtils.showInfoSnackBar(
      message: "لا توجد تقارير لحفظها",
      backgroundColor: Colors.orange,
      icon: Icons.warning_amber_rounded,
    );
    return;
  }

  final pdfBytes = await generateFn(records);
  if (pdfBytes == null) return;

  try {
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    String? filePath;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ملف PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );
    } else {
      // Android / iOS fallback
      final directory = await getApplicationDocumentsDirectory();
      final appDir = Directory('${directory.path}/SmartSheet/Reports');
      if (!await appDir.exists()) await appDir.create(recursive: true);
      final file = File('${appDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      filePath = file.path;
    }

    if (filePath != null && context.mounted) {
      _showSuccessSnackBar(context, filePath, pdfBytes);
    }
  } catch (e) {
    debugPrint('❌ خطأ في حفظ PDF: $e');
  }
}

void _showSuccessSnackBar(BuildContext context, String filePath, Uint8List bytes) {
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
              style: const TextStyle(fontFamily: 'Amiri', color: Colors.white),
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

// ---------------------------------
// المشاركة/الطباعة (عرض PDF)
// ---------------------------------

Future<void> exportProductionReportsToPdf(BuildContext context, List<Map<String, dynamic>> records) async {
  final pdfBytes = await generateProductionReportPdfBytes(records);
  if (pdfBytes != null) {
    await Printing.sharePdf(bytes: pdfBytes, filename: 'تقرير_إنتاج_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }
}

Future<void> exportPrintingReportsToPdf(BuildContext context, List<Map<String, dynamic>> records) async {
  final pdfBytes = await generatePrintingReportPdfBytes(records);
  if (pdfBytes != null) {
    await Printing.sharePdf(bytes: pdfBytes, filename: 'تقرير_طباعة_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }
}

Future<void> exportReportToPdf(BuildContext context, Map<String, dynamic> record, List<String> imagePaths) async {
  await exportProductionReportsToPdf(context, [record]);
}

// ---------------------------------
// دوال مساعدة لإنشاء PDF
// ---------------------------------

String _getDimensionsOnly(Map<String, dynamic> record) {
  final dimensions = record['dimensions'];
  if (dimensions is! Map) return '---';

  String formatNumber(String value) {
    if (value.isEmpty) return '0';
    if (value.contains('.')) {
      final parts = value.split('.');
      if (parts.length > 1 && parts[1] == '0') return parts[0];
      return value.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return value;
  }

  final fL = formatNumber(dimensions['length']?.toString() ?? '');
  final fW = formatNumber(dimensions['width']?.toString() ?? '');
  final fH = formatNumber(dimensions['height']?.toString() ?? '');

  if (fL == '0' || fW == '0') return '---';

  if (record['isSheet'] == true) {
    return '$fL / $fW';
  } else {
    return '$fL / $fW / $fH';
  }
}

// بناء الخلايا الأساسية للجدول
pw.Widget buildTableDataCell(String text, double width, pw.Font font, {bool isRightMost = false, bool isSectionEnd = false}) {
  return pw.Container(
    width: width,
    height: 30.0,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: const pw.BorderSide(width: 0.5),
        left: pw.BorderSide(width: isSectionEnd ? 1.5 : 0.5, color: PdfColors.black),
        right: isRightMost ? const pw.BorderSide(width: 0.5) : pw.BorderSide.none,
      ),
    ),
    child: pw.Text(ArabicPDFHelper.fixArabic(text),
      style: pw.TextStyle(font: font, fontSize: 7.5),
      softWrap: true, textAlign: pw.TextAlign.center),
  );
}

// خلية الحبر
pw.Widget buildStackedInkCell(String colorName, String quantity, double width, pw.Font font, {bool isSectionEnd = false}) {
  return pw.Container(
    width: width,
    height: 30.0,
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: const pw.BorderSide(width: 0.5),
        left: pw.BorderSide(width: isSectionEnd ? 1.5 : 0.5, color: PdfColors.black),
      ),
    ),
    child: pw.Column(children: [
      pw.Container(
        height: 15.0,
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
        child: pw.Text(ArabicPDFHelper.fixArabic(colorName), style: pw.TextStyle(font: font, fontSize: 6.5)),
      ),
      pw.Container(
        height: 15.0,
        alignment: pw.Alignment.center,
        child: pw.Text(ArabicPDFHelper.fixArabic(quantity), style: pw.TextStyle(font: font, fontSize: 7)),
      ),
    ]),
  );
}

// ---------------------------------
// دالة: تقرير الإنتاج (بدون أحبار، مع الفني/الماكينة)
// ---------------------------------
Future<Uint8List> _generateConsolidatedProductionPdfBytes(Map<String, dynamic> params) async {
  try {
    final List<dynamic> records = params['records'];
    final arabicFont = pw.Font.ttf(params['font'].buffer.asByteData());
    final arabicBoldFont = pw.Font.ttf(params['bold'].buffer.asByteData());

    final pdf = pw.Document();
    const int recordsPerPage = 13;
    final int totalPages = (records.length / recordsPerPage).ceil();

    // Width calculation: Total 810
    // Fixed columns: م(20), الفني(50), التاريخ(55), كود(48), المقاس(60), أمر(45), إنتاج(35), تشغيل(70), هالك(50), أعطال(70) = 503
    // Remaining: 810 - 503 = 307
    // Flexible: العميل, الصنف, ملاحظات (307 / 3 = 102.0)
    final double flexibleColWidth = ((810 - 503) / 3).floorToDouble();

    for (int page = 0; page < totalPages; page++) {
      final int startIndex = page * recordsPerPage;
      final int endIndex = (page + 1) * recordsPerPage < records.length
          ? (page + 1) * recordsPerPage
          : records.length;

      final List<dynamic> pageRecords = records.sublist(startIndex, endIndex);
      final List<pw.Widget> pageRows = [];

      for (int i = 0; i < pageRecords.length; i++) {
        final record = pageRecords[i] as Map<String, dynamic>;
        final String tName = (record['technicianName'] ?? record['technician_name'])?.toString() ?? '---';

        pageRows.add(
          pw.Row(children: [
            buildTableDataCell('${startIndex + i + 1}', 20.0, arabicFont, isRightMost: true),
            buildTableDataCell(tName, 50.0, arabicFont),
            buildTableDataCell(_formatDate(record['date']?.toString() ?? '---'), 55.0, arabicFont),
            buildTableDataCell(record['clientName']?.toString() ?? '---', flexibleColWidth, arabicFont),
            buildTableDataCell(record['product']?.toString() ?? '---', flexibleColWidth, arabicFont),
            buildTableDataCell(record['productCode']?.toString() ?? '---', 48.0, arabicFont),
            buildTableDataCell(_getDimensionsOnly(record), 60.0, arabicFont),
            buildTableDataCell(record['orderNumber']?.toString() ?? '---', 45.0, arabicFont),
            buildTableDataCell(record['quantity']?.toString() ?? '---', 35.0, arabicFont),
            buildTableDataCell(record['startTime']?.toString() ?? '---', 35.0, arabicFont),
            buildTableDataCell(record['endTime']?.toString() ?? '---', 35.0, arabicFont, isSectionEnd: true),
            buildTableDataCell(record['lineWaste']?.toString() ?? '---', 25.0, arabicFont),
            buildTableDataCell(record['printWaste']?.toString() ?? '---', 25.0, arabicFont, isSectionEnd: true),
            buildTableDataCell(record['downtimeStart']?.toString() ?? '---', 35.0, arabicFont),
            buildTableDataCell(record['downtimeEnd']?.toString() ?? '---', 35.0, arabicFont, isSectionEnd: true),
            buildTableDataCell(record['notes']?.toString() ?? '---', flexibleColWidth, arabicFont),
          ]),
        );
      }

      // Get unique machine names for this page
      final Set<String> pageMachineNames = {};
      for (var record in pageRecords) {
        final machineName = (record['machineName'] ?? record['machine_name'])?.toString() ?? '';
        if (machineName.isNotEmpty) {
          pageMachineNames.add(machineName);
        }
      }
      
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(children: [
            pw.Text(ArabicPDFHelper.fixArabic('قسم الفلكسو'),
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 16)),
            pw.SizedBox(height: 4),
            pw.Text(ArabicPDFHelper.fixArabic(pageMachineNames.length == 1 
                ? 'تقرير الإنتاج لماكينة: ${pageMachineNames.first}'
                : 'تقرير الإنتاج للماكينات: ${pageMachineNames.join(', ')}'),
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 14)),
            pw.SizedBox(height: 6),
            _buildProductionHeader(flexibleWidth: flexibleColWidth, font: arabicBoldFont),
            pw.Column(children: pageRows),
          ]),
        ),
      ));
    }
    return await pdf.save();
  } catch (e) {
    debugPrint('❌ خطأ في _generateConsolidatedProductionPdfBytes: $e');
    return Uint8List(0);
  }
}

pw.Widget _buildProductionHeader({required double flexibleWidth, required pw.Font font}) {
  return pw.Row(
    children: [
      _buildSpannedHeader('م', 20.0, font, isRightMost: true),
      _buildSpannedHeader('الفني', 50.0, font),
      _buildSpannedHeader('التاريخ', 55.0, font),
      _buildSpannedHeader('إسم العميل', flexibleWidth, font),
      _buildSpannedHeader('الصنف', flexibleWidth, font),
      _buildSpannedHeader('كود الصنف', 48.0, font),
      _buildSpannedHeader('المقاس', 60.0, font),
      _buildSpannedHeader('أمر التشغيل', 45.0, font),
      _buildSpannedHeader('الإنتاج', 35.0, font),
      _buildGroupedHeader('وقت التشغيل', ['من', 'إلى'], [35.0, 35.0], font, isSectionEnd: true),
      _buildGroupedHeader('الهالك', ['خ', 'ط'], [25.0, 25.0], font, isSectionEnd: true),
      _buildGroupedHeader('الأعطال', ['من', 'إلى'], [35.0, 35.0], font, isSectionEnd: true),
      _buildSpannedHeader('الملاحظات', flexibleWidth, font),
    ],
  );
}

// ---------------------------------
// دالة: تقرير الطباعة (مع أحبار)
// ---------------------------------
Future<Uint8List> _generateConsolidatedPrintingPdfBytes(Map<String, dynamic> params) async {
  try {
    final List<dynamic> records = params['records'];
    final arabicFont = pw.Font.ttf(params['font'].buffer.asByteData());
    final arabicBoldFont = pw.Font.ttf(params['bold'].buffer.asByteData());

    // استخراج الحد الأقصى لعدد الألوان في أي أوردر واحد
    int maxColorsCount = 0;
    List<String> colorHeaders = [];
    
    for (var record in records) {
      final List<dynamic> colors = record['colors'] ?? [];
      if (colors.length > maxColorsCount) {
        maxColorsCount = colors.length;
        // إنشاء عناوين الألوان بناءً على أكبر عدد
        colorHeaders = colors.map((c) {
          final colorData = c is Map ? c : {};
          return colorData['color']?.toString() ?? '---';
        }).toList();
      }
    }
    
    final List<String> uniqueColors = colorHeaders.take(maxColorsCount).toList();

    final pdf = pw.Document();
    const int recordsPerPage = 13;
    final int totalPages = (records.length / recordsPerPage).ceil();

    // Width calculation: Total 810
    // Fixed columns: م(20), الفني(50), التاريخ(55), العدد(40), الملاحظات(flexible) = 165 + flexibleColWidth
    // Dynamic columns: المقاس(60 + extra), الصنف(flexible + extra), العميل(flexible + extra)
    // Colors width: uniqueColors.length * 35.0
    // Remaining space = 810 - 165 - (colorsWidth) - (flexibleColWidth for notes) = 645 - colorsWidth - flexibleColWidth
    // Distribute remaining to: العميل, الصنف, المقاس (3 columns)
    final double colorsWidth = uniqueColors.length * 35.0;
    const double notesWidth = 80.0; // Fixed width for notes
    final double remainingSpace = 810 - 165 - colorsWidth - notesWidth; // 165 = م+الفني+التاريخ+العدد
    final double flexibleColWidth = (remainingSpace / 3).floorToDouble(); // For العميل, الصنف, المقاس

    for (int page = 0; page < totalPages; page++) {
      final int startIndex = page * recordsPerPage;
      final int endIndex = (page + 1) * recordsPerPage < records.length
          ? (page + 1) * recordsPerPage
          : records.length;

      final List<dynamic> pageRecords = records.sublist(startIndex, endIndex);
      final List<pw.Widget> pageRows = [];

      for (int i = 0; i < pageRecords.length; i++) {
        final record = pageRecords[i] as Map<String, dynamic>;
        final String tName = (record['technicianName'] ?? record['technician_name'])?.toString() ?? '---';
        
        pageRows.add(
          pw.Row(children: [
            buildTableDataCell('${startIndex + i + 1}', 20.0, arabicFont, isRightMost: true),
            buildTableDataCell(tName, 50.0, arabicFont),
            buildTableDataCell(_formatDate(record['date']?.toString() ?? '---'), 55.0, arabicFont),
            buildTableDataCell(record['clientName']?.toString() ?? '---', flexibleColWidth, arabicFont),
            buildTableDataCell(record['product']?.toString() ?? '---', flexibleColWidth, arabicFont),
            buildTableDataCell(_getDimensionsOnly(record), flexibleColWidth, arabicFont),
            
            // الأحبار المقسمة (ديناميكية بناءً على الحد الأقصى)
            ...List.generate(uniqueColors.length, (j) {
              final recordColors = record['colors'] as List? ?? [];
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
                35.0,
                arabicFont,
                isSectionEnd: j == uniqueColors.length - 1,
              );
            }),
            
            buildTableDataCell(record['quantity']?.toString() ?? '---', 40.0, arabicFont),
            buildTableDataCell(record['notes']?.toString() ?? '---', notesWidth, arabicFont),
          ]),
        );
      }

      // Get unique machine names for this page
      final Set<String> pageMachineNames = {};
      for (var record in pageRecords) {
        final machineName = (record['machineName'] ?? record['machine_name'])?.toString() ?? '';
        if (machineName.isNotEmpty) {
          pageMachineNames.add(machineName);
        }
      }
      
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(children: [
            pw.Text(ArabicPDFHelper.fixArabic('قسم الفلكسو'),
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 16)),
            pw.SizedBox(height: 4),
            pw.Text(ArabicPDFHelper.fixArabic(pageMachineNames.length == 1 
                ? 'تقرير الطباعة لماكينة: ${pageMachineNames.first}'
                : 'تقرير الطباعة للماكينات: ${pageMachineNames.join(', ')}'),
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 14)),
            pw.SizedBox(height: 6),
            _buildPrintingHeader(uniqueColors: uniqueColors, flexibleWidth: flexibleColWidth, notesWidth: notesWidth, font: arabicBoldFont),
            pw.Column(children: pageRows),
          ]),
        ),
      ));
    }
    return await pdf.save();
  } catch (e) {
    debugPrint('❌ خطأ في _generateConsolidatedPrintingPdfBytes: $e');
    return Uint8List(0);
  }
}

pw.Widget _buildPrintingHeader({required List<String> uniqueColors, required double flexibleWidth, required double notesWidth, required pw.Font font}) {
  return pw.Row(
    children: [
      _buildSpannedHeader('م', 20.0, font, isRightMost: true),
      _buildSpannedHeader('الفني', 50.0, font),
      _buildSpannedHeader('التاريخ', 55.0, font),
      _buildSpannedHeader('إسم العميل', flexibleWidth, font),
      _buildSpannedHeader('الصنف', flexibleWidth, font),
      _buildSpannedHeader('المقاس', flexibleWidth, font),
      
      // الأحبار الديناميكية - عرض كل لون في عمود منفصل
      if (uniqueColors.isNotEmpty)
        ...List.generate(uniqueColors.length, (j) {
          final colorName = j < uniqueColors.length ? uniqueColors[j] : '---';
          return _buildSpannedHeader(colorName, 35.0, font, isSectionEnd: j == uniqueColors.length - 1);
        }),
      
      _buildSpannedHeader('العدد', 40.0, font),
      _buildSpannedHeader('الملاحظات', notesWidth, font),
    ],
  );
}

// ---------------------------------
// دوال Headers مشتركة
// ---------------------------------

pw.Widget _buildSpannedHeader(String text, double width, pw.Font font, {bool isRightMost = false, bool isSectionEnd = false}) {
  return pw.Container(
    width: width,
    height: 35.0,
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

pw.Widget _buildGroupedHeader(String title, List<String> subs, List<double> subWidths, pw.Font font, {bool isSectionEnd = false}) {
  double totalWidth = subWidths.reduce((a, b) => a + b);
  return pw.Container(
    width: totalWidth,
    height: 35.0,
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
        height: 18.0,
        alignment: pw.Alignment.center,
        child: pw.Text(ArabicPDFHelper.fixArabic(title),
          style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
      ),
      pw.Container(
        height: 17.0,
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
