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
      final bytes = await compute(_generateCrushingProductionPdfBytes, {
        'records': safeRecords,
        'font': fontBytes,
        'bold': boldFontBytes,
        'title': params['title'] ?? 'تقرير إنتاج قسم التكسير',
      });
      return bytes.isEmpty ? null : bytes;
    }

    final bytes = await compute(_generateConsolidatedProductionPdfBytes, {
      'records': safeRecords,
      'font': fontBytes,
      'bold': boldFontBytes,
      'title': params['title'],
      'department': department,
    });
    return bytes.isEmpty ? null : bytes;
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

    final bytes = await compute(_generateConsolidatedPrintingPdfBytes, {
      'records': safeRecords,
      'font': fontBytes,
      'bold': boldFontBytes,
      'title': params['title'],
    });
    return bytes.isEmpty ? null : bytes;
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

String _formatTime(String t) {
  if (t.isEmpty || t == 'null' || t == '---') return '---';
  try {
    DateTime? dt = DateTime.tryParse(t);
    if (dt != null) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  } catch (_) {}
  return t;
}

int _compareRecordsByDateAndEndTime(Map<String, dynamic> a, Map<String, dynamic> b) {
  final String dateA = _formatDate((a['date'] ?? a['report_date'] ?? a['reportDate'])?.toString() ?? '');
  final String dateB = _formatDate((b['date'] ?? b['report_date'] ?? b['reportDate'])?.toString() ?? '');
  
  int dateCmp = dateA.compareTo(dateB);
  if (dateCmp != 0) return dateCmp;

  final String timeA = (a['end_time'] ?? a['endTime'] ?? a['run_time_end'] ?? a['runTimeEnd'])?.toString().trim() ?? '';
  final String timeB = (b['end_time'] ?? b['endTime'] ?? b['run_time_end'] ?? b['runTimeEnd'])?.toString().trim() ?? '';

  String normalizeTime(String t) {
    if (t.isEmpty || t == 'null') return '00:00';
    try {
      DateTime? dt = DateTime.tryParse(t);
      if (dt != null) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
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

// تنظيف النص من الحروف التي تُسبب خللاً في مكتبة bidi-2.0.13 عند توليد الـ PDF:
// 1. علامات الاتجاه (RTL/LTR marks)
// 2. التشكيل العربي (Non-Spacing Marks) التي تُشغّل خوارزمية _compose وتتسبب في RangeError
String _cleanForPdf(String text) {
  return text
      // علامات الاتجاه
      .replaceAll('\u200F', '')  // Right-to-Left Mark
      .replaceAll('\u200E', '')  // Left-to-Right Mark
      .replaceAll('\u200B', '')  // Zero Width Space
      .replaceAll('\u200C', '')  // Zero Width Non-Joiner
      .replaceAll('\u200D', '')  // Zero Width Joiner
      .replaceAll('\u202A', '')  // Left-to-Right Embedding
      .replaceAll('\u202B', '')  // Right-to-Left Embedding
      .replaceAll('\u202C', '')  // Pop Directional Formatting
      .replaceAll('\u202D', '')  // Left-to-Right Override
      .replaceAll('\u202E', '')  // Right-to-Left Override
      .replaceAll('\u2066', '')  // Left-to-Right Isolate
      .replaceAll('\u2067', '')  // Right-to-Left Isolate
      .replaceAll('\u2068', '')  // First Strong Isolate
      .replaceAll('\u2069', '')  // Pop Directional Isolate
      // التشكيل العربي (Arabic Diacritics / Non-Spacing Marks)
      // النطاق U+064B - U+065F: التنوين، الفتحة، الضمة، الكسرة، الشدة، السكون إلخ
      .replaceAllMapped(RegExp(r'[\u064B-\u065F\u0610-\u061A\u06D6-\u06ED\u0670]'), (_) => '');
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
    child: pw.Text(ArabicPDFHelper.fixArabic(_cleanForPdf(text)),
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
    final bool isProductionLine = params['department']?.toString() == 'production_line';

    final pdf = pw.Document();
    const int recordsPerPage = 13;
    final int totalPages = (records.length / recordsPerPage).ceil();

    for (int page = 0; page < totalPages; page++) {
      final int startIndex = page * recordsPerPage;
      final int endIndex = (page + 1) * recordsPerPage < records.length
          ? (page + 1) * recordsPerPage
          : records.length;

      final List<dynamic> pageRecords = records.sublist(startIndex, endIndex);
      final List<pw.TableRow> tableRows = [];

      // صف الرأس
      tableRows.add(_buildProductionHeaderRow(
        font: arabicBoldFont,
        isProductionLine: isProductionLine,
      ));

      for (int i = 0; i < pageRecords.length; i++) {
        final record = pageRecords[i] as Map<String, dynamic>;

        final String tName = (record['technician_name'] ?? record['technicianName'])?.toString() ?? '---';
        final crewRaw = record['crew_members'] ?? record['crewMembers'];
        final String crewDisplay = (crewRaw is List && crewRaw.isNotEmpty)
            ? crewRaw.map((e) => e.toString()).join(' / ')
            : '---';
        final String clientName = (record['client_name'] ?? record['clientName'] ?? record['customer_name'] ?? record['customerName'] ?? record['client'])?.toString() ?? '---';
        final String productName = (record['product_name'] ?? record['productName'] ?? record['item_name'] ?? record['itemName'] ?? record['product'])?.toString() ?? '---';
        final String productCode = (record['product_code'] ?? record['productCode'] ?? record['item_code'] ?? record['itemCode'])?.toString() ?? '---';
        final String orderNumber = (record['order_number'] ?? record['orderNumber'] ?? record['work_order'] ?? record['workOrder'])?.toString() ?? '---';
        final String quantity = (record['quantity'] ?? record['production_quantity'] ?? record['productionQuantity'])?.toString() ?? '---';
        final String startTime = _formatTime((record['start_time'] ?? record['startTime'] ?? record['run_time_start'] ?? record['runTimeStart'])?.toString() ?? '---');
        final String endTime = _formatTime((record['end_time'] ?? record['endTime'] ?? record['run_time_end'] ?? record['runTimeEnd'])?.toString() ?? '---');
        final String lineWaste = (record['line_waste'] ?? record['lineWaste'] ?? record['waste_quantity'] ?? record['wasteQuantity'])?.toString() ?? '---';
        final String printWaste = (record['print_waste'] ?? record['printWaste'])?.toString() ?? '---';
        final String downtimeStart = _formatTime((record['downtime_start'] ?? record['downtimeStart'])?.toString() ?? '---');
        final String downtimeEnd = _formatTime((record['downtime_end'] ?? record['downtimeEnd'])?.toString() ?? '---');
        final String notes = record['notes']?.toString() ?? '---';

        // الخلايا بالترتيب الطبيعي (م أولاً) ثم تُعكس للحصول على RTL
        final List<pw.Widget> rowCells = [
          _buildFlexCell('${startIndex + i + 1}', arabicFont),
          _buildFlexCell(tName, arabicFont),
          _buildFlexCell(_formatDate(record['date']?.toString() ?? '---'), arabicFont),
          if (isProductionLine) _buildFlexCell(crewDisplay, arabicFont), // طاقم التشغيل ← خط الإنتاج فقط
          _buildFlexCell(clientName, arabicFont),
          _buildFlexCell(productName, arabicFont),
          _buildFlexCell(productCode, arabicFont),
          _buildFlexCell(_getDimensionsOnly(record), arabicFont),
          _buildFlexCell(orderNumber, arabicFont),
          _buildFlexCell(quantity, arabicFont),
          _buildFlexCell(startTime, arabicFont),
          _buildFlexCell(endTime, arabicFont),
          if (isProductionLine)
            _buildFlexCell(lineWaste, arabicFont)
          else ...[
            _buildFlexCell(lineWaste, arabicFont),
            _buildFlexCell(printWaste, arabicFont),
          ],
          _buildFlexCell(downtimeStart, arabicFont),
          _buildFlexCell(downtimeEnd, arabicFont),
          _buildFlexCell(notes, arabicFont),
        ];
        tableRows.add(pw.TableRow(children: rowCells.reversed.toList()));
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(ArabicPDFHelper.fixArabic(customTitle),
                style: pw.TextStyle(font: arabicBoldFont, fontSize: 16),
                textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 10),
              pw.Table(
                columnWidths: _productionLineColumnWidths(isProductionLine),
                border: const pw.TableBorder(
                  top: pw.BorderSide(width: 0.5),
                  bottom: pw.BorderSide(width: 0.5),
                  left: pw.BorderSide(width: 0.5),
                  right: pw.BorderSide(width: 0.5),
                  horizontalInside: pw.BorderSide(width: 0.5),
                  verticalInside: pw.BorderSide(width: 0.5),
                ),
                children: tableRows,
              ),
            ],
          ),
        ),
      ));
    }
    return await pdf.save();
  } catch (e, st) {
    debugPrint('❌ خطأ في _generateConsolidatedProductionPdfBytes: $e\n$st');
    return Uint8List(0);
  }
}

