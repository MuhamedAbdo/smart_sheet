import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Future<Uint8List> Function(PdfPageFormat) buildPdf;
  final String title;

  const PdfPreviewScreen({
    super.key,
    required this.buildPdf,
    this.title = 'معاينة للطباعة',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1a3a6e),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => buildPdf(format),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: true, // يتيح للمستخدم تغيير حجم الورق (مثل A4 إلى A5)
        pageFormats: const <String, PdfPageFormat>{
          'A3': PdfPageFormat.a3,
          'A4': PdfPageFormat.a4,
          'A5': PdfPageFormat.a5,
          'A6': PdfPageFormat.a6,
          'Letter': PdfPageFormat.letter,
          'Legal': PdfPageFormat.legal,
          'Roll 57mm': PdfPageFormat.roll57,
          'Roll 80mm': PdfPageFormat.roll80,
        },
        initialPageFormat: PdfPageFormat.a4,
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1a3a6e)),
        ),
      ),
    );
  }
}
