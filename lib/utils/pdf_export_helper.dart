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
  final fileName = 'تقارير_الإنتاج_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
                fontFamily: 'Cairo',
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
      return value.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
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
        _buildHeaderCell('المقاس', arabicBoldFont),
        _buildHeaderCell('اسم الصنف', arabicBoldFont),
        _buildHeaderCell('كود الصنف', arabicBoldFont),
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
              alignment: pw.Alignment.centerRight,
              child: _buildInkMiniTable(colorEntries, arabicFont)),
          _buildCenteredDataCell(_getDimensionsOnly(record), arabicFont),
          _buildDataCell(record['product']?.toString() ?? '---', arabicFont),
          _buildDataCell(record['productCode']?.toString() ?? '---', arabicFont),
          _buildDataCell(record['clientName']?.toString() ?? '---', arabicFont),
          _buildDataCell(_formatDate(record['date']?.toString() ?? '---'), arabicFont),
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
          pw.Text(ArabicPDFHelper.fixArabic('تقارير الإنتاج'),
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 18)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2), // الملاحظات
              1: const pw.FixedColumnWidth(40), // العدد
              2: const pw.FixedColumnWidth(160), // كمية الحبر بالليتر
              3: const pw.FixedColumnWidth(80), // المقاس
              4: const pw.FixedColumnWidth(110), // اسم الصنف
              5: const pw.FixedColumnWidth(80), // كود الصنف
              6: const pw.FixedColumnWidth(110), // العميل
              7: const pw.FixedColumnWidth(80), // التاريخ
              8: const pw.FixedColumnWidth(30), // م
            },
            children: tableRows,
          ),
        ]),
      ),
    ));
  }
  return await pdf.save();
}

// الدوال المساعدة للبناء (Header, Data, MiniTable)
pw.Widget _buildHeaderCell(String text, pw.Font font) => pw.Container(
    alignment: pw.Alignment.centerRight,
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: pw.Text(ArabicPDFHelper.fixArabic(text),
        style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.white)));

pw.Widget _buildDataCell(String text, pw.Font font) => pw.Container(
    alignment: pw.Alignment.centerRight,
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Text(ArabicPDFHelper.fixArabic(text),
        style: pw.TextStyle(font: font, fontSize: 9)));

pw.Widget _buildCenteredDataCell(String text, pw.Font font) => pw.Container(
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Text(ArabicPDFHelper.fixArabic(text),
        style: pw.TextStyle(font: font, fontSize: 9)));

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
    child: pw.Text(ArabicPDFHelper.fixArabic(text),
        style: pw.TextStyle(font: font, fontSize: 7)));

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
