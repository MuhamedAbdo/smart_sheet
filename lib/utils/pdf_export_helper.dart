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

/// ✅ حفظ PDF في الذاكرة الداخلية للهاتف
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

  if (!hasPermission) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("ℹ️ سيتم حفظ الملف في المسار الداخلي للتطبيق"),
        backgroundColor: Colors.blue,
      ),
    );
  }

  final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
  final boldFontData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");

  final Uint8List fontBytes = fontData.buffer
      .asUint8List(fontData.offsetInBytes, fontData.lengthInBytes);
  final Uint8List boldFontBytes = boldFontData.buffer
      .asUint8List(boldFontData.offsetInBytes, boldFontData.lengthInBytes);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("⏳ جاري إنشاء وحفظ ملف PDF...")),
  );

  try {
    final safeRecords = records.map((r) => toSerializableMap(r)).toList();

    final Uint8List pdfBytes = await compute(_generateConsolidatedPdfBytes, {
      'records': safeRecords,
      'font': fontBytes,
      'bold': boldFontBytes,
    });

    String filePath;

    if (hasPermission && Platform.isAndroid) {
      try {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final appDir = Directory('${directory.path}/SmartSheet/Reports');
          if (!await appDir.exists()) {
            await appDir.create(recursive: true);
          }
          final fileName =
              'تقارير_الحبر_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File('${appDir.path}/$fileName');
          await file.writeAsBytes(pdfBytes);
          filePath = file.path;
        } else {
          throw Exception('لا يمكن الوصول إلى التخزين الخارجي');
        }
      } catch (e) {
        debugPrint('❌ خطأ في الحفظ الخارجي: $e');
        filePath = await _saveToInternalStorage(pdfBytes);
      }
    } else {
      filePath = await _saveToInternalStorage(pdfBytes);
    }

    final fileName = filePath.split('/').last;
    final displayPath = filePath.contains('files')
        ? 'المسار الداخلي للتطبيق'
        : 'التخزين الخارجي';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم حفظ PDF بنجاح في $displayPath\n$fileName'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'فتح الملف',
          textColor: Colors.white,
          onPressed: () async {
            try {
              await OpenFile.open(filePath);
            } catch (e) {
              try {
                await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
              } catch (e2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تعذر فتح الملف، تم حفظه في: $fileName'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          },
        ),
      ),
    );

    debugPrint('✅ تم حفظ الملف بنجاح في: $filePath');
    debugPrint('📁 حجم الملف: ${pdfBytes.length} بايت');
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ خطأ في حفظ PDF: $e'),
        backgroundColor: Colors.red,
      ),
    );
    debugPrint('❌ خطأ في حفظ PDF: $e');
  }
}

/// ✅ دالة مساعدة للحفظ في المسار الداخلي
Future<String> _saveToInternalStorage(Uint8List pdfBytes) async {
  final directory = await getApplicationDocumentsDirectory();
  final appDir = Directory('${directory.path}/SmartSheet/Reports');
  if (!await appDir.exists()) {
    await appDir.create(recursive: true);
  }
  final fileName = 'تقارير_الحبر_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final file = File('${appDir.path}/$fileName');
  await file.writeAsBytes(pdfBytes);
  return file.path;
}