/// خلية بيانات مرنة تُستخدم مع pw.Table
/// ارتفاع الصف يُحدَّد تلقائياً حسب المحتوى (بدون ارتفاع ثابت).
pw.Widget _buildFlexCell(String text, pw.Font font) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
    child: pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text(
        ArabicPDFHelper.fixArabic(_cleanForPdf(text)),
        style: pw.TextStyle(font: font, fontSize: 7.5),
        softWrap: true,
        textAlign: pw.TextAlign.center,
      ),
    ),
  );
}

/// خلية رأس مرنة تُستخدم مع pw.Table
pw.Widget _buildFlexHeaderCell(String text, pw.Font font, {bool isGroupTitle = false}) {
  return pw.Container(
    color: isGroupTitle ? PdfColors.grey200 : PdfColors.grey300,
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
    child: pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text(
        ArabicPDFHelper.fixArabic(text),
        style: pw.TextStyle(font: font, fontSize: 8),
        softWrap: true,
        textAlign: pw.TextAlign.center,
      ),
    ),
  );
}

/// يعكس خريطة عروض الأعمدة لتناسب الترتيب من اليمين لليسار.
/// pw.Table لا يعكس الأعمدة تلقائياً مع Directionality(rtl)،
/// لذا نعكس الأعمدة يدوياً عبر هذه الدالة + عكس children في كل TableRow.
Map<int, pw.TableColumnWidth> _reverseColumnWidths(Map<int, pw.TableColumnWidth> widths) {
  final int maxKey = widths.keys.reduce((a, b) => a > b ? a : b);
  return { for (final e in widths.entries) (maxKey - e.key): e.value };
}

