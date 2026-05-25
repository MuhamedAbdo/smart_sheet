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
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    final regularStyle = pw.TextStyle(font: regularFont, fontSize: 8);
    final boldStyle = pw.TextStyle(
        font: boldFont, fontSize: 8, fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(
        font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold);

    final headerColor = PdfColor.fromHex('#5b796d');
    final redColor = PdfColor.fromHex('#e53e3e');

    return pw.Stack(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.topCenter,
            child: pw.Container(
              width: PdfPageFormat.a4.width - 32,
              height: PdfPageFormat.a4.height - 42,
              child: pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header
                    _buildHeader(data, titleStyle, boldStyle, redColor),
                    pw.SizedBox(height: 4),

                    // 2. Client & Order Info
                    _buildClientInfo(data, boldStyle, regularStyle),
                    pw.SizedBox(height: 4),

                    // 3. Items Table
                    _buildItemsTable(
                        data, boldStyle, regularStyle, headerColor),
                    pw.SizedBox(height: 4),

                    // 4. Corrugation Section
                    _buildCorrugationSection(
                        data, boldStyle, regularStyle, headerColor),
                    pw.SizedBox(height: 4),

                    // 5. Bottom Section
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _buildCorrugationReportTable(
                            data, boldStyle, regularStyle),
                        pw.SizedBox(height: 4),
                        _buildFlexoTable(boldStyle, regularStyle, headerColor),
                      ],
                    ),
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
              child: pw.Text(
                  _ar("وثيقة تشغيل - العاشر للطباعة والنشر والتغليف"),
                  style: regularStyle.copyWith(
                      fontSize: 7.0, color: PdfColors.grey700)),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildHeader(JobOrderData data, pw.TextStyle titleStyle,
      pw.TextStyle boldStyle, PdfColor redColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Right (Company name)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_ar("العاشر للطباعة والنشر والتغليف"),
                  style: boldStyle.copyWith(fontSize: 12)),
              pw.Text(_ar("( كارتبرس )"),
                  style: boldStyle.copyWith(fontSize: 12)),
            ],
          ),
        ),
        // Center: Order number
        pw.Expanded(
          child: pw.Center(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(_ar("أمر تشغيل رقم "), style: titleStyle),
                  pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text("(", style: titleStyle),
                        pw.Text(
                          " ${data.orderNumber.isEmpty ? '____' : data.orderNumber} ",
                          style: titleStyle.copyWith(color: redColor),
                        ),
                        pw.Text(")", style: titleStyle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Left: Box with info
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(_ar("بسم الله الرحمن الرحيم"),
                  style: boldStyle.copyWith(fontSize: 9)),
              pw.SizedBox(height: 2),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _infoRow(_ar("طلبية رقم :"), data.jobNumber, boldStyle,
                        isNumber: true),
                    _infoRow(
                        _ar("بتاريخ :"),
                        data.orderDate.isEmpty ? _today() : data.orderDate,
                        boldStyle,
                        isNumber: true),
                    _infoRow(
                        _ar("محرر أمر التشغيل :"), data.createdBy, boldStyle,
                        isNumber: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _infoRow(String label, String value, pw.TextStyle style,
      {bool isNumber = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style.copyWith(fontSize: 9)),
          value.isEmpty
              ? _dottedLine(width: 50)
              : isNumber
                  ? pw.Directionality(
                      textDirection: pw.TextDirection.ltr,
                      child: pw.Text(value, style: style.copyWith(fontSize: 9)),
                    )
                  : pw.Text(_ar(value), style: style.copyWith(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildClientInfo(
      JobOrderData data, pw.TextStyle boldStyle, pw.TextStyle regularStyle) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.5),
      ),
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                  child: pw.Text(
                      _ar("العميل : ${data.customerName.isEmpty ? '________________' : data.customerName}"),
                      style: boldStyle)),
              pw.Expanded(
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(_ar("كود العميل : "), style: boldStyle),
                    pw.Directionality(
                      textDirection: pw.TextDirection.ltr,
                      child: pw.Text(
                          data.clientCode.isEmpty
                              ? '________'
                              : data.clientCode,
                          style: boldStyle),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(_ar("تاريخ بدء التشغيل : "), style: boldStyle),
                    pw.Directionality(
                      textDirection: pw.TextDirection.ltr,
                      child: pw.Text(
                          data.startDate.isEmpty
                              ? '________________'
                              : data.startDate,
                          style: boldStyle),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(_ar("ميعاد التسليم : "), style: boldStyle),
                    pw.Directionality(
                      textDirection: pw.TextDirection.ltr,
                      child: pw.Text(
                          data.deliveryDate.isEmpty
                              ? '________________'
                              : data.deliveryDate,
                          style: boldStyle),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(JobOrderData data, pw.TextStyle boldStyle,
      pw.TextStyle regularStyle, PdfColor headerColor) {
    // Reversing table layout for RTL rendering in pdf package.
    // LTR columns render left-to-right. To make "م" appear on the right, it must be the last column.
    // Order: 0=Notes, 1=Dimensions, 2=Quantity, 3=Item Name, 4=Index
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 1.0),
      columnWidths: {
        0: const pw.FlexColumnWidth(3.0), // Notes
        1: const pw.FlexColumnWidth(2.0), // Dimensions
        2: const pw.FlexColumnWidth(1.2), // Quantity
        3: const pw.FlexColumnWidth(3.0), // Item Name
        4: const pw.FlexColumnWidth(0.6), // Index (م)
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerColor),
          children: [
            _cellText(
                "ملاحظات الصنف", boldStyle.copyWith(color: PdfColors.white),
                alignCenter: true),
            _cellText("الأبعاد (ط × ع × إ)",
                boldStyle.copyWith(color: PdfColors.white),
                alignCenter: true),
            _cellText("الكمية", boldStyle.copyWith(color: PdfColors.white),
                alignCenter: true),
            _cellText("بيان الصنف", boldStyle.copyWith(color: PdfColors.white),
                alignCenter: true),
            _cellText("م", boldStyle.copyWith(color: PdfColors.white),
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
              _cellText(data.items[i].itemNotes, regularStyle),
              _cellWidget(
                pw.Directionality(
                  textDirection: pw.TextDirection.ltr,
                  child: pw.Text(
                    "${data.items[i].height} × ${data.items[i].width} × ${data.items[i].length}"
                        .replaceAll(RegExp(r'^[ ×]+|[ ×]+$'), ''),
                    style: boldStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                alignCenter: true,
              ),
              _cellText(data.items[i].quantity, boldStyle, alignCenter: true),
              _cellWidget(
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(_ar(data.items[i].productName), style: boldStyle),
                    if (data.items[i].productCode.isNotEmpty) ...[
                      pw.SizedBox(width: 4),
                      pw.Directionality(
                        textDirection: pw.TextDirection.ltr,
                        child: pw.Text("(${data.items[i].productCode})",
                            style: boldStyle),
                      ),
                    ],
                  ],
                ),
                alignCenter: false,
              ),
              _cellWidget(
                pw.Directionality(
                  textDirection: pw.TextDirection.ltr,
                  child: pw.Text(
                      i < _arabicNumerals.length
                          ? _arabicNumerals[i]
                          : '${i + 1}',
                      style: boldStyle,
                      textAlign: pw.TextAlign.center),
                ),
                alignCenter: true,
              ),
            ],
          ),
        ]
      ],
    );
  }

  static pw.Widget _buildCorrugationSection(JobOrderData data,
      pw.TextStyle boldStyle, pw.TextStyle regularStyle, PdfColor headerColor) {
    var corrugationItems = data.items.where((i) => i.hasCorrugation).toList();
    if (corrugationItems.isEmpty && data.items.isNotEmpty) {
      corrugationItems = [data.items.first];
    }

    if (corrugationItems.isEmpty) return pw.SizedBox();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: headerColor,
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            alignment: pw.Alignment.center,
            child: pw.Text(_ar("التضليع"),
                style: boldStyle.copyWith(color: PdfColors.white)),
          ),
          pw.Container(
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 70,
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(left: pw.BorderSide(width: 1.0))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: List.generate(corrugationItems.length, (idx) {
                        return _buildSingleCorrugationItemBlock(
                            corrugationItems[idx],
                            isLast: idx == corrugationItems.length - 1,
                            boldStyle: boldStyle,
                            regularStyle: regularStyle,
                            headerColor: headerColor,
                            itemIndex: idx,
                            totalItems: corrugationItems.length);
                      }),
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 30,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Container(
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 1),
                        decoration: const pw.BoxDecoration(
                            border:
                                pw.Border(bottom: pw.BorderSide(width: 1.0))),
                        child: pw.Text(_ar("توقيع فني التضليع والتاريخ"),
                            style: boldStyle.copyWith(fontSize: 7.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
              height: 14,
              child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Expanded(
                        flex: 12,
                        child: pw.Container(
                            alignment: pw.Alignment.centerRight,
                            padding:
                                const pw.EdgeInsets.symmetric(horizontal: 4),
                            decoration: const pw.BoxDecoration(
                                border:
                                    pw.Border(left: pw.BorderSide(width: 1.0))),
                            child: pw.Text(_ar("ملاحظات"),
                                style: boldStyle.copyWith(fontSize: 9)))),
                    pw.Expanded(flex: 88, child: pw.Container(height: 14)),
                  ])),
        ],
      ),
    );
  }

  static pw.Widget _buildSingleCorrugationItemBlock(
    JobOrderItem item, {
    required bool isLast,
    required pw.TextStyle boldStyle,
    required pw.TextStyle regularStyle,
    required PdfColor headerColor,
    required int itemIndex,
    required int totalItems,
  }) {
    return pw.Container(
        decoration: isLast
            ? null
            : const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (totalItems > 1)
                pw.Container(
                    color: PdfColors.grey300,
                    padding: const pw.EdgeInsets.symmetric(vertical: 1),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                        _ar("${item.productName} - ${item.productCode}"),
                        style: boldStyle.copyWith(fontSize: 8))),
              pw.Container(
                  height: 14,
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
                  child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Expanded(
                            flex: 18,
                            child: pw.Container(
                                decoration: const pw.BoxDecoration(
                                    border: pw.Border(
                                        left: pw.BorderSide(width: 1.0))),
                                alignment: pw.Alignment.centerRight,
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 4),
                                child: pw.Text(_ar("التضليع"),
                                    style: boldStyle.copyWith(fontSize: 9)))),
                        pw.Expanded(
                            flex: 82,
                            child: pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 3),
                                child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.end,
                                    children: [
                                      _corrugationCheckbox(
                                          'E',
                                          item.corrugationTypes.contains('E'),
                                          boldStyle),
                                      pw.SizedBox(width: 4),
                                      _corrugationCheckbox(
                                          'C',
                                          item.corrugationTypes.contains('C'),
                                          boldStyle),
                                      pw.SizedBox(width: 4),
                                      _corrugationCheckbox(
                                          'E/E',
                                          item.corrugationTypes.contains('E/E'),
                                          boldStyle),
                                      pw.SizedBox(width: 4),
                                      _corrugationCheckbox(
                                          'C/C',
                                          item.corrugationTypes.contains('C/C'),
                                          boldStyle),
                                      pw.SizedBox(width: 4),
                                      _corrugationCheckbox(
                                          'C/E',
                                          item.corrugationTypes.contains('C/E'),
                                          boldStyle),
                                      pw.Spacer(),
                                      if (item.customCorrugation.isNotEmpty)
                                        pw.Directionality(
                                            textDirection: pw.TextDirection.ltr,
                                            child: pw.Text(
                                                "(${item.customCorrugation})",
                                                style: boldStyle.copyWith(
                                                    fontSize: 8)))
                                      else
                                        pw.Text("(           )",
                                            style: boldStyle.copyWith(
                                                fontSize: 8)),
                                    ]))),
                      ])),
              pw.Container(
                  height: 48,
                  child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Expanded(
                            flex: 25,
                            child: pw.Container(
                                decoration: const pw.BoxDecoration(
                                    border: pw.Border(
                                        left: pw.BorderSide(width: 1.0))),
                                child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.stretch,
                                    children: [
                                      _corrLabelRow("عينات", true, boldStyle),
                                      _corrLabelRow(
                                          "مقاس العلبة", true, boldStyle),
                                      _corrLabelRow(
                                          "مقاس الشريحة", true, boldStyle),
                                      _corrLabelRow(
                                          "عرض البكر", false, boldStyle),
                                    ]))),
                        pw.Expanded(
                            flex: 75,
                            child: pw.Column(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.stretch,
                                children: [
                                  _corrMiddleRow(pw.Container(), true),
                                  _corrMiddleRow(
                                      pw.Directionality(
                                          textDirection: pw.TextDirection.ltr,
                                          child: pw.Text(
                                              item.corrugationBoxSize.isEmpty
                                                  ? '     /     '
                                                  : item.corrugationBoxSize
                                                      .split('/')
                                                      .map((e) => e.trim())
                                                      .toList()
                                                      .reversed
                                                      .join(' / '),
                                              style: regularStyle)),
                                      true),
                                  _corrMiddleRow(
                                      pw.Row(
                                          mainAxisAlignment:
                                              pw.MainAxisAlignment.center,
                                          children: [
                                            pw.Directionality(
                                                textDirection:
                                                    pw.TextDirection.ltr,
                                                child: pw.Text(
                                                    item.corrugationSheetSize
                                                            .isEmpty
                                                        ? '     /     '
                                                        : item
                                                            .corrugationSheetSize
                                                            .split('/')
                                                            .map(
                                                                (e) => e.trim())
                                                            .toList()
                                                            .reversed
                                                            .join(' / '),
                                                    style: regularStyle)),
                                            pw.Text("  /  "),
                                            pw.Text(_ar("عدد الشرائح"),
                                                style: boldStyle.copyWith(
                                                    fontSize: 8)),
                                            pw.Text(
                                                " [ ${item.corrugationSheetCount.isEmpty ? '   ' : item.corrugationSheetCount} ] ",
                                                style: regularStyle),
                                          ]),
                                      true),
                                  _corrMiddleRow(pw.Container(), false),
                                ])),
                      ]))
            ]));
  }

  static pw.Widget _corrMiddleRow(pw.Widget child, bool hasBottom) {
    return pw.Container(
      height: 12,
      alignment: pw.Alignment.center,
      decoration: hasBottom
          ? const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.0)))
          : null,
      child: child,
    );
  }

  static pw.Widget _corrLabelRow(
      String label, bool hasBottom, pw.TextStyle style) {
    return pw.Container(
      height: 12,
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      decoration: hasBottom
          ? const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.0)))
          : null,
      child: pw.Text(_ar(label), style: style.copyWith(fontSize: 8)),
    );
  }

  static pw.Widget _corrugationCheckbox(
      String label, bool isChecked, pw.TextStyle style) {
    return pw.Directionality(
      textDirection: pw.TextDirection.ltr,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Transform.translate(
            offset: const PdfPoint(0, 1.5),
            child: pw.Text(_ar(label), style: style.copyWith(fontSize: 8)),
          ),
          pw.SizedBox(width: 4),
          pw.Container(
            width: 8,
            height: 8,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.0),
              color: isChecked ? PdfColors.black : PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────────

  static pw.Widget _cellText(String text, pw.TextStyle style,
      {bool alignCenter = false}) {
    return pw.Container(
      alignment: alignCenter ? pw.Alignment.center : pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
      child: pw.Text(_ar(text),
          style: style,
          textAlign: alignCenter ? pw.TextAlign.center : pw.TextAlign.right),
    );
  }

  static pw.Widget _cellWidget(pw.Widget child, {bool alignCenter = false}) {
    return pw.Container(
      alignment: alignCenter ? pw.Alignment.center : pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
      child: child,
    );
  }

  static pw.Widget _buildCorrugationReportTable(
      JobOrderData data, pw.TextStyle boldStyle, pw.TextStyle regularStyle) {
    int rowCount = data.items.isEmpty ? 1 : data.items.length;

    return pw
        .Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(
            _ar("تقرير قسم التضليع ( تدوين المقاسات التي تم تشغيلها في حالة تشغيل أمر على عدة مهمات )"),
            style: regularStyle.copyWith(fontSize: 7)),
        pw.Text(_ar("اسم القائم بالتشغيل مع التوقيع والتاريخ"),
            style: regularStyle.copyWith(fontSize: 7)),
      ]),
      pw.SizedBox(height: 2),
      pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.0),
          ),
          child: pw.Column(
              children: List.generate(rowCount, (index) {
            return pw.Container(
                height: 12,
                decoration: index == rowCount - 1
                    ? null
                    : const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
                child: pw.Row(children: [
                  pw.Expanded(
                      flex: 8,
                      child: pw.Container(
                        alignment: pw.Alignment.center,
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(left: pw.BorderSide(width: 1.0))),
                        child: pw.Directionality(
                            textDirection: pw.TextDirection.ltr,
                            child: pw.Text("${index + 1}",
                                style: boldStyle.copyWith(fontSize: 8))),
                      )),
                  pw.Expanded(
                      flex: 46,
                      child: pw.Container(
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(left: pw.BorderSide(width: 1.0))),
                      )),
                  pw.Expanded(
                    flex: 46,
                    child: pw.Container(),
                  ),
                ]));
          })))
    ]);
  }

  static pw.Widget _buildFlexoTable(
      pw.TextStyle boldStyle, pw.TextStyle regularStyle, PdfColor headerColor) {
    return pw.Container(
        height: 52,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.0),
        ),
        child: pw
            .Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Expanded(
              flex: 85,
              child: pw.Container(
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(left: pw.BorderSide(width: 1.0))),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Container(
                          height: 14,
                          color: headerColor,
                          alignment: pw.Alignment.center,
                          child: pw.Text(_ar("طباعة الفلكسو"),
                              style: boldStyle.copyWith(
                                  color: PdfColors.white, fontSize: 10)),
                        ),
                        pw.Expanded(
                            child: pw.Container(
                                decoration: const pw.BoxDecoration(
                                    border: pw.Border(
                                        top: pw.BorderSide(width: 1.0))),
                                child: pw.Row(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.stretch,
                                    children: [
                                      pw.Expanded(
                                          flex: 20,
                                          child: pw.Container(
                                              decoration:
                                                  const pw.BoxDecoration(
                                                      border: pw.Border(
                                                          left: pw.BorderSide(
                                                              width: 1.0))),
                                              child: pw.Column(
                                                  crossAxisAlignment: pw
                                                      .CrossAxisAlignment
                                                      .stretch,
                                                  children: [
                                                    pw.Container(
                                                        height: 12,
                                                        child: _flexoLabelCell(
                                                            "طباعة",
                                                            boldStyle,
                                                            true)),
                                                    pw.Container(
                                                        height: 12,
                                                        child: _flexoLabelCell(
                                                            "فرز طباعة",
                                                            boldStyle,
                                                            true)),
                                                    pw.Container(
                                                        height: 12,
                                                        child: _flexoLabelCell(
                                                            "ملاحظات",
                                                            boldStyle,
                                                            false)),
                                                  ]))),
                                      pw.Expanded(
                                          flex: 80,
                                          child: pw.Column(
                                              crossAxisAlignment:
                                                  pw.CrossAxisAlignment.stretch,
                                              children: [
                                                pw.Container(
                                                    height: 12,
                                                    child: _flexoValueCellRow1(
                                                        boldStyle,
                                                        regularStyle,
                                                        true)),
                                                pw.Container(
                                                    height: 12,
                                                    child: _flexoValueCellRow2(
                                                        boldStyle,
                                                        regularStyle,
                                                        true)),
                                                pw.Container(
                                                    height: 12,
                                                    child: _flexoValueCellEmpty(
                                                        false)),
                                              ])),
                                    ])))
                      ]))),
          pw.Expanded(
              flex: 15,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      height: 14,
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
                      alignment: pw.Alignment.center,
                      child: pw.Text(_ar("توقيع المختص"),
                          style: boldStyle.copyWith(fontSize: 8)),
                    ),
                  ])),
        ]));
  }

  static pw.Widget _flexoLabelCell(
      String text, pw.TextStyle style, bool hasBottomBorder) {
    return pw.Container(
      alignment: pw.Alignment.center,
      decoration: hasBottomBorder
          ? const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.0)))
          : null,
      child: pw.Text(_ar(text), style: style.copyWith(fontSize: 7)),
    );
  }

  static pw.Widget _flexoValueCellRow1(
      pw.TextStyle boldStyle, pw.TextStyle regularStyle, bool hasBottomBorder) {
    return pw.Container(
        alignment: pw.Alignment.center,
        decoration: hasBottomBorder
            ? const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.0)))
            : null,
        child:
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.Text(_ar("ألوان ("), style: boldStyle.copyWith(fontSize: 7)),
          pw.Text("                    ", style: regularStyle),
          pw.Text(_ar("                                ) - إجمالي عدد الألوان"),
              style: boldStyle.copyWith(fontSize: 7)),
          pw.Text("          ", style: regularStyle),
          pw.Text(_ar("لون."), style: boldStyle.copyWith(fontSize: 7)),
        ]));
  }

  static pw.Widget _flexoValueCellRow2(
      pw.TextStyle boldStyle, pw.TextStyle regularStyle, bool hasBottomBorder) {
    return pw.Container(
        alignment: pw.Alignment.center,
        decoration: hasBottomBorder
            ? const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.0)))
            : null,
        child:
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          _checkboxWithLabel("أول", boldStyle),
          pw.SizedBox(width: 15),
          pw.Text(" - ", style: boldStyle),
          pw.SizedBox(width: 15),
          _checkboxWithLabel("ثاني", boldStyle),
          pw.SizedBox(width: 15),
          pw.Text(" - ", style: boldStyle),
          pw.SizedBox(width: 15),
          _checkboxWithLabel("هالك", boldStyle),
        ]));
  }

  static pw.Widget _checkboxWithLabel(String label, pw.TextStyle style) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Transform.translate(
          offset: const PdfPoint(0, 1.5),
          child: pw.Text(_ar(label), style: style.copyWith(fontSize: 7)),
        ),
        pw.SizedBox(width: 4),
        pw.Container(
          width: 8,
          height: 8,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.0),
          ),
        ),
      ],
    );
  }

  static pw.Widget _flexoValueCellEmpty(bool hasBottomBorder) {
    return pw.Container(
      decoration: hasBottomBorder
          ? const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.0)))
          : null,
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
