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
        ScaffoldMessenger,
        BuildContext,
        Colors,
        Text,
        SnackBarAction;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

/// ✅ الدالة الجديدة: توليد بيانات PDF وإرجاعها كـ Bytes لاستخدامها في FilePicker
/// هذه الدالة تحل مشكلة الخطأ "method not defined" في ملف الشاشة
Future<Uint8List?> generateInkReportPdfBytes(
    List<Map<String, dynamic>> records) async {
  if (records.isEmpty) return null;

  try {
    // تحميل الخطوط لدعم اللغة العربية
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");

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
    debugPrint('❌ خطأ في generateInkReportPdfBytes: $e');
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

/// ✅ حفظ PDF في الذاكرة الداخلية للهاتف (تلقائي)
Future<void> savePdfToDevice(
    BuildContext context, List<Map<String, dynamic>> records) async {
  if (records.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ لا توجد تقارير لحفظها")),
    );
    return;
  }

  var status = await Permission.storage.status;
  if (!status.isGranted) {
    status = await Permission.storage.request();
  }

  final hasPermission = status.isGranted;

  // إذا لم يتوفر إذن التخزين الخارجي سنحفظ داخلياً
  final Uint8List? pdfBytes = await generateInkReportPdfBytes(records);
  if (pdfBytes == null) return;

  try {
    String filePath;
    if (hasPermission && Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final appDir = Directory('${directory.path}/SmartSheet/Reports');
        if (!await appDir.exists()) await appDir.create(recursive: true);
        final fileName =
            'تقارير_الحبر_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${appDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        filePath = file.path;
      } else {
        filePath = await _saveToInternalStorage(pdfBytes);
      }
    } else {
      filePath = await _saveToInternalStorage(pdfBytes);
    }

    _showSuccessSnackBar(context, filePath, pdfBytes);
  } catch (e) {
    debugPrint('❌ خطأ في حفظ PDF: $e');
  }
}

Future<String> _saveToInternalStorage(Uint8List pdfBytes) async {
  final directory = await getApplicationDocumentsDirectory();
  final appDir = Directory('${directory.path}/SmartSheet/Reports');
  if (!await appDir.exists()) await appDir.create(recursive: true);
  final fileName = 'تقارير_الحبر_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final file = File('${appDir.path}/$fileName');
  await file.writeAsBytes(pdfBytes);
  return file.path;
}

void _showSuccessSnackBar(
    BuildContext context, String filePath, Uint8List bytes) {
  final fileName = filePath.split('/').last;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('✅ تم حفظ PDF بنجاح\n$fileName'),
      backgroundColor: Colors.green,
      action: SnackBarAction(
        label: 'فتح',
        textColor: Colors.white,
        onPressed: () => OpenFile.open(filePath),
      ),
    ),
  );
}