// الترتيب الأصلي (LTR index) للأعمدة — يُعكس لاحقاً بـ _reverseColumnWidths للحصول على RTL.
Map<int, pw.TableColumnWidth> _productionLineColumnWidths(bool isProductionLine) {
  if (isProductionLine) {
    // 16 عمود (indices 0-15): م | الفني | التاريخ | طاقم التشغيل | إسم العميل | ... | الملاحظات
    return _reverseColumnWidths({
      0:  const pw.FixedColumnWidth(22),   // م
      1:  const pw.FlexColumnWidth(2.0),   // الفني
      2:  const pw.FixedColumnWidth(54),   // التاريخ
      3:  const pw.FlexColumnWidth(3.5),   // طاقم التشغيل  ← خط الإنتاج فقط
      4:  const pw.FlexColumnWidth(3.5),   // إسم العميل
      5:  const pw.FlexColumnWidth(3.5),   // الصنف
      6:  const pw.FixedColumnWidth(46),   // كود الصنف
      7:  const pw.FixedColumnWidth(68),   // المقاس
      8:  const pw.FixedColumnWidth(43),   // أمر التشغيل
      9:  const pw.FixedColumnWidth(36),   // الإنتاج
      10: const pw.FixedColumnWidth(36),   // من (التشغيل)
      11: const pw.FixedColumnWidth(36),   // إلى (التشغيل)
      12: const pw.FixedColumnWidth(55),   // الهالك
      13: const pw.FixedColumnWidth(36),   // من (الأعطال)
      14: const pw.FixedColumnWidth(36),   // إلى (الأعطال)
      15: const pw.FlexColumnWidth(3.0),   // الملاحظات
    });
  } else {
    // 16 عمود (فلكسو — بدون طاقم التشغيل): indices 0-15
    return _reverseColumnWidths({
      0:  const pw.FixedColumnWidth(22),   // م
      1:  const pw.FlexColumnWidth(2.0),   // الفني
      2:  const pw.FixedColumnWidth(54),   // التاريخ
      3:  const pw.FlexColumnWidth(3.5),   // إسم العميل
      4:  const pw.FlexColumnWidth(3.5),   // الصنف
      5:  const pw.FixedColumnWidth(46),   // كود الصنف
      6:  const pw.FixedColumnWidth(68),   // المقاس
      7:  const pw.FixedColumnWidth(43),   // أمر التشغيل
      8:  const pw.FixedColumnWidth(36),   // الإنتاج
      9:  const pw.FixedColumnWidth(36),   // من (التشغيل)
      10: const pw.FixedColumnWidth(36),   // إلى (التشغيل)
      11: const pw.FixedColumnWidth(30),   // هالك خ
      12: const pw.FixedColumnWidth(30),   // هالك ط
      13: const pw.FixedColumnWidth(36),   // من (الأعطال)
      14: const pw.FixedColumnWidth(36),   // إلى (الأعطال)
      15: const pw.FlexColumnWidth(3.0),   // الملاحظات
    });
  }
}

