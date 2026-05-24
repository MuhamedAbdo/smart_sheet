import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/arabic_pdf_helper.dart';

// ─── Data Models ────────────────────────────────────────────────────────────

/// بيانات صنف واحد داخل أمر التشغيل
class JobOrderItem {
  final String productName;
  final String productCode;
  final String length;
  final String width;
  final String height;
  String quantity;
  String itemNotes;
  String review;

  // Corrugation fields
  final List<String> corrugationTypes;
  final String customCorrugation;
  final String corrugationSamples;
  final String corrugationBoxSize;
  final String corrugationSheetSize;
  final String corrugationSheetCount;

  JobOrderItem({
    required this.productName,
    required this.productCode,
    this.length = '',
    this.width = '',
    this.height = '',
    this.quantity = '',
    this.itemNotes = '',
    this.review = '',
    this.corrugationTypes = const [],
    this.customCorrugation = '',
    this.corrugationSamples = '',
    this.corrugationBoxSize = '',
    this.corrugationSheetSize = '',
    this.corrugationSheetCount = '',
  });

  bool get hasCorrugation =>
      corrugationTypes.isNotEmpty || customCorrugation.isNotEmpty;
}

/// بيانات أمر التشغيل الكامل
class JobOrderData {
  final String orderNumber;
  final String jobNumber;
  final String orderDate;
  final String createdBy;
  final String customerName;
  final String clientCode;
  final String address;
  final String startDate;
  final String supervisor;
  final String deliveryDate;
  final String phone;
  final String receivedDate;
  final String generalNotes;
  final List<JobOrderItem> items;

