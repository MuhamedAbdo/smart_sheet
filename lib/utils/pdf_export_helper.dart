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

Future<Uint8List?> generateFlexoProductionReportPdfBytes(Map<String, dynamic> params) async {
  final records = params['records'] as List<Map<String, dynamic>>;
  if (records.isEmpty) return null;
  try {
    final fontData = await rootBundle.load("assets/fonts/Amiri-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Amiri-Bold.ttf");
    final Uint8List fontBytes = fontData.buffer.asUint8List();
    final Uint8List boldFontBytes = boldFontData.buffer.asUint8List();
    final safeRecords = records.map((r) => toSerializableMap(r)).toList();
    safeRecords.sort(_compareRecordsByDateAndEndTime);
    final String? department = params['department']?.toString() ??
        (safeRecords.isNotEmpty ? safeRecords.first['department']?.toString() : null);

    if (department == 'crushing' || department == 'die_cutting') {
      return await compute(_generateCrushingProductionPdfBytes, {
        'records': safeRecords,
        'font': fontBytes,
        'bold': boldFontBytes,
        'title': params['title'] ?? 'تقرير إنتاج قسم التكسير',
      });
    }

    return await compute(_generateConsolidatedProductionPdfBytes, {
      'records': safeRecords,
      'font': fontBytes,
      'bold': boldFontBytes,
      'title': params['title'],
    });
  } catch (e) {
    debugPrint('❌ خطأ في generateFlexoProductionReportPdfBytes: $e');
    return null;
  }
}