// الترتيب المنطقي للأعمدة من اليمين لليسار:
// م | الفني | التاريخ | طاقم التشغيل | إسم العميل | الصنف | ... | الملاحظات
// الـ children في TableRow تُعكس (.reversed) لتوافق RTL.
pw.TableRow _buildProductionHeaderRow({required pw.Font font, required bool isProductionLine}) {
  final List<pw.Widget> cells = [
    _buildFlexHeaderCell('م', font),
    _buildFlexHeaderCell('الفني', font),
    _buildFlexHeaderCell('التاريخ', font),
    if (isProductionLine) _buildFlexHeaderCell('طاقم التشغيل', font), // خط الإنتاج فقط
    _buildFlexHeaderCell('إسم العميل', font),
    _buildFlexHeaderCell('الصنف', font),
    _buildFlexHeaderCell('كود الصنف', font),
    _buildFlexHeaderCell('المقاس', font),
    _buildFlexHeaderCell('أمر التشغيل', font),
    _buildFlexHeaderCell('الإنتاج', font),
    _buildFlexHeaderCell('من', font),
    _buildFlexHeaderCell('إلى', font),
    if (isProductionLine)
      _buildFlexHeaderCell('الهالك', font)
    else ...[
      _buildFlexHeaderCell('هالك خ', font),
      _buildFlexHeaderCell('هالك ط', font),
    ],
    _buildFlexHeaderCell('من', font),
    _buildFlexHeaderCell('إلى', font),
    _buildFlexHeaderCell('الملاحظات', font),
  ];
  return pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
    children: cells.reversed.toList(),
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

    // أعمدة الجدول باستخدام FlexColumnWidth لتوزيع المساحة على عرض A4 Landscape بالكامل.
    // الترتيب: م | الفني | التاريخ | طاقم التشغيل | إسم العميل | الصنف |
    //          كود الصنف | رقم الفورمة | المقاس | أمر التشغيل | الإنتاج |
    //          من(تشغيل) | إلى(تشغيل) | الهالك | من(أعطال) | إلى(أعطال) | الملاحظات
    // عروض الأعمدة معكوسة لـ RTL (17 عمود: indices 0-16 بعد العكس)
    final Map<int, pw.TableColumnWidth> crushingColumnWidths = _reverseColumnWidths({
      0:  const pw.FixedColumnWidth(22),    // م
      1:  const pw.FlexColumnWidth(2.0),    // الفني
      2:  const pw.FixedColumnWidth(54),    // التاريخ
      3:  const pw.FlexColumnWidth(3.5),    // طاقم التشغيل
      4:  const pw.FlexColumnWidth(3.5),    // إسم العميل
      5:  const pw.FlexColumnWidth(3.5),    // الصنف
      6:  const pw.FixedColumnWidth(46),    // كود الصنف
      7:  const pw.FixedColumnWidth(55),    // رقم الفورمة
      8:  const pw.FixedColumnWidth(65),    // المقاس
      9:  const pw.FixedColumnWidth(43),    // أمر التشغيل
      10: const pw.FixedColumnWidth(36),    // الإنتاج
      11: const pw.FixedColumnWidth(36),    // من (التشغيل)
      12: const pw.FixedColumnWidth(36),    // إلى (التشغيل)
      13: const pw.FixedColumnWidth(36),    // الهالك
      14: const pw.FixedColumnWidth(36),    // من (الأعطال)
      15: const pw.FixedColumnWidth(36),    // إلى (الأعطال)
      16: const pw.FlexColumnWidth(3.0),    // الملاحظات
    });

    for (int page = 0; page < totalPages; page++) {
      final int startIndex = page * recordsPerPage;
      final int endIndex = (page + 1) * recordsPerPage < records.length
          ? (page + 1) * recordsPerPage
          : records.length;

      final List<dynamic> pageRecords = records.sublist(startIndex, endIndex);
      final List<pw.TableRow> tableRows = [];

      // صف الرأس
      tableRows.add(_buildCrushingHeaderRow(font: arabicBoldFont));

      for (int i = 0; i < pageRecords.length; i++) {
        final record = pageRecords[i] as Map<String, dynamic>;

        final String tName = (record['technician_name'] ?? record['technicianName'])?.toString() ?? '---';
        final crewRaw = record['crew_members'] ?? record['crewMembers'];
        final String crewDisplay = (crewRaw is List && crewRaw.isNotEmpty)
            ? crewRaw.map((e) => e.toString()).join(' / ')
            : '---';
        final String formNumber = (record['form_number'] ?? record['formNumber'])?.toString() ?? '---';
        final String wasteValue = (record['line_waste'] ?? record['lineWaste'] ?? record['waste'] ?? record['wasteQuantity'] ?? record['waste_quantity'])?.toString() ?? '---';
        final String formNumDisplay = formNumber.trim().isEmpty || formNumber == 'null' ? '---' : formNumber;
        final String wasteDisplay = wasteValue.trim().isEmpty || wasteValue == 'null' ? '---' : wasteValue;
        final String clientName = (record['client_name'] ?? record['clientName'] ?? record['client'] ?? record['customer_name'] ?? record['customerName'])?.toString() ?? '---';
        final String productName = (record['product_name'] ?? record['productName'] ?? record['product'] ?? record['item_name'] ?? record['itemName'])?.toString() ?? '---';
        final String productCode = (record['product_code'] ?? record['productCode'] ?? record['item_code'] ?? record['itemCode'])?.toString() ?? '---';
        final String orderNumber = (record['order_number'] ?? record['orderNumber'] ?? record['work_order'] ?? record['workOrder'])?.toString() ?? '---';
        final String quantity = (record['quantity'] ?? record['production_quantity'] ?? record['productionQuantity'])?.toString() ?? '---';
        final String startTime = _formatTime((record['start_time'] ?? record['startTime'] ?? record['run_time_start'] ?? record['runTimeStart'])?.toString() ?? '---');
        final String endTime = _formatTime((record['end_time'] ?? record['endTime'] ?? record['run_time_end'] ?? record['runTimeEnd'])?.toString() ?? '---');
        final String downtimeStart = _formatTime((record['downtime_start'] ?? record['downtimeStart'])?.toString() ?? '---');
        final String downtimeEnd = _formatTime((record['downtime_end'] ?? record['downtimeEnd'])?.toString() ?? '---');
        final String notes = record['notes']?.toString() ?? '---';
        final String dateStr = (record['date'] ?? record['report_date'] ?? record['reportDate'])?.toString() ?? '---';

        // الخلايا بالترتيب الطبيعي (م أولاً) ثم تُعكس للحصول على RTL
        final List<pw.Widget> rowCells = [
          _buildFlexCell('${startIndex + i + 1}', arabicFont),
          _buildFlexCell(tName, arabicFont),
          _buildFlexCell(_formatDate(dateStr), arabicFont),
          _buildFlexCell(crewDisplay, arabicFont),
          _buildFlexCell(clientName, arabicFont),
          _buildFlexCell(productName, arabicFont),
          _buildFlexCell(productCode, arabicFont),
          _buildFlexCell(formNumDisplay, arabicFont),
          _buildFlexCell(_getDimensionsOnly(record), arabicFont),
          _buildFlexCell(orderNumber, arabicFont),
          _buildFlexCell(quantity, arabicFont),
          _buildFlexCell(startTime, arabicFont),
          _buildFlexCell(endTime, arabicFont),
          _buildFlexCell(wasteDisplay, arabicFont),
          _buildFlexCell(downtimeStart, arabicFont),
          _buildFlexCell(downtimeEnd, arabicFont),
          _buildFlexCell(notes, arabicFont),
        ];
        tableRows.add(pw.TableRow(children: rowCells.reversed.toList()));
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(ArabicPDFHelper.fixArabic(customTitle),
                style: pw.TextStyle(font: arabicBoldFont, fontSize: 16),
                textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 10),
              pw.Table(
                columnWidths: crushingColumnWidths,
                border: const pw.TableBorder(
                  top: pw.BorderSide(width: 0.5),
                  bottom: pw.BorderSide(width: 0.5),
                  left: pw.BorderSide(width: 0.5),
                  right: pw.BorderSide(width: 0.5),
                  horizontalInside: pw.BorderSide(width: 0.5),
                  verticalInside: pw.BorderSide(width: 0.5),
                ),
                children: tableRows,
              ),
            ],
          ),
        ),
      ));
    }
    return await pdf.save();
  } catch (e) {
    debugPrint('❌ خطأ في _generateCrushingProductionPdfBytes: $e');
    return Uint8List(0);
  }
}