/// تصدير ومشاركة PDF
Future<void> exportReportsToPdf(
    BuildContext context, List<Map<String, dynamic>> records) async {
  final pdfBytes = await generateInkReportPdfBytes(records);
  if (pdfBytes != null) {
    final fileName =
        'تقارير_الحبر_${DateTime.now().millisecondsSinceEpoch}.pdf';
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

String _buildProductWithDimensions(Map<String, dynamic> record) {
  final product = record['product']?.toString() ?? '---';
  final dimensions = record['dimensions'];
  String dimensionsStr = '';

  if (dimensions is Map) {
    final length = dimensions['length']?.toString() ?? '';
    final width = dimensions['width']?.toString() ?? '';
    final height = dimensions['height']?.toString() ?? '';

    String formatNumber(String value) {
      if (value.isEmpty) return '';
      if (value.contains('.')) {
        final parts = value.split('.');
        if (parts.length > 1 && parts[1] == '0') return parts[0];
        return value
            .replaceAll(RegExp(r'0*$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }
      return value;
    }

    final fL = formatNumber(length);
    final fW = formatNumber(width);
    final fH = formatNumber(height);

    if (fL.isNotEmpty && fW.isNotEmpty && fH.isNotEmpty) {
      dimensionsStr = '$fL/$fW/$fH';
    }
  }

  return dimensionsStr.isEmpty ? product : '$product\n$dimensionsStr';
}

Future<Uint8List> _generateConsolidatedPdfBytes(
    Map<String, dynamic> params) async {
  final List<dynamic> records = params['records'];
  final arabicFont = pw.Font.ttf(params['font'].buffer.asByteData());
  final arabicBoldFont = pw.Font.ttf(params['bold'].buffer.asByteData());

  final pdf = pw.Document();
  const int recordsPerPage = 9;
  final int totalPages = (records.length / recordsPerPage).ceil();

  for (int page = 0; page < totalPages; page++) {
    final int startIndex = page * recordsPerPage;
    final int endIndex = (page + 1) * recordsPerPage < records.length
        ? (page + 1) * recordsPerPage
        : records.length;

    final List<dynamic> pageRecords = records.sublist(startIndex, endIndex);
    final tableRows = <pw.TableRow>[];

    // رأس الجدول
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF38761D)),
      children: [
        _buildHeaderCell('الملاحظات', arabicBoldFont),
        _buildHeaderCell('العدد', arabicBoldFont),
        _buildHeaderCell('كمية الحبر بالليتر', arabicBoldFont),
        _buildHeaderCell('الصنف', arabicBoldFont),
        _buildHeaderCell('العميل', arabicBoldFont),
        _buildHeaderCell('التاريخ', arabicBoldFont),
        _buildHeaderCell('م', arabicBoldFont),
      ],
    ));

    for (int i = 0; i < pageRecords.length; i++) {
      final record = pageRecords[i] as Map<String, dynamic>;
      final List<dynamic> colors = record['colors'] ?? [];
      final List<Map<String, String>> colorEntries = colors
          .map((c) => {
                'color': c['color']?.toString() ?? '---',
                'quantity': c['quantity']?.toString() ?? '---',
              })
          .toList();
      while (colorEntries.length < 3) {
        colorEntries.add({'color': '---', 'quantity': '---'});
      }

      tableRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(
            color:
                i.isOdd ? const PdfColor.fromInt(0xFFF5F5F5) : PdfColors.white),
        children: [
          _buildDataCell(record['notes']?.toString() ?? '---', arabicFont),
          _buildDataCell(record['quantity']?.toString() ?? '---', arabicFont),
          pw.Container(
              alignment: pw.Alignment.center,
              child: _buildInkMiniTable(colorEntries, arabicFont)),
          _buildDataCell(_buildProductWithDimensions(record), arabicFont),
          _buildDataCell(record['clientName']?.toString() ?? '---', arabicFont),
          _buildDataCell(
              _formatDate(record['date']?.toString() ?? '---'), arabicFont),
          _buildDataCell('${startIndex + i + 1}', arabicFont),
        ],
      ));
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(16),
      build: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(children: [
          pw.Text('تقارير طباعة الأحبار',
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 18)),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(180),
                3: const pw.FixedColumnWidth(100),
                4: const pw.FixedColumnWidth(100),
                5: const pw.FixedColumnWidth(80),
                6: const pw.FixedColumnWidth(40),
              },
              children: tableRows,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                  top: pw.BorderSide(width: 1, color: PdfColors.grey)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'صفحة ${page + 1} من $totalPages',
                  style: pw.TextStyle(font: arabicFont, fontSize: 10),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  'عدد التقارير: ${records.length}',
                  style: pw.TextStyle(font: arabicFont, fontSize: 10),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          ),
        ]),
      ),
    ));
  }
  return await pdf.save();
}

// الدوال المساعدة للبناء (Header, Data, MiniTable)
pw.Widget _buildHeaderCell(String text, pw.Font font) => pw.Container(
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(text,
        style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.white)));

pw.Widget _buildDataCell(String text, pw.Font font) => pw.Container(
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)));

pw.Widget _buildInkMiniTable(List<Map<String, String>> entries, pw.Font font) {
  return pw.Table(
    border: pw.TableBorder.all(width: 0.3),
    children: [
      pw.TableRow(
          children: entries
              .take(3)
              .map((e) => _miniCell(e['color']!, font))
              .toList()),
      pw.TableRow(
          children: entries
              .take(3)
              .map((e) => _miniCell(e['quantity']!, font))
              .toList()),
    ],
  );
}

pw.Widget _miniCell(String text, pw.Font font) => pw.Container(
    width: 60,
    height: 18,
    alignment: pw.Alignment.center,
    child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 7)));

// دالة توليد تقرير فردي لـ Isolate
Future<Uint8List> _generateSingleReportPdfBytes(
    Map<String, dynamic> params) async {
  // نفس منطق Consolidated ولكن لسجل واحد فقط (مختصر)
  return await _generateConsolidatedPdfBytes({
    'records': [params['record']],
    'font': params['font'],
    'bold': params['bold']
  });
}