Future<Uint8List?> generatePrintingReportPdfBytes(Map<String, dynamic> params) async {
  final records = params['records'] as List<Map<String, dynamic>>;
  if (records.isEmpty) return null;
  try {
    final fontData = await rootBundle.load("assets/fonts/Amiri-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Amiri-Bold.ttf");
    final Uint8List fontBytes = fontData.buffer.asUint8List();
    final Uint8List boldFontBytes = boldFontData.buffer.asUint8List();
    final safeRecords = records.map((r) => toSerializableMap(r)).toList();
    safeRecords.sort(_compareRecordsByDateAndEndTime);

    return await compute(_generateConsolidatedPrintingPdfBytes, {
      'records': safeRecords,
      'font': fontBytes,
      'bold': boldFontBytes,
      'title': params['title'],
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

int _compareRecordsByDateAndEndTime(Map<String, dynamic> a, Map<String, dynamic> b) {
  final String dateA = _formatDate(a['date']?.toString() ?? '');
  final String dateB = _formatDate(b['date']?.toString() ?? '');
  
  int dateCmp = dateA.compareTo(dateB);
  if (dateCmp != 0) return dateCmp;

  final String timeA = (a['end_time'] ?? a['endTime'])?.toString().trim() ?? '';
  final String timeB = (b['end_time'] ?? b['endTime'])?.toString().trim() ?? '';

  String normalizeTime(String t) {
    if (t.isEmpty) return '00:00';
    List<String> parts = t.split(':');
    if (parts.length == 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return t.padLeft(5, '0');
  }

  return normalizeTime(timeA).compareTo(normalizeTime(timeB));
}

// ---------------------------------
// الحفظ على الجهاز
// ---------------------------------

Future<void> saveProductionPdfToDevice(BuildContext context, List<Map<String, dynamic>> records) async {
  await _savePdfCommon(context, records, generateFlexoProductionReportPdfBytes, 'تقرير_إنتاج');
}

Future<void> savePrintingPdfToDevice(BuildContext context, List<Map<String, dynamic>> records) async {
  await _savePdfCommon(context, records, generatePrintingReportPdfBytes, 'تقرير_طباعة');
}

Future<void> _savePdfCommon(
  BuildContext context,
  List<Map<String, dynamic>> records,
  Future<Uint8List?> Function(Map<String, dynamic>) generateFn,
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

  final pdfBytes = await generateFn({'records': records, 'title': prefix});
  if (pdfBytes == null) return;

  try {
    String fileName = prefix.contains('ماكينة') 
        ? '${prefix.replaceAll(RegExp(r'[\s:/\\*?"<>|]'), '_')}.pdf'
        : '${prefix.replaceAll(RegExp(r'[\s:/\\*?"<>|]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
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

Future<void> exportFlexoProductionReportsToPdf(BuildContext context, List<Map<String, dynamic>> records, {String? title, String? department}) async {
  final pdfBytes = await generateFlexoProductionReportPdfBytes({'records': records, 'title': title, 'department': department});
  if (pdfBytes != null) {
    String fileName = title != null ? '${title.replaceAll(RegExp(r'[\s:/\\*?"<>|]'), '_')}.pdf' : 'تقرير_إنتاج_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }
}

Future<void> exportPrintingReportsToPdf(BuildContext context, List<Map<String, dynamic>> records, {String? title, String? department}) async {
  final pdfBytes = await generatePrintingReportPdfBytes({'records': records, 'title': title, 'department': department});
  if (pdfBytes != null) {
    String fileName = title != null ? '${title.replaceAll(RegExp(r'[\s:/\\*?"<>|]'), '_')}.pdf' : 'تقرير_طباعة_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }
}

Future<void> exportReportToPdf(BuildContext context, Map<String, dynamic> record, List<String> imagePaths) async {
  await exportFlexoProductionReportsToPdf(context, [record]);
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

  final bool isSheet = record['isSheet'] == true || record['is_sheet'] == true || record['is_sheet'] == 'true';

  if (isSheet) {
    // للقراءة من اليمين لليسار: الطول أولاً على اليمين ثم العرض
    return '$fW / $fL';
  } else {
    // للقراءة من اليمين لليسار: الطول على اليمين / العرض في المنتصف / الارتفاع على اليسار
    return '$fH / $fW / $fL';
  }
}


String _getWeightOnly(Map<String, dynamic> record) {
  final dims = record['dimensions'] is Map ? record['dimensions'] as Map : {};
  final rawWeight = record['weight'] ?? dims['weight'];
  if (rawWeight == null) return '---';
  final wStr = rawWeight.toString().trim();
  if (wStr.isEmpty || wStr == '0' || wStr == '0.0') return '---';
  if (wStr.contains('.')) {
    final parts = wStr.split('.');
    if (parts.length > 1 && parts[1] == '0') return parts[0];
    return wStr.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return wStr;
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
        right: const pw.BorderSide(width: 0.5, color: PdfColors.black),
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
        right: const pw.BorderSide(width: 0.5, color: PdfColors.black),
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
    final String customTitle = params['title']?.toString() ?? 'تقرير الإنتاج لقسم الفلكسو';
    final arabicFont = pw.Font.ttf(params['font'].buffer.asByteData());
    final arabicBoldFont = pw.Font.ttf(params['bold'].buffer.asByteData());

    final pdf = pw.Document();
    const int recordsPerPage = 13;
    final int totalPages = (records.length / recordsPerPage).ceil();

    // Width calculation: Total 810
    // تم تقليل مساحة (الفني، العميل، الصنف) لتوفير مساحة لـ (الهالك، الوزن)
    const double techColWidth = 52.0;
    const double clientColWidth = 72.0;
    const double productColWidth = 72.0;
    // Fixed columns: م(20) + الفني(52) + التاريخ(52) + العميل(72) + الصنف(72) + كود(45) + المقاس(70) + أمر(42) + إنتاج(35) + تشغيل(70) + هالك(28) + وزن(32) + أعطال(70) = 660
    // الملاحظات تأخذ المساحة المتبقية من 810
    const double notesColWidth = 810.0 - 660.0; // = 150.0

    for (int page = 0; page < totalPages; page++) {
      final int startIndex = page * recordsPerPage;
      final int endIndex = (page + 1) * recordsPerPage < records.length
          ? (page + 1) * recordsPerPage
          : records.length;

      final List<dynamic> pageRecords = records.sublist(startIndex, endIndex);
      final List<pw.Widget> pageRows = [];

      for (int i = 0; i < pageRecords.length; i++) {
        final record = pageRecords[i] as Map<String, dynamic>;

        final String tName = (record['technician_name'] ?? record['technicianName'])?.toString() ?? '---';
        final String clientName = (record['client_name'] ?? record['clientName'] ?? record['client'])?.toString() ?? '---';
        final String productName = (record['product_name'] ?? record['productName'] ?? record['product'])?.toString() ?? '---';
        final String productCode = (record['product_code'] ?? record['productCode'])?.toString() ?? '---';
        final String orderNumber = (record['order_number'] ?? record['orderNumber'])?.toString() ?? '---';
        final String quantity = record['quantity']?.toString() ?? '---';
        final String startTime = (record['start_time'] ?? record['startTime'])?.toString() ?? '---';
        final String endTime = (record['end_time'] ?? record['endTime'])?.toString() ?? '---';
        final String lineWaste = (record['line_waste'] ?? record['lineWaste'] ?? record['print_waste'] ?? record['printWaste'])?.toString() ?? '---';
        final String downtimeStart = (record['downtime_start'] ?? record['downtimeStart'])?.toString() ?? '---';
        final String downtimeEnd = (record['downtime_end'] ?? record['downtimeEnd'])?.toString() ?? '---';
        final String notes = record['notes']?.toString() ?? '---';

        pageRows.add(
          pw.Row(children: [
            buildTableDataCell('${startIndex + i + 1}', 20.0, arabicFont, isRightMost: true),
            buildTableDataCell(tName, techColWidth, arabicFont),
            buildTableDataCell(_formatDate(record['date']?.toString() ?? '---'), 52.0, arabicFont),
            buildTableDataCell(clientName, clientColWidth, arabicFont),
            buildTableDataCell(productName, productColWidth, arabicFont),
            buildTableDataCell(productCode, 45.0, arabicFont),
            buildTableDataCell(_getDimensionsOnly(record), 70.0, arabicFont),
            buildTableDataCell(orderNumber, 42.0, arabicFont),
            buildTableDataCell(quantity, 35.0, arabicFont),
            buildTableDataCell(startTime, 35.0, arabicFont),
            buildTableDataCell(endTime, 35.0, arabicFont, isSectionEnd: true),
            buildTableDataCell(lineWaste, 28.0, arabicFont),
            buildTableDataCell(_getWeightOnly(record), 32.0, arabicFont, isSectionEnd: true),
            buildTableDataCell(downtimeStart, 35.0, arabicFont),
            buildTableDataCell(downtimeEnd, 35.0, arabicFont, isSectionEnd: true),
            buildTableDataCell(notes, notesColWidth, arabicFont),
          ]),
        );
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(children: [
            pw.Text(ArabicPDFHelper.fixArabic(customTitle),
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 16)),
            pw.SizedBox(height: 10),
            _buildProductionHeader(
              clientWidth: clientColWidth,
              productWidth: productColWidth,
              techWidth: techColWidth,
              notesWidth: notesColWidth,
              font: arabicBoldFont,
            ),
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

pw.Widget _buildProductionHeader({
  required double clientWidth,
  required double productWidth,
  required double techWidth,
  required double notesWidth,
  required pw.Font font,
}) {
  return pw.Row(
    children: [
      _buildSpannedHeader('م', 20.0, font, isRightMost: true),
      _buildSpannedHeader('الفني', techWidth, font),
      _buildSpannedHeader('التاريخ', 52.0, font),
      _buildSpannedHeader('إسم العميل', clientWidth, font),
      _buildSpannedHeader('الصنف', productWidth, font),
      _buildSpannedHeader('كود الصنف', 45.0, font),
      _buildSpannedHeader('المقاس', 70.0, font),
      _buildSpannedHeader('أمر التشغيل', 42.0, font),
      _buildSpannedHeader('الإنتاج', 35.0, font),
      _buildGroupedHeader('وقت التشغيل', ['من', 'إلى'], [35.0, 35.0], font, isSectionEnd: true),
      _buildSpannedHeader('الهالك', 28.0, font),
      _buildSpannedHeader('الوزن', 32.0, font, isSectionEnd: true),
      _buildGroupedHeader('الأعطال', ['من', 'إلى'], [35.0, 35.0], font, isSectionEnd: true),
      _buildSpannedHeader('الملاحظات', notesWidth, font),
    ],
  );
}

// ---------------------------------
// دالة: تقرير إنتاج قسم التكسير (بدون ألوان أو طباعة، هالك فقط، مع إدراج رقم الفورمة)
// ---------------------------------
Future<Uint8List> _generateCrushingProductionPdfBytes(Map<String, dynamic> params) async {
  try {
    final List<dynamic> records = params['records'];
    final String customTitle = params['title']?.toString() ?? 'تقرير إنتاج التكسير';
    final arabicFont = pw.Font.ttf(params['font'].buffer.asByteData());
    final arabicBoldFont = pw.Font.ttf(params['bold'].buffer.asByteData());

    final pdf = pw.Document();
    const int recordsPerPage = 13;
    final int totalPages = (records.length / recordsPerPage).ceil();

    const double techColWidth = 55.0;
    const double clientColWidth = 75.0;
    const double productColWidth = 75.0;
    const double formNumColWidth = 60.0;
    // Fixed columns: م(20) + الفني(55) + التاريخ(52) + العميل(75) + الصنف(75) + كود(45) + رقم الفورمة(60) + المقاس(70) + أمر(45) + إنتاج(40) + تشغيل(70) + هالك(35) + أعطال(70) = 712
    const double notesColWidth = 810.0 - 712.0; // = 98.0

    for (int page = 0; page < totalPages; page++) {
      final int startIndex = page * recordsPerPage;
      final int endIndex = (page + 1) * recordsPerPage < records.length
          ? (page + 1) * recordsPerPage
          : records.length;

      final List<dynamic> pageRecords = records.sublist(startIndex, endIndex);
      final List<pw.Widget> pageRows = [];

      for (int i = 0; i < pageRecords.length; i++) {
        final record = pageRecords[i] as Map<String, dynamic>;

        final String tName = (record['technician_name'] ?? record['technicianName'])?.toString() ?? '---';
        final String formNumber = (record['form_number'] ?? record['formNumber'])?.toString() ?? '---';
        final String wasteValue = (record['line_waste'] ?? record['lineWaste'] ?? record['waste'] ?? record['wasteQuantity'] ?? record['waste_quantity'])?.toString() ?? '---';
        final String formNumDisplay = formNumber.trim().isEmpty || formNumber == 'null' ? '---' : formNumber;
        final String wasteDisplay = wasteValue.trim().isEmpty || wasteValue == 'null' ? '---' : wasteValue;
        final String clientName = (record['client_name'] ?? record['clientName'] ?? record['client'])?.toString() ?? '---';
        final String productName = (record['product_name'] ?? record['productName'] ?? record['product'])?.toString() ?? '---';
        final String productCode = (record['product_code'] ?? record['productCode'])?.toString() ?? '---';
        final String orderNumber = (record['order_number'] ?? record['orderNumber'])?.toString() ?? '---';
        final String quantity = record['quantity']?.toString() ?? '---';
        final String startTime = (record['start_time'] ?? record['startTime'])?.toString() ?? '---';
        final String endTime = (record['end_time'] ?? record['endTime'])?.toString() ?? '---';
        final String downtimeStart = (record['downtime_start'] ?? record['downtimeStart'])?.toString() ?? '---';
        final String downtimeEnd = (record['downtime_end'] ?? record['downtimeEnd'])?.toString() ?? '---';
        final String notes = record['notes']?.toString() ?? '---';

        pageRows.add(
          pw.Row(children: [
            buildTableDataCell('${startIndex + i + 1}', 20.0, arabicFont, isRightMost: true),
            buildTableDataCell(tName, techColWidth, arabicFont),
            buildTableDataCell(_formatDate(record['date']?.toString() ?? '---'), 52.0, arabicFont),
            buildTableDataCell(clientName, clientColWidth, arabicFont),
            buildTableDataCell(productName, productColWidth, arabicFont),
            buildTableDataCell(productCode, 45.0, arabicFont),
            buildTableDataCell(formNumDisplay, formNumColWidth, arabicFont),
            buildTableDataCell(_getDimensionsOnly(record), 70.0, arabicFont),
            buildTableDataCell(orderNumber, 45.0, arabicFont),
            buildTableDataCell(quantity, 40.0, arabicFont),
            buildTableDataCell(startTime, 35.0, arabicFont),
            buildTableDataCell(endTime, 35.0, arabicFont, isSectionEnd: true),
            buildTableDataCell(wasteDisplay, 35.0, arabicFont, isSectionEnd: true),
            buildTableDataCell(downtimeStart, 35.0, arabicFont),
            buildTableDataCell(downtimeEnd, 35.0, arabicFont, isSectionEnd: true),
            buildTableDataCell(notes, notesColWidth, arabicFont),
          ]),
        );
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(children: [
            pw.Text(ArabicPDFHelper.fixArabic(customTitle),
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 16)),
            pw.SizedBox(height: 10),
            _buildCrushingProductionHeader(
              clientWidth: clientColWidth,
              productWidth: productColWidth,
              techWidth: techColWidth,
              formNumWidth: formNumColWidth,
              notesWidth: notesColWidth,
              font: arabicBoldFont,
            ),
            pw.Column(children: pageRows),
          ]),
        ),
      ));
    }
    return await pdf.save();
  } catch (e) {
    debugPrint('❌ خطأ في _generateCrushingProductionPdfBytes: $e');
    return Uint8List(0);
  }
}

pw.Widget _buildCrushingProductionHeader({
  required double clientWidth,
  required double productWidth,
  required double techWidth,
  required double formNumWidth,
  required double notesWidth,
  required pw.Font font,
}) {
  return pw.Row(
    children: [
      _buildSpannedHeader('م', 20.0, font, isRightMost: true),
      _buildSpannedHeader('الفني', techWidth, font),
      _buildSpannedHeader('التاريخ', 52.0, font),
      _buildSpannedHeader('إسم العميل', clientWidth, font),
      _buildSpannedHeader('الصنف', productWidth, font),
      _buildSpannedHeader('كود الصنف', 45.0, font),
      _buildSpannedHeader('رقم الفورمة', formNumWidth, font),
      _buildSpannedHeader('المقاس', 70.0, font),
      _buildSpannedHeader('أمر التشغيل', 45.0, font),
      _buildSpannedHeader('الإنتاج', 40.0, font),
      _buildGroupedHeader('وقت التشغيل', ['من', 'إلى'], [35.0, 35.0], font, isSectionEnd: true),
      _buildSpannedHeader('الهالك', 35.0, font, isSectionEnd: true),
      _buildGroupedHeader('الأعطال', ['من', 'إلى'], [35.0, 35.0], font, isSectionEnd: true),
      _buildSpannedHeader('الملاحظات', notesWidth, font),
    ],
  );
}


// ---------------------------------
// دالة: تقرير الطباعة (مع أحبار)
// ---------------------------------
Future<Uint8List> _generateConsolidatedPrintingPdfBytes(Map<String, dynamic> params) async {
  try {
    final List<dynamic> records = params['records'];
    final String customTitle = params['title']?.toString() ?? 'تقرير إنتاج الطباعة';
    final arabicFont = pw.Font.ttf(params['font'].buffer.asByteData());
    final arabicBoldFont = pw.Font.ttf(params['bold'].buffer.asByteData());

    // حساب أقصى عدد ألوان موجود في أي تقرير واحد
    int maxColorsCount = 0;
    for (var record in records) {
      final List<dynamic> colors = record['colors'] ?? [];
      if (colors.length > maxColorsCount) {
        maxColorsCount = colors.length;
      }
    }

    final pdf = pw.Document();
    const int recordsPerPage = 13;
    final int totalPages = (records.length / recordsPerPage).ceil();

    // Width calculation: Total 810
    // Fixed columns: م(20), التاريخ(55), المقاس(70), العدد(40) = 185
    // Colors width: maxColorsCount * 35.0
    // Remaining = 810 - 185 - (colorsWidth)
    final double colorsWidth = maxColorsCount * 35.0;
    final double remainingWidth = 810 - 185 - colorsWidth;
    final double flexibleColWidth = (remainingWidth / 3).floorToDouble();

    for (int page = 0; page < totalPages; page++) {
      final int startIndex = page * recordsPerPage;
      final int endIndex = (page + 1) * recordsPerPage < records.length
          ? (page + 1) * recordsPerPage
          : records.length;

      final List<dynamic> pageRecords = records.sublist(startIndex, endIndex);
      final List<pw.Widget> pageRows = [];

      for (int i = 0; i < pageRecords.length; i++) {
        final record = pageRecords[i] as Map<String, dynamic>;
        
        final String clientName = (record['client_name'] ?? record['clientName'] ?? record['client'])?.toString() ?? '---';
        final String productName = (record['product_name'] ?? record['productName'] ?? record['product'])?.toString() ?? '---';
        final String quantity = record['quantity']?.toString() ?? '---';
        final String notes = record['notes']?.toString() ?? '---';

        pageRows.add(
          pw.Row(children: [
            buildTableDataCell('${startIndex + i + 1}', 20.0, arabicFont, isRightMost: true),
            buildTableDataCell(_formatDate(record['date']?.toString() ?? '---'), 55.0, arabicFont),
            buildTableDataCell(clientName, flexibleColWidth, arabicFont),
            buildTableDataCell(productName, flexibleColWidth, arabicFont),
            buildTableDataCell(_getDimensionsOnly(record), 70.0, arabicFont),
            
            // الأحبار المقسمة بديناميكية
            ...List.generate(maxColorsCount, (j) {
              final recordColors = record['colors'] as List? ?? [];
              String displayedName = '';
              String displayedQty = '';
              
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
                isSectionEnd: j == maxColorsCount - 1,
              );
            }),
            
            buildTableDataCell(quantity, 40.0, arabicFont),
            buildTableDataCell(notes, flexibleColWidth, arabicFont),
          ]),
        );
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(children: [
            pw.Text(ArabicPDFHelper.fixArabic(customTitle),
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 16)),
            pw.SizedBox(height: 10),
            _buildPrintingHeader(maxColorsCount: maxColorsCount, flexibleWidth: flexibleColWidth, font: arabicBoldFont),
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

pw.Widget _buildPrintingHeader({required int maxColorsCount, required double flexibleWidth, required pw.Font font}) {
  return pw.Row(
    children: [
      _buildSpannedHeader('م', 20.0, font, isRightMost: true),
      _buildSpannedHeader('التاريخ', 55.0, font),
      _buildSpannedHeader('إسم العميل', flexibleWidth, font),
      _buildSpannedHeader('الصنف', flexibleWidth, font),
      _buildSpannedHeader('المقاس', 70.0, font),
      if (maxColorsCount > 0)
        _buildSpannedHeader('كمية الحبر بالليتر', maxColorsCount * 35.0, font, isSectionEnd: true),
      _buildSpannedHeader('العدد', 40.0, font),
      _buildSpannedHeader('الملاحظات', flexibleWidth, font),
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
        right: const pw.BorderSide(width: 0.5, color: PdfColors.black),
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
        right: const pw.BorderSide(width: 0.5, color: PdfColors.black),
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