pw.TableRow _buildCrushingHeaderRow({required pw.Font font}) {
  final List<pw.Widget> cells = [
    _buildFlexHeaderCell('م', font),
    _buildFlexHeaderCell('الفني', font),
    _buildFlexHeaderCell('التاريخ', font),
    _buildFlexHeaderCell('طاقم التشغيل', font),
    _buildFlexHeaderCell('إسم العميل', font),
    _buildFlexHeaderCell('الصنف', font),
    _buildFlexHeaderCell('كود الصنف', font),
    _buildFlexHeaderCell('رقم الفورمة', font),
    _buildFlexHeaderCell('المقاس', font),
    _buildFlexHeaderCell('أمر التشغيل', font),
    _buildFlexHeaderCell('الإنتاج', font),
    _buildFlexHeaderCell('من', font),
    _buildFlexHeaderCell('إلى', font),
    _buildFlexHeaderCell('الهالك', font),
    _buildFlexHeaderCell('من', font),
    _buildFlexHeaderCell('إلى', font),
    _buildFlexHeaderCell('الملاحظات', font),
  ];
  return pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
    children: cells.reversed.toList(),
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
  } catch (e, st) {
    debugPrint('❌ خطأ في _generateConsolidatedPrintingPdfBytes: $e\n$st');
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