  const JobOrderData({
    this.orderNumber = '',
    this.jobNumber = '',
    this.orderDate = '',
    this.createdBy = '',
    this.customerName = '',
    this.clientCode = '',
    this.address = '',
    this.startDate = '',
    this.supervisor = '',
    this.deliveryDate = '',
    this.phone = '',
    this.receivedDate = '',
    this.generalNotes = '',
    this.items = const [],
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

class JobOrderService {
  static const _arabicNumerals = [
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
    '١٠',
    '١١',
    '١٢',
  ];

  static String _ar(String text) => ArabicPDFHelper.fixArabic(text);

  static String _today() => DateTime.now().toString().split(' ')[0];

  // ── Public API ──────────────────────────────────────────────────────────────

  /// يولد وثيقة PDF أصلية (Native) بدون الحاجة إلى HTML
  static Future<Uint8List> generateNativePdf(JobOrderData data) async {
    final doc = pw.Document();

    final regularFontData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');

    final regularFont = pw.Font.ttf(regularFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        build: (pw.Context ctx) =>
            _buildSinglePage(data, regularFont, boldFont),
      ),
    );

    return await doc.save();
  }

  /// يفتح نافذة معاينة الـ PDF التفاعلية
  static Future<void> showPreview(
      BuildContext context, JobOrderData data) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            width: 1000,
            height: MediaQuery.of(ctx).size.height * 0.9,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF1A3A6E),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.picture_as_pdf,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'معاينة أمر التشغيل (Native PDF)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'إغلاق المعاينة',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: (format) async => await generateNativePdf(data),
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: 'job_order_${data.jobNumber}.pdf',
                    loadingWidget: const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF1A3A6E)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// يفتح نافذة الطباعة مباشرة
  static Future<void> openForPrinting(JobOrderData data) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => await generateNativePdf(data),
        name: 'job_order_${data.jobNumber}',
      );
    } catch (e) {
      debugPrint("⚠️ Printing failed: $e");
    }
  }

  // ── Layout Builders ─────────────────────────────────────────────────────────

  static pw.Widget _buildSinglePage(
      JobOrderData data, pw.Font regularFont, pw.Font boldFont) {
    final regularStyle = pw.TextStyle(font: regularFont, fontSize: 8.5);
    final boldStyle = pw.TextStyle(
        font: boldFont, fontSize: 8.5, fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(
        font: boldFont, fontSize: 11.5, fontWeight: pw.FontWeight.bold);

    return pw.Stack(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 20),
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.topCenter,
            child: pw.Container(
              width: PdfPageFormat.a4.width - 40,
              child: pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header
                    _buildHeader(data, titleStyle, boldStyle),
                    pw.SizedBox(height: 8),

                    // 2. Simple Client Info Table
                    _buildSimpleClientInfo(data, boldStyle, regularStyle),
                    pw.SizedBox(height: 8),

                    // 3. Items Table
                    _buildItemsTable(data, boldStyle, regularStyle),
                    pw.SizedBox(height: 8),

                    // 4. Corrugation Section
                    if (data.items.any((i) => i.hasCorrugation)) ...[
                      _buildCorrugationSection(data, boldStyle, regularStyle),
                      pw.SizedBox(height: 8),
                    ],

                    // 5. Notes Section
                    _buildNotesSection(
                        data.generalNotes, boldStyle, regularStyle),
                    pw.SizedBox(height: 8),

                    // 6. Signatures Section
                    _buildSignaturesSection(boldStyle, regularStyle),
                  ],
                ),
              ),
            ),
          ),
        ),
        pw.Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(
              child: pw.Text(_ar("وثيقة تشغيل"),
                  style: regularStyle.copyWith(
                      fontSize: 7.0, color: PdfColors.grey700)),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildHeader(
      JobOrderData data, pw.TextStyle titleStyle, pw.TextStyle boldStyle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_ar("أمر تشغيل مطبوعات"), style: titleStyle),
            pw.SizedBox(height: 3),
            pw.Text(
                _ar("رقم الطلبية: ${data.orderNumber.isEmpty ? '____' : data.orderNumber}"),
                style: boldStyle),
            pw.Text(
                _ar("رقم أمر التشغيل: ${data.jobNumber.isEmpty ? '____' : data.jobNumber}"),
                style: boldStyle),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                  _ar("تاريخ الإصدار: ${data.orderDate.isEmpty ? _today() : data.orderDate}"),
                  style: boldStyle),
              pw.SizedBox(height: 3),
              pw.Text(_ar("تم الإنشاء بواسطة: ${data.createdBy}"),
                  style: boldStyle),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSimpleClientInfo(
      JobOrderData data, pw.TextStyle boldStyle, pw.TextStyle regularStyle) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cellText("مشرف القسم", boldStyle, alignCenter: true),
            _cellText("تاريخ بدء التشغيل", boldStyle, alignCenter: true),
            _cellText("تاريخ الإنتهاء / الإستلام", boldStyle,
                alignCenter: true),
            _cellText("ميعاد التسليم", boldStyle, alignCenter: true),
          ],
        ),
        pw.TableRow(
          children: [
            _cellText(data.supervisor, regularStyle, alignCenter: true),
            _cellText(data.startDate, regularStyle, alignCenter: true),
            _cellText(data.receivedDate, regularStyle, alignCenter: true),
            _cellText(data.deliveryDate, regularStyle, alignCenter: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(
      JobOrderData data, pw.TextStyle boldStyle, pw.TextStyle regularStyle) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),
        1: const pw.FlexColumnWidth(3.0),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(2.0),
        4: const pw.FlexColumnWidth(3.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.black),
          children: [
            _cellText("م", boldStyle.copyWith(color: PdfColors.white),
                alignCenter: true),
            _cellText("بيان الصنف", boldStyle.copyWith(color: PdfColors.white),
                alignCenter: true),
            _cellText("الكمية", boldStyle.copyWith(color: PdfColors.white),
                alignCenter: true),
            _cellText("الأبعاد", boldStyle.copyWith(color: PdfColors.white),
                alignCenter: true),
            _cellText(
                "ملاحظات الصنف", boldStyle.copyWith(color: PdfColors.white),
                alignCenter: true),
          ],
        ),
        if (data.items.isEmpty)
          pw.TableRow(
            children: List.generate(5, (_) => _cellText("", regularStyle)),
          ),
        for (int i = 0; i < data.items.length; i++) ...[
          pw.TableRow(
            children: [
              _cellText(
                  i < _arabicNumerals.length ? _arabicNumerals[i] : '${i + 1}',
                  regularStyle,
                  alignCenter: true),
              _cellText(
                  "${data.items[i].productName} ${data.items[i].productCode.isNotEmpty ? '(${data.items[i].productCode})' : ''}",
                  regularStyle),
              _cellText(data.items[i].quantity, regularStyle,
                  alignCenter: true),
              _cellText(
                  "${data.items[i].length} × ${data.items[i].width} × ${data.items[i].height}"
                      .replaceAll(RegExp(r'^[ ×]+|[ ×]+$'), ''),
                  regularStyle,
                  alignCenter: true),
              _cellText(data.items[i].itemNotes, regularStyle),
            ],
          ),
        ]
      ],
    );
  }

  static pw.Widget _buildCorrugationSection(
      JobOrderData data, pw.TextStyle boldStyle, pw.TextStyle regularStyle) {
    final corrugationItems = data.items.where((i) => i.hasCorrugation).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: PdfColors.black,
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          alignment: pw.Alignment.center,
          child: pw.Text(_ar("بيانات التضليع"),
              style: boldStyle.copyWith(color: PdfColors.white)),
        ),
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.black, width: 0.8),
              right: pw.BorderSide(color: PdfColors.black, width: 0.8),
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
            ),
          ),
          padding: const pw.EdgeInsets.all(5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: List.generate(corrugationItems.length, (idx) {
              final item = corrugationItems[idx];
              final isE = item.corrugationTypes.contains('E') ? 'E' : '';
              final isC = item.corrugationTypes.contains('C') ? 'C' : '';
              final isEE = item.corrugationTypes.contains('E/E') ? 'E/E' : '';
              final isCC = item.corrugationTypes.contains('C/C') ? 'C/C' : '';
              final isCE = item.corrugationTypes.contains('C/E') ? 'C/E' : '';

              final selectedTypes = [isE, isC, isEE, isCC, isCE]
                  .where((t) => t.isNotEmpty)
                  .join(' ، ');

              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_ar("• صنف ${idx + 1}: "), style: boldStyle),
                    pw.Expanded(
                      child: pw.Text(
                        _ar("الأنواع: ($selectedTypes) | مقاس العلبة: ${item.corrugationBoxSize} | الشريحة: ${item.corrugationSheetSize} | عدد الشرائح: ${item.corrugationSheetCount} | مخصص: ${item.customCorrugation}"),
                        style: regularStyle,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildNotesSection(
      String notes, pw.TextStyle boldStyle, pw.TextStyle regularStyle) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
            ),
            child: pw.Text(_ar("ملاحظات عامة وتعليمات"), style: boldStyle),
          ),
          pw.Container(
            height: 90,
            padding: const pw.EdgeInsets.all(6),
            child: notes.isEmpty
                ? pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (_) => _dottedLine()),
                  )
                : pw.Text(_ar(notes), style: regularStyle),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignaturesSection(
      pw.TextStyle boldStyle, pw.TextStyle regularStyle) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cellText("مدير الإنتاج", boldStyle, alignCenter: true),
            _cellText("مشرف الجودة", boldStyle, alignCenter: true),
            _cellText("مشرف التخطيط", boldStyle, alignCenter: true),
            _cellText("مشرف الحسابات", boldStyle, alignCenter: true),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Container(
                height: 50,
                alignment: pw.Alignment.bottomCenter,
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: _dottedLine(width: 80)),
            pw.Container(
                height: 50,
                alignment: pw.Alignment.bottomCenter,
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: _dottedLine(width: 80)),
            pw.Container(
                height: 50,
                alignment: pw.Alignment.bottomCenter,
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: _dottedLine(width: 80)),
            pw.Container(
                height: 50,
                alignment: pw.Alignment.bottomCenter,
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: _dottedLine(width: 80)),
          ],
        ),
      ],
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────────

  static pw.Widget _cellText(String text, pw.TextStyle style,
      {bool alignCenter = false}) {
    return pw.Container(
      alignment: alignCenter ? pw.Alignment.center : pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
      child: pw.Text(_ar(text),
          style: style,
          textAlign: alignCenter ? pw.TextAlign.center : pw.TextAlign.right),
    );
  }

  static pw.Widget _dottedLine({double? width}) {
    return pw.Container(
      width: width,
      height: 1,
      margin: const pw.EdgeInsets.symmetric(vertical: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
              color: PdfColors.grey600,
              width: 0.8,
              style: pw.BorderStyle.dotted),
        ),
      ),
    );
  }
}