/// تصدير تقارير متعددة إلى PDF واحد
Future<void> exportReportsToPdf(
    BuildContext context, List<Map<String, dynamic>> records) async {
  if (records.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ لا توجد تقارير لتصديرها")),
    );
    return;
  }

  final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
  final boldFontData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");

  final Uint8List fontBytes = fontData.buffer
      .asUint8List(fontData.offsetInBytes, fontData.lengthInBytes);
  final Uint8List boldFontBytes = boldFontData.buffer
      .asUint8List(boldFontData.offsetInBytes, boldFontData.lengthInBytes);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("⏳ جاري إنشاء ملف PDF...")),
  );

  try {
    final safeRecords = records.map((r) => toSerializableMap(r)).toList();

    final Uint8List pdfBytes = await compute(_generateConsolidatedPdfBytes, {
      'records': safeRecords,
      'font': fontBytes,
      'bold': boldFontBytes,
    });

    final directory = await getTemporaryDirectory();
    final fileName =
        'تقارير_الحبر_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم إنشاء ومشاركة PDF بنجاح ($fileName)'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ خطأ في إنشاء PDF: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// تصدير تقرير واحد
Future<void> exportReportToPdf(BuildContext context,
    Map<String, dynamic> record, List<String> imagePaths) async {
  final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
  final boldFontData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");

  final Uint8List fontBytes = fontData.buffer
      .asUint8List(fontData.offsetInBytes, fontData.lengthInBytes);
  final Uint8List boldFontBytes = boldFontData.buffer
      .asUint8List(boldFontData.offsetInBytes, boldFontData.lengthInBytes);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("⏳ جاري إنشاء ملف التقرير...")),
  );

  try {
    final safeRecord = toSerializableMap(record);

    final Uint8List pdfBytes = await compute(_generateSingleReportPdfBytes, {
      'record': safeRecord,
      'font': fontBytes,
      'bold': boldFontBytes,
    });

    final directory = await getTemporaryDirectory();
    final reportDate =
        safeRecord['date']?.toString().replaceAll('/', '-') ?? 'NoDate';
    final fileName =
        'تقرير_حبر_${_formatDate(reportDate)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم إنشاء التقرير ($fileName)'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ خطأ في التقرير: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// ---------------------------------
// دوال Isolate
// ---------------------------------

Future<Uint8List> _generateConsolidatedPdfBytes(
    Map<String, dynamic> params) async {
  final List<dynamic> records = params['records'] as List<dynamic>;
  final Uint8List fontBytes = params['font'] as Uint8List;
  final Uint8List boldBytes = params['bold'] as Uint8List;

  final arabicFont = pw.Font.ttf(fontBytes.buffer
      .asByteData(fontBytes.offsetInBytes, fontBytes.lengthInBytes));
  final arabicBoldFont = pw.Font.ttf(boldBytes.buffer
      .asByteData(boldBytes.offsetInBytes, boldBytes.lengthInBytes));

  final pdf = pw.Document();

  // ✅ الآن: كل صفحة تحتوي على 10 صفوف رئيسية (خلاف صف العنوان)
  const int recordsPerPage = 10;
  final int totalPages = (records.length / recordsPerPage).ceil();

  for (int page = 0; page < totalPages; page++) {
    final int startIndex = page * recordsPerPage;
    final int endIndex = (page + 1) * recordsPerPage < records.length
        ? (page + 1) * recordsPerPage
        : records.length;

    final List<dynamic> pageRecords = records.sublist(startIndex, endIndex);

    final tableRows = <pw.TableRow>[];

    // ✅ رأس الجدول الرئيسي
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFF38761D),
        ),
        children: [
          _buildHeaderCell('الملاحظات', arabicBoldFont),
          _buildHeaderCell('العدد', arabicBoldFont),
          _buildHeaderCell('كمية الحبر بالليتر', arabicBoldFont),
          _buildHeaderCell('الصنف', arabicBoldFont),
          _buildHeaderCell('العميل', arabicBoldFont),
          _buildHeaderCell('التاريخ', arabicBoldFont),
          _buildHeaderCell('م', arabicBoldFont),
        ],
      ),
    );

    // صفوف البيانات للصفحة الحالية
    for (int i = 0; i < pageRecords.length; i++) {
      final record = pageRecords[i] as Map<String, dynamic>;
      final List<dynamic> colors = (record['colors'] is List)
          ? List<dynamic>.from(record['colors'])
          : [];

      final List<Map<String, String>> colorEntries = [];
      for (int j = 0; j < colors.length; j++) {
        final colorMap = colors[j] as Map<String, dynamic>;
        colorEntries.add({
          'color': colorMap['color']?.toString() ?? '---',
          'quantity': colorMap['quantity']?.toString() ?? '---',
        });
      }

      while (colorEntries.length < 3) {
        colorEntries.add({'color': '---', 'quantity': '---'});
      }

      final inkTable = pw.Container(
        width: 180,
        child: pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(60),
            1: const pw.FixedColumnWidth(60),
            2: const pw.FixedColumnWidth(60),
          },
          border: pw.TableBorder.all(
            color: PdfColors.black,
            width: 0.5,
          ),
          children: [
            pw.TableRow(
              children: [
                _buildInkTableCell(colorEntries[0]['color']!, arabicFont, 60),
                _buildInkTableCell(colorEntries[1]['color']!, arabicFont, 60),
                _buildInkTableCell(colorEntries[2]['color']!, arabicFont, 60),
              ],
            ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
                ),
              ),
              children: [
                pw.Container(height: 0.5),
                pw.Container(height: 0.5),
                pw.Container(height: 0.5),
              ],
            ),
            pw.TableRow(
              children: [
                _buildInkTableCell(
                    colorEntries[0]['quantity']!, arabicFont, 60),
                _buildInkTableCell(
                    colorEntries[1]['quantity']!, arabicFont, 60),
                _buildInkTableCell(
                    colorEntries[2]['quantity']!, arabicFont, 60),
              ],
            ),
          ],
        ),
      );

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color:
                i.isOdd ? const PdfColor.fromInt(0xFFF5F5F5) : PdfColors.white,
          ),
          children: [
            _buildDataCell(record['notes']?.toString() ?? '---', arabicFont),
            _buildDataCell(record['quantity']?.toString() ?? '---', arabicFont),
            pw.Container(
              alignment: pw.Alignment.center,
              child: inkTable,
            ),
            _buildDataCell(record['product']?.toString() ?? '---', arabicFont),
            _buildDataCell(
                record['clientName']?.toString() ?? '---', arabicFont),
            _buildDataCell(
                _formatDate(record['date']?.toString() ?? '---'), arabicFont),
            // رقم المسلسل يُحتسب عبر الفهرس الكلي: startIndex + i + 1
            _buildDataCell('${startIndex + i + 1}', arabicFont),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 16),
                  alignment: pw.Alignment.center,
                  child: pw.Text('تقارير طباعة الأحبار',
                      style: pw.TextStyle(
                          font: arabicBoldFont,
                          fontSize: 18,
                          color: PdfColors.black)),
                ),
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.black,
                      width: 0.5,
                    ),
                    defaultVerticalAlignment:
                        pw.TableCellVerticalAlignment.middle,
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
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 16),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'عدد التقارير: ${records.length}',
                        style: pw.TextStyle(font: arabicFont, fontSize: 10),
                      ),
                      pw.Text(
                        'الصفحة ${page + 1} من $totalPages',
                        style: pw.TextStyle(font: arabicFont, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  return await pdf.save();
}

Future<Uint8List> _generateSingleReportPdfBytes(
    Map<String, dynamic> params) async {
  final Map<String, dynamic> record =
      Map<String, dynamic>.from(params['record'] as Map);
  final Uint8List fontBytes = params['font'] as Uint8List;
  final Uint8List boldBytes = params['bold'] as Uint8List;

  final arabicFont = pw.Font.ttf(fontBytes.buffer
      .asByteData(fontBytes.offsetInBytes, fontBytes.lengthInBytes));
  final arabicBoldFont = pw.Font.ttf(boldBytes.buffer
      .asByteData(boldBytes.offsetInBytes, boldBytes.lengthInBytes));

  final pdf = pw.Document();

  final List<dynamic> colors =
      (record['colors'] is List) ? List<dynamic>.from(record['colors']) : [];

  final List<Map<String, String>> colorEntries = [];
  for (int j = 0; j < colors.length; j++) {
    final colorMap = colors[j] as Map<String, dynamic>;
    colorEntries.add({
      'color': colorMap['color']?.toString() ?? '---',
      'quantity': colorMap['quantity']?.toString() ?? '---',
    });
  }

  while (colorEntries.length < 3) {
    colorEntries.add({'color': '---', 'quantity': '---'});
  }

  final inkTable = pw.Container(
    width: 180,
    child: pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(60),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FixedColumnWidth(60),
      },
      border: pw.TableBorder.all(
        color: PdfColors.black,
        width: 0.5,
      ),
      children: [
        pw.TableRow(
          children: [
            _buildInkTableCell(colorEntries[0]['color']!, arabicFont, 60),
            _buildInkTableCell(colorEntries[1]['color']!, arabicFont, 60),
            _buildInkTableCell(colorEntries[2]['color']!, arabicFont, 60),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
            ),
          ),
          children: [
            pw.Container(height: 0.5),
            pw.Container(height: 0.5),
            pw.Container(height: 0.5),
          ],
        ),
        pw.TableRow(
          children: [
            _buildInkTableCell(colorEntries[0]['quantity']!, arabicFont, 60),
            _buildInkTableCell(colorEntries[1]['quantity']!, arabicFont, 60),
            _buildInkTableCell(colorEntries[2]['quantity']!, arabicFont, 60),
          ],
        ),
      ],
    ),
  );

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(16),
      build: (context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 16),
                alignment: pw.Alignment.center,
                child: pw.Text('تقرير طباعة حبر فردي',
                    style: pw.TextStyle(
                        font: arabicBoldFont,
                        fontSize: 18,
                        color: PdfColors.black)),
              ),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.black,
                  width: 0.5,
                ),
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FixedColumnWidth(60),
                  2: const pw.FixedColumnWidth(180),
                  3: const pw.FixedColumnWidth(100),
                  4: const pw.FixedColumnWidth(100),
                  5: const pw.FixedColumnWidth(80),
                  6: const pw.FixedColumnWidth(40),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF38761D),
                    ),
                    children: [
                      _buildHeaderCell('الملاحظات', arabicBoldFont),
                      _buildHeaderCell('العدد', arabicBoldFont),
                      _buildHeaderCell('كمية الحبر بالليتر', arabicBoldFont),
                      _buildHeaderCell('الصنف', arabicBoldFont),
                      _buildHeaderCell('العميل', arabicBoldFont),
                      _buildHeaderCell('التاريخ', arabicBoldFont),
                      _buildHeaderCell('م', arabicBoldFont),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF5F5F5),
                    ),
                    children: [
                      _buildDataCell(
                          record['notes']?.toString() ?? '---', arabicFont),
                      _buildDataCell(
                          record['quantity']?.toString() ?? '---', arabicFont),
                      pw.Container(
                        alignment: pw.Alignment.center,
                        child: inkTable,
                      ),
                      _buildDataCell(
                          record['product']?.toString() ?? '---', arabicFont),
                      _buildDataCell(record['clientName']?.toString() ?? '---',
                          arabicFont),
                      _buildDataCell(
                          _formatDate(record['date']?.toString() ?? '---'),
                          arabicFont),
                      _buildDataCell('1', arabicFont),
                    ],
                  ),
                ],
              ),
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 20),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'تاريخ التقرير: ${_formatDate(record['date']?.toString() ?? 'غير محدد')}',
                  style: pw.TextStyle(font: arabicFont, fontSize: 10),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return await pdf.save();
}

// ---------------------------
// دوال مساعدة لبناء الخلايا
// ---------------------------

pw.Widget _buildHeaderCell(String text, pw.Font boldFont) {
  return pw.Container(
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: boldFont,
        fontSize: 10,
        color: PdfColors.white,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _buildDataCell(String text, pw.Font font) {
  return pw.Container(
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: font,
        fontSize: 9,
        color: PdfColors.black,
      ),
      textAlign: pw.TextAlign.center,
      maxLines: 2,
    ),
  );
}

pw.Widget _buildInkTableCell(String text, pw.Font font, double width) {
  return pw.Container(
    width: width,
    height: 20,
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: font,
        fontSize: 8,
        color: PdfColors.black,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
}
