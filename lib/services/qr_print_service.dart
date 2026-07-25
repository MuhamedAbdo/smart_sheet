import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:smart_sheet/models/die_cutting_form.dart';

class QRPrintService {
  static Future<void> printDieCuttingQRLabels(List<DieCuttingForm> forms) async {
    if (forms.isEmpty) return;
    
    // تحويل البيانات إلى Map بسيط لتمريرها عبر الـ Isolate لتجنب أخطاء HiveObjects
    final formsData = forms.map((f) => {
      'formNumber': f.formNumber,
      'customerName': f.customerName,
      'itemName': f.itemName,
    }).toList();

    // تحميل خط يدعم اللغة العربية لتجنب ظهور النصوص كمربعات
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final fontBytes = fontData.buffer.asUint8List();

    // عرض واجهة الطباعة، وتشغيل وظيفة التوليد في الخلفية (Isolate)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return await compute(_generatePdfInBackground, {
          'forms': formsData,
          'font': fontBytes,
        });
      },
      name: 'Die_Cutting_QR_Labels',
    );
  }

  // الدالة التي ستعمل في مسار منفصل (Isolate) لمنع تجميد الشاشة
  static Future<Uint8List> _generatePdfInBackground(Map<String, dynamic> data) async {
    final List<Map<String, dynamic>> forms = List<Map<String, dynamic>>.from(data['forms']);
    final Uint8List fontBytes = data['font'];

    final doc = pw.Document();
    final ttf = pw.Font.ttf(fontBytes.buffer.asByteData());

    // تقسيم الصفحة إلى شبكة (3 أعمدة × 5 صفوف = 15 ملصق بالصفحة)
    const int crossAxisCount = 3;
    const int mainAxisCount = 5;
    const int itemsPerPage = crossAxisCount * mainAxisCount;

    for (var i = 0; i < forms.length; i += itemsPerPage) {
      final pageForms = forms.skip(i).take(itemsPerPage).toList();
      
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.GridView(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: pageForms.map((form) {
                return pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
                  ),
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'dc_form:${form['formNumber']}',
                        width: 80,
                        height: 80,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'فورمة: ${form['formNumber']}', 
                        style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold), 
                        textDirection: pw.TextDirection.rtl,
                        maxLines: 1,
                      ),
                      if (form['customerName'] != null && (form['customerName'] as String).isNotEmpty)
                        pw.Text(
                          'العميل: ${form['customerName']}', 
                          style: pw.TextStyle(font: ttf, fontSize: 9), 
                          textDirection: pw.TextDirection.rtl,
                          maxLines: 1,
                        ),
                      if (form['itemName'] != null && (form['itemName'] as String).isNotEmpty)
                        pw.Text(
                          'الصنف: ${form['itemName']}', 
                          style: pw.TextStyle(font: ttf, fontSize: 9), 
                          textDirection: pw.TextDirection.rtl,
                          maxLines: 1,
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      );
    }

    return doc.save();
  }
}
