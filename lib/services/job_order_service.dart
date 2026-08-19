import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// عرض البكر المستهدف
  final String rollWidth;

  /// أنواع الورق لكل طبقة (ط١، ط٢، ...)
  final List<String> paperLayers;

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
    this.rollWidth = '',
    this.paperLayers = const [],
  });

  bool get hasCorrugation =>
      corrugationTypes.isNotEmpty || customCorrugation.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'productName': productName,
    'productCode': productCode,
    'length': length,
    'width': width,
    'height': height,
    'quantity': quantity,
    'itemNotes': itemNotes,
    'review': review,
    'corrugationTypes': corrugationTypes,
    'customCorrugation': customCorrugation,
    'corrugationSamples': corrugationSamples,
    'corrugationBoxSize': corrugationBoxSize,
    'corrugationSheetSize': corrugationSheetSize,
    'corrugationSheetCount': corrugationSheetCount,
    'rollWidth': rollWidth,
    'paperLayers': paperLayers,
  };

  factory JobOrderItem.fromJson(Map<String, dynamic> json) => JobOrderItem(
    productName: json['productName'] ?? '',
    productCode: json['productCode'] ?? '',
    length: json['length'] ?? '',
    width: json['width'] ?? '',
    height: json['height'] ?? '',
    quantity: json['quantity'] ?? '',
    itemNotes: json['itemNotes'] ?? '',
    review: json['review'] ?? '',
    corrugationTypes: List<String>.from(json['corrugationTypes'] ?? []),
    customCorrugation: json['customCorrugation'] ?? '',
    corrugationSamples: json['corrugationSamples'] ?? '',
    corrugationBoxSize: json['corrugationBoxSize'] ?? '',
    corrugationSheetSize: json['corrugationSheetSize'] ?? '',
    corrugationSheetCount: json['corrugationSheetCount'] ?? '',
    rollWidth: json['rollWidth'] ?? '',
    paperLayers: List<String>.from(json['paperLayers'] ?? []),
  );
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
  final String creatorEmail;
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
    this.creatorEmail = '',
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
    'orderNumber': orderNumber,
    'jobNumber': jobNumber,
    'orderDate': orderDate,
    'createdBy': createdBy,
    'customerName': customerName,
    'clientCode': clientCode,
    'address': address,
    'startDate': startDate,
    'supervisor': supervisor,
    'deliveryDate': deliveryDate,
    'phone': phone,
    'receivedDate': receivedDate,
    'generalNotes': generalNotes,
    'creatorEmail': creatorEmail,
    'items': items.map((i) => i.toJson()).toList(),
    'savedAt': DateTime.now().toIso8601String(),
  };

  factory JobOrderData.fromJson(Map<String, dynamic> json) => JobOrderData(
    orderNumber: json['orderNumber'] ?? '',
    jobNumber: json['jobNumber'] ?? '',
    orderDate: json['orderDate'] ?? '',
    createdBy: json['createdBy'] ?? '',
    customerName: json['customerName'] ?? '',
    clientCode: json['clientCode'] ?? '',
    address: json['address'] ?? '',
    startDate: json['startDate'] ?? '',
    supervisor: json['supervisor'] ?? '',
    deliveryDate: json['deliveryDate'] ?? '',
    phone: json['phone'] ?? '',
    receivedDate: json['receivedDate'] ?? '',
    generalNotes: json['generalNotes'] ?? '',
    creatorEmail: json['creatorEmail'] ?? '',
    items: (json['items'] as List<dynamic>? ?? [])
        .map((i) => JobOrderItem.fromJson(Map<String, dynamic>.from(i)))
        .toList(),
  );
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

  /// يحفظ أمر التشغيل مع مزامنته مع Supabase
  static Future<void> saveOrder(JobOrderData data) async {
    final jsonData = data.toJson();
    final supabase = Supabase.instance.client;
    final key = 'order_${DateTime.now().millisecondsSinceEpoch}';
    
    // 1. محاولة الرفع إلى Supabase
    try {
      await supabase.from('issued_job_orders').insert({
        'id': key,
        'order_number': data.orderNumber,
        'job_number': data.jobNumber,
        'client_name': data.customerName, // Fix: client_name instead of customer_name
        'order_data': jsonData, // حفظ كامل البيانات بصيغة JSON
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Job order synced to Supabase successfully.');
    } catch (e) {
      debugPrint('Failed to sync job order to Supabase: $e');
      throw Exception('فشل في مزامنة البيانات مع السيرفر: $e');
    }

    // 2. الحفظ المحلي في Hive بعد نجاح المزامنة
    final box = await Hive.openBox('issued_job_orders');
    final jsonString = jsonEncode(jsonData);
    await box.put(key, jsonString);
  }

  /// يجلب كل أوامر التشغيل من السيرفر (إن أمكن) ثم من Hive
  static Future<List<MapEntry<dynamic, JobOrderData>>> getSavedOrders() async {
    final box = await Hive.openBox('issued_job_orders');
    final supabase = Supabase.instance.client;

    try {
      final List<dynamic> response = await supabase
          .from('issued_job_orders')
          .select('id, order_data')
          .order('created_at', ascending: false);

      await box.clear(); // مسح الـ Cache القديم
      for (var row in response) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        final orderData = map['order_data'];
        await box.put(id, jsonEncode(orderData));
      }
      debugPrint('Fetched ${response.length} issued job orders from Supabase.');
    } catch (e) {
      debugPrint('Failed to fetch issued job orders from Supabase (using local cache): $e');
    }

    final entries = box.keys.map((k) {
      try {
        final raw = jsonDecode(box.get(k) as String) as Map<String, dynamic>;
        return MapEntry(k, JobOrderData.fromJson(raw));
      } catch (_) {
        return null;
      }
    }).whereType<MapEntry<dynamic, JobOrderData>>().toList();

    // ترتيب من الأحدث للأقدم بناءً على مفتاح الـ timestamp
    entries.sort((a, b) => b.key.toString().compareTo(a.key.toString()));
    return entries;
  }

  /// يحذف أمر تشغيل واحد
  static Future<void> deleteOrder(dynamic key) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('issued_job_orders').delete().eq('id', key);
    } catch (e) {
      debugPrint('Failed to delete from Supabase: $e');
      throw Exception('فشل الحذف من السيرفر: $e');
    }
    
    final box = await Hive.openBox('issued_job_orders');
    await box.delete(key);
  }

  /// يولد وثيقة PDF أصلية (Native) بدون الحاجة إلى HTML
  static Future<Uint8List> generateNativePdf(JobOrderData data, {PdfPageFormat format = PdfPageFormat.a4}) async {
    debugPrint(
        "📄 generateNativePdf: start generating for job ${data.jobNumber} with format $format...");
    final doc = pw.Document();

    final regularFontData =
        await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');

    final regularFont = pw.Font.ttf(regularFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    // Get printed factory name and logo from Hive
    final box = await Hive.openBox('settings');
    final printedFactoryName = box.get('printedFactoryName',
        defaultValue: "العاشر للطباعة والنشر والتغليف\n( كازنبرس )") as String;
    final factoryLogoBase64 = box.get('factoryLogoBase64') as String?;

    // الأبعاد الأصلية للصفحة (A4) ناقص الهوامش (margin: vertical 12, horizontal 16)
    // وذلك لضمان عمل الـ Widgets التي تعتمد على مساحة محددة (مثل Expanded و Spacer) بشكل صحيح داخل FittedBox.
    final double originalContentWidth = PdfPageFormat.a4.width - 32;
    final double originalContentHeight = PdfPageFormat.a4.height - 24;

    // الصفحة الأولى: البيانات الأساسية، جدول الأصناف، التضليع، تجهيزات الكرتون، وطباعة الأوفست والفلكسو
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        theme: theme,
        build: (pw.Context ctx) => pw.FittedBox(
          fit: pw.BoxFit.contain,
          child: pw.SizedBox(
            width: originalContentWidth,
            height: originalContentHeight,
            child: _buildPage1(
              data, regularFont, boldFont, printedFactoryName, factoryLogoBase64),
          ),
        ),
      ),
    );

    // الصفحة الثانية: تسليمات منتج تام، بيان مرفقات العميل، وتقرير الإقفال
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        theme: theme,
        build: (pw.Context ctx) => pw.FittedBox(
          fit: pw.BoxFit.contain,
          child: pw.SizedBox(
            width: originalContentWidth,
            height: originalContentHeight,
            child: _buildPage2(data, regularFont, boldFont),
          ),
        ),
      ),
    );

    final bytes = await doc.save();
    debugPrint(
        "✅ generateNativePdf: finished generating PDF bytes (${bytes.length} bytes).");
    return bytes;
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
                    build: (format) async => await generateNativePdf(data, format: format),
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
      debugPrint("🖨️ openForPrinting: Calling Printing.layoutPdf...");
      await Printing.layoutPdf(
        onLayout: (format) async {
          debugPrint("🖨️ layoutPdf onLayout triggered with format: $format");
          return await generateNativePdf(data, format: format);
        },
        name: 'job_order_${data.jobNumber}',
      );
      debugPrint("🖨️ openForPrinting: Printing dialog closed or completed.");
    } catch (e) {
      debugPrint("⚠️ Printing failed: $e");
    }
  }

  // ── Layout Builders ─────────────────────────────────────────────────────────

  static pw.Widget _buildPage1(JobOrderData data, pw.Font regularFont,
      pw.Font boldFont, String printedFactoryName, String? logoBase64) {
    final regularStyle = pw.TextStyle(font: regularFont, fontSize: 7.5);
    final boldStyle = pw.TextStyle(
        font: boldFont, fontSize: 7.5, fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(
        font: boldFont, fontSize: 12, fontWeight: pw.FontWeight.bold);
    final barStyle = pw.TextStyle(
        font: boldFont,
        fontSize: 8.5,
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold);

    final headerBarColor = PdfColor.fromHex('#3b3b3b');
    final labelBgColor = PdfColor.fromHex('#e9e9e9');
    final sigBgColor = PdfColor.fromHex('#eeeeee');
    final redColor = PdfColor.fromHex('#b30000');

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // بسم الله الرحمن الرحيم
          pw.Container(
            alignment: pw.Alignment.topRight,
            margin: const pw.EdgeInsets.only(bottom: 1),
            child: pw.Text(_ar("بسم الله الرحمن الرحيم"),
                style: boldStyle.copyWith(fontSize: 8.5)),
          ),

          // 1. Header (Company + Order Box)
          _buildPage1Header(
              data, boldStyle, regularStyle, printedFactoryName, logoBase64),

          // Title
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 2),
            alignment: pw.Alignment.center,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(_ar("أمر تشغيل رقم "), style: titleStyle),
                pw.Text(" ) ", style: titleStyle),
                pw.Text(
                  data.orderNumber.isEmpty
                      ? "          "
                      : " ${data.orderNumber} ",
                  style: titleStyle.copyWith(color: redColor),
                ),
                pw.Text(" ( ", style: titleStyle),
              ],
            ),
          ),

          // 2. Top Info Table
          _buildPage1TopInfo(data, boldStyle, regularStyle),
          pw.SizedBox(height: 1.5),

          // 3. Items Table (5 rows, 6 columns)
          _buildPage1ItemsTable(data, boldStyle, regularStyle, headerBarColor),
          pw.SizedBox(height: 1.5),

          // 4. التضليع
          _buildCorrugationSection(
              data, boldStyle, regularStyle, headerBarColor),
          pw.SizedBox(height: 1.5),

          // 5. تقرير قسم التضليع (5 صفوف)
          _buildCorrugationReportTable(
              data, boldStyle, regularStyle, headerBarColor),
          pw.SizedBox(height: 1.5),

          // 6. Carton Preparations (تجهيزات الكرتون)
          _buildPage1CartonPrep(
              boldStyle, regularStyle, barStyle, headerBarColor, labelBgColor),
          pw.SizedBox(height: 1.5),

          // 7. Flexo Printing (طباعة الفلكسو) - في نفس المكان الذي كان يحتله طباعة الأوفست
          _buildPage1FlexoPrinting(
              boldStyle, regularStyle, barStyle, headerBarColor, sigBgColor),
        ],
      ),
    );
  }

  static pw.Widget _buildPage2(
      JobOrderData data, pw.Font regularFont, pw.Font boldFont) {
    final regularStyle = pw.TextStyle(font: regularFont, fontSize: 7.5);
    final boldStyle = pw.TextStyle(
        font: boldFont, fontSize: 7.5, fontWeight: pw.FontWeight.bold);
    final barStyle = pw.TextStyle(
        font: boldFont,
        fontSize: 8.5,
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold);

    final headerBarColor = PdfColor.fromHex('#3b3b3b');

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Spacer(),
          // 8. Offset Printing (طباعة الأوفست - نُقل للصفحة الثانية)
          _buildPage1OffsetPrinting(
              boldStyle, regularStyle, barStyle, headerBarColor),
          pw.SizedBox(height: 6.0),

          // 9. تسليمات منتج تام (نُقل للصفحة الثانية - 10 خلايا)
          _buildDeliveriesTable(boldStyle, regularStyle, headerBarColor),
          pw.SizedBox(height: 6.0),

          // 10. بيان مرفقات العميل (نُقل للصفحة الثانية - 4 خلايا)
          _buildAttachmentsTable(boldStyle, regularStyle, headerBarColor),
          pw.SizedBox(height: 6.0),

          // 11. تقرير الإقفال (نُقل للصفحة الثانية)
          _buildClosingReport(boldStyle),
          pw.Spacer(),

          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(_ar("88% من الحجم الأصلى"),
                style: regularStyle.copyWith(fontSize: 7)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildClosingReport(pw.TextStyle boldStyle) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 16,
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  flex: 80,
                  child: pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(left: pw.BorderSide(width: 1.0))),
                    child: pw.Text(_ar("تقرير الإقفال     بتاريخ :"),
                        style: boldStyle.copyWith(fontSize: 8)),
                  ),
                ),
                pw.Expanded(
                  flex: 20,
                  child: pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Text(_ar("المخازن"),
                        style: boldStyle.copyWith(fontSize: 8)),
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            height: 24,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  flex: 80,
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(left: pw.BorderSide(width: 1.0))),
                  ),
                ),
                pw.Expanded(
                  flex: 20,
                  child: pw.Container(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPage1Header(
      JobOrderData data,
      pw.TextStyle boldStyle,
      pw.TextStyle regularStyle,
      String printedFactoryName,
      String? logoBase64) {
    final lines = printedFactoryName.split('\n');

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Company Name
        pw.Container(
          width: 145,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: lines
                .map((line) => pw.Text(_ar(line.trim()),
                    style: boldStyle.copyWith(fontSize: 12.5)))
                .toList(),
          ),
        ),

        // Middle Logo (Watermark / Image)
        if (logoBase64 != null && logoBase64.isNotEmpty)
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Container(
                height: 65,
                padding: const pw.EdgeInsets.all(6),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Image(
                  pw.MemoryImage(base64Decode(logoBase64)),
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          )
        else
          pw.Expanded(child: pw.SizedBox()),

        // Order Box (طلبية رقم / بتاريخ / محرر أمر التشغيل)
        pw.Container(
          width: 145,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.0),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _orderBoxRow(
                  "طلبية رقم :", data.jobNumber, boldStyle, regularStyle, true),
              _orderBoxRow(
                  "بتاريخ :",
                  data.orderDate.isEmpty ? _today() : data.orderDate,
                  boldStyle,
                  regularStyle,
                  true),
              _orderBoxRow("محرر أمر التشغيل :", data.createdBy, boldStyle,
                  regularStyle, false),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _orderBoxRow(String label, String val,
      pw.TextStyle boldStyle, pw.TextStyle regularStyle, bool isNum) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_ar(label), style: boldStyle.copyWith(fontSize: 8)),
          isNum && val.isNotEmpty
              ? pw.Directionality(
                  textDirection: pw.TextDirection.ltr,
                  child: pw.Text(val, style: boldStyle.copyWith(fontSize: 8)),
                )
              : pw.Text(_ar(val), style: boldStyle.copyWith(fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _buildPage1TopInfo(
      JobOrderData data, pw.TextStyle boldStyle, pw.TextStyle regularStyle) {
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.0)),
      child: pw.Column(
        children: [
          // Row 1
          pw.Row(children: [
            pw.Expanded(
                flex: 70,
                child: pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3.5),
                    child: pw.Text(
                        _ar("العميل : ${data.customerName.isEmpty ? '..........................................................................' : data.customerName}"),
                        style: boldStyle.copyWith(fontSize: 8.5)))),
            pw.Container(width: 1, height: 17, color: PdfColors.black),
            pw.Expanded(
                flex: 30,
                child: pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3.5),
                    child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          pw.Text(_ar("كود العميل : "),
                              style: boldStyle.copyWith(fontSize: 8.5)),
                          pw.Directionality(
                            textDirection: pw.TextDirection.ltr,
                            child: pw.Text(
                                data.clientCode.isEmpty
                                    ? '..........................'
                                    : data.clientCode,
                                style: boldStyle.copyWith(fontSize: 8.5)),
                          ),
                        ]))),
          ]),
          pw.Container(height: 1, color: PdfColors.black),
          // Row 2
          pw.Row(children: [
            pw.Expanded(
                flex: 33,
                child: pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3.5),
                    child: pw.Row(children: [
                      pw.Text(_ar("تاريخ بدء التشغيل : "),
                          style: regularStyle.copyWith(fontSize: 8.5)),
                      pw.Directionality(
                          textDirection: pw.TextDirection.ltr,
                          child: pw.Text(
                              data.startDate.isEmpty
                                  ? '.......................'
                                  : data.startDate,
                              style: boldStyle.copyWith(fontSize: 8.5))),
                    ]))),
            pw.Container(width: 1, height: 17, color: PdfColors.black),
            pw.Expanded(
                flex: 34,
                child: pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3.5),
                    child: pw.Row(children: [
                      pw.Text(_ar("ميعاد التسليم : "),
                          style: regularStyle.copyWith(fontSize: 8.5)),
                      pw.Directionality(
                          textDirection: pw.TextDirection.ltr,
                          child: pw.Text(
                              data.deliveryDate.isEmpty
                                  ? '.......................'
                                  : data.deliveryDate,
                              style: boldStyle.copyWith(fontSize: 8.5))),
                    ]))),
            pw.Container(width: 1, height: 17, color: PdfColors.black),
            pw.Expanded(
                flex: 33,
                child: pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3.5),
                    child: pw.Row(children: [
                      pw.Text(_ar("تاريخ الانتهاء : "),
                          style: regularStyle.copyWith(fontSize: 8.5)),
                      pw.Directionality(
                          textDirection: pw.TextDirection.ltr,
                          child: pw.Text(
                              data.receivedDate.isEmpty
                                  ? '.......................'
                                  : data.receivedDate,
                              style: boldStyle.copyWith(fontSize: 8.5))),
                    ]))),
          ]),
        ],
      ),
    );
  }

  static String _formatNumberWithCommas(String input) {
    if (input.isEmpty) return "";
    final clean = input.replaceAll(',', '').trim();
    final number = double.tryParse(clean);
    if (number != null) {
      if (number == number.truncateToDouble()) {
        final intNum = number.truncate();
        final str = intNum.toString();
        return str.replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
      } else {
        final parts = clean.split('.');
        final intPart = parts[0].replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
        return '$intPart.${parts.length > 1 ? parts[1] : ""}';
      }
    }
    return input;
  }

  static pw.Widget _buildPage1ItemsTable(
      JobOrderData data,
      pw.TextStyle boldStyle,
      pw.TextStyle regularStyle,
      PdfColor headerBarColor) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 1.0),
      columnWidths: {
        0: const pw.FlexColumnWidth(20),
        1: const pw.FlexColumnWidth(20),
        2: const pw.FlexColumnWidth(12),
        3: const pw.FlexColumnWidth(33),
        4: const pw.FlexColumnWidth(10),
        5: const pw.FlexColumnWidth(5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBarColor),
          children: [
            _tableHeaderCell("ملاحظات الصنف", boldStyle),
            _tableHeaderCell("الابعاد ( ط × ع × ا )", boldStyle),
            _tableHeaderCell("الكمية", boldStyle),
            _tableHeaderCell("بيان الصنف", boldStyle),
            _tableHeaderCell("كود", boldStyle),
            _tableHeaderCell("م", boldStyle),
          ],
        ),
        for (int i = 0; i < 5; i++)
          pw.TableRow(
            children: [
              _itemBodyCell(
                  i < data.items.length ? data.items[i].itemNotes : "",
                  regularStyle,
                  false,
                  false),
              _itemBodyCell(
                  i < data.items.length
                      ? "${data.items[i].height} × ${data.items[i].width} × ${data.items[i].length}"
                          .replaceAll(RegExp(r'^[ ×]+|[ ×]+$'), '')
                      : "",
                  boldStyle,
                  true,
                  true),
              _itemBodyCell(
                  i < data.items.length
                      ? _formatNumberWithCommas(data.items[i].quantity)
                      : "",
                  boldStyle,
                  true,
                  true),
              _itemBodyCell(
                  i < data.items.length ? data.items[i].productName : "",
                  boldStyle,
                  false,
                  false),
              _itemBodyCell(
                  i < data.items.length ? data.items[i].productCode : "",
                  boldStyle,
                  true,
                  true),
              _itemBodyCell(
                  i < _arabicNumerals.length ? _arabicNumerals[i] : "${i + 1}",
                  boldStyle,
                  true,
                  false),
            ],
          ),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text, pw.TextStyle boldStyle) {
    return pw.Container(
      height: 16,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      child: pw.Text(_ar(text),
          style: boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
          textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _itemBodyCell(
      String text, pw.TextStyle style, bool center, bool isLTR) {
    return pw.Container(
      height: 17,
      alignment: center ? pw.Alignment.center : pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 3),
      child: text.isEmpty
          ? pw.SizedBox()
          : isLTR
              ? pw.Directionality(
                  textDirection: pw.TextDirection.ltr,
                  child: pw.Text(text,
                      style: style.copyWith(fontSize: 8.5),
                      textAlign:
                          center ? pw.TextAlign.center : pw.TextAlign.right),
                )
              : pw.Text(_ar(text),
                  style: style.copyWith(fontSize: 8.5),
                  textAlign: center ? pw.TextAlign.center : pw.TextAlign.right),
    );
  }

  static pw.Widget _plainCheckboxWithLabel(String label) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(_ar(label), style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(width: 3),
        _squareCheckbox(),
      ],
    );
  }

  static pw.Widget _squareCheckbox() {
    return pw.Container(
      width: 8,
      height: 8,
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.0)),
    );
  }

  static pw.Widget _prepRow(String label, pw.Widget content,
      pw.TextStyle boldStyle, pw.TextStyle regularStyle, PdfColor labelBgColor,
      {bool isLast = false, double height = 18}) {
    final bottomBorder = isLast
        ? pw.BorderSide.none
        : const pw.BorderSide(color: PdfColors.black, width: 1.5);
    return pw.Container(
      height: height,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            width: 68,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
                color: labelBgColor,
                border: pw.Border(
                    left:
                        const pw.BorderSide(color: PdfColors.black, width: 1.0),
                    bottom: bottomBorder)),
            padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 2),
            child: pw.Text(_ar(label),
                style: boldStyle.copyWith(fontSize: 8),
                textAlign: pw.TextAlign.center),
          ),
          pw.Expanded(
            child: pw.Container(
              decoration:
                  pw.BoxDecoration(border: pw.Border(bottom: bottomBorder)),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              alignment: pw.Alignment.centerRight,
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPage1CartonPrep(
      pw.TextStyle boldStyle,
      pw.TextStyle regularStyle,
      pw.TextStyle barStyle,
      PdfColor headerBarColor,
      PdfColor labelBgColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.0)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                height: 16,
                color: headerBarColor,
                alignment: pw.Alignment.center,
                child: pw.Text(_ar("تجهيزات الكرتون"), style: barStyle),
              ),
              _prepRow(
                  "فرمة تكسير",
                  pw.Text(
                      _ar("مقاس (             )    لعدد (             ) . علبة    التوقيع والتاريخ :"),
                      style: regularStyle.copyWith(fontSize: 8)),
                  boldStyle,
                  regularStyle,
                  labelBgColor,
                  height: 18),
              pw.Container(
                height: 16,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _cartonHalfRow("ريجة", _squareCheckbox(), boldStyle,
                        labelBgColor, true),
                    _cartonHalfRow("تفتيح", _squareCheckbox(), boldStyle,
                        labelBgColor, false),
                  ],
                ),
              ),
              pw.Container(
                height: 16,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _cartonHalfRow("دبوس", _squareCheckbox(), boldStyle,
                        labelBgColor, true),
                    _cartonHalfRow(
                        "لصق عادى . آلى",
                        pw.Row(children: [
                          _squareCheckbox(),
                          pw.SizedBox(width: 6),
                          _squareCheckbox()
                        ]),
                        boldStyle,
                        labelBgColor,
                        false),
                  ],
                ),
              ),
              pw.Container(
                height: 17,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _sigQuarterCell("التوقيع :", regularStyle, true),
                    _sigQuarterCell("التوقيع :", regularStyle, true),
                    _sigQuarterCell("التوقيع :", regularStyle, true),
                    _sigQuarterCell("التوقيع :", regularStyle, false),
                  ],
                ),
              ),
              _prepRow("ملاحظات", pw.Container(height: 11), boldStyle,
                  regularStyle, labelBgColor,
                  isLast: true, height: 18),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _cartonHalfRow(String label, pw.Widget content,
      pw.TextStyle boldStyle, PdfColor labelBgColor, bool hasLeftBorder) {
    const bottomBorder = pw.BorderSide(color: PdfColors.black, width: 1.5);
    const sideBorder = pw.BorderSide(color: PdfColors.black, width: 1.5);
    return pw.Expanded(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            width: 68,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
                color: labelBgColor,
                border: pw.Border(
                    left: hasLeftBorder
                        ? const pw.BorderSide(
                            color: PdfColors.black, width: 1.0)
                        : sideBorder,
                    right: sideBorder,
                    bottom: bottomBorder)),
            padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 2),
            child: pw.Text(_ar(label),
                style: boldStyle.copyWith(fontSize: 8),
                textAlign: pw.TextAlign.center),
          ),
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: bottomBorder)),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              alignment: pw.Alignment.centerRight,
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sigQuarterCell(
      String text, pw.TextStyle style, bool hasLeftBorder) {
    const bottomBorder = pw.BorderSide(color: PdfColors.black, width: 1.5);
    return pw.Expanded(
      child: pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border(
                left: hasLeftBorder
                    ? const pw.BorderSide(color: PdfColors.black, width: 1.0)
                    : pw.BorderSide.none,
                bottom: bottomBorder)),
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        alignment: pw.Alignment.centerRight,
        child: pw.Text(_ar(text), style: style.copyWith(fontSize: 8)),
      ),
    );
  }

  static pw.Widget _buildPage1OffsetPrinting(
      pw.TextStyle boldStyle,
      pw.TextStyle regularStyle,
      pw.TextStyle barStyle,
      PdfColor headerBarColor) {
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.0)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 16,
            color: headerBarColor,
            alignment: pw.Alignment.center,
            child: pw.Text(_ar("طباعة الأوفست"), style: barStyle),
          ),
          pw.Container(
            height: 34,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  flex: 80,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(_ar("تقرير رئيس القسم .."),
                        style: regularStyle.copyWith(fontSize: 8)),
                  ),
                ),
                pw.Expanded(
                  flex: 20,
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(right: pw.BorderSide(width: 1.0))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Container(
                          height: 18,
                          alignment: pw.Alignment.center,
                          decoration: const pw.BoxDecoration(
                              border:
                                  pw.Border(bottom: pw.BorderSide(width: 1.0))),
                          child: pw.Text(_ar("التوقيع والتاريخ"),
                              style: boldStyle.copyWith(fontSize: 8)),
                        ),
                        pw.Expanded(child: pw.Container()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPage1FlexoPrinting(
      pw.TextStyle boldStyle,
      pw.TextStyle regularStyle,
      pw.TextStyle barStyle,
      PdfColor headerBarColor,
      PdfColor sigBgColor) {
    return pw.Container(
      height: 64,
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.0)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 16,
            color: headerBarColor,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Text(_ar("طباعة الفلكسو"), style: barStyle),
                  ),
                ),
                pw.Container(
                  width: 55,
                  alignment: pw.Alignment.center,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      right: pw.BorderSide(color: PdfColors.white, width: 1.0),
                    ),
                  ),
                  child: pw.Text(_ar("توقيع المختص"),
                      style: barStyle.copyWith(fontSize: 7.5),
                      textAlign: pw.TextAlign.center),
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Container(
                        height: 16,
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        alignment: pw.Alignment.centerRight,
                        decoration: const pw.BoxDecoration(
                            border:
                                pw.Border(bottom: pw.BorderSide(width: 1.0))),
                        child: pw.Text(
                            _ar("طباعة   ألوان (             ) - إجمالى عدد الألوان ............................."),
                            style: regularStyle.copyWith(fontSize: 8)),
                      ),
                      pw.Container(
                        height: 16,
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        alignment: pw.Alignment.centerRight,
                        decoration: const pw.BoxDecoration(
                            border:
                                pw.Border(bottom: pw.BorderSide(width: 1.0))),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(_ar("فرز طباعة    "),
                                style: regularStyle.copyWith(fontSize: 8)),
                            _plainCheckboxWithLabel("أول"),
                            pw.SizedBox(width: 12),
                            _plainCheckboxWithLabel("ثانى"),
                            pw.SizedBox(width: 12),
                            _plainCheckboxWithLabel("هالك"),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(_ar("ملاحظات"),
                              style: boldStyle.copyWith(fontSize: 8)),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: 55,
                  decoration: pw.BoxDecoration(
                    color: sigBgColor,
                    border: const pw.Border(
                      right: pw.BorderSide(color: PdfColors.black, width: 1.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCorrugationSection(JobOrderData data,
      pw.TextStyle boldStyle, pw.TextStyle regularStyle, PdfColor headerColor) {
    const int totalSlots = 5;
    final List<JobOrderItem> corrugationItems = [];
    for (int i = 0; i < totalSlots; i++) {
      if (i < data.items.length) {
        corrugationItems.add(data.items[i]);
      } else {
        corrugationItems.add(JobOrderItem(
            productName: '', productCode: '', quantity: '', itemNotes: ''));
      }
    }

    double rowHeight = 15; // header
    for (int i = 0; i < totalSlots; i++) {
      rowHeight += 12; // product name header
      rowHeight += 13; // corrugation checkboxes row
      rowHeight += 13; // box size + sheet size + roll width row
      rowHeight += 13; // paper layers row
      if (i < totalSlots - 1) rowHeight += 1.5; // border
    }

    return pw.Container(
      height: rowHeight,
      margin: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            flex: 76,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.0),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    height: 15,
                    color: headerColor,
                    alignment: pw.Alignment.center,
                    child: pw.Text(_ar("التضليع"),
                        style: boldStyle.copyWith(
                            color: PdfColors.white, fontSize: 8.5)),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: List.generate(totalSlots, (idx) {
                        return _buildSingleCorrugationItemBlock(
                            corrugationItems[idx],
                            isLast: idx == totalSlots - 1,
                            boldStyle: boldStyle,
                            regularStyle: regularStyle,
                            headerColor: headerColor,
                            itemIndex: idx,
                            totalItems: totalSlots);
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 3),
          pw.Expanded(
            flex: 24,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.0),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    height: 15,
                    color: headerColor,
                    alignment: pw.Alignment.center,
                    child: pw.Text(_ar("ملاحظات وتعليمات عامة"),
                        style: boldStyle.copyWith(
                            color: PdfColors.white, fontSize: 7.5)),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Container(
                          height: 16,
                          alignment: pw.Alignment.center,
                          child: pw.Text(_ar("توقيع فنى التضليع والتاريخ"),
                              style: boldStyle.copyWith(fontSize: 7.5)),
                        ),
                        pw.Expanded(
                          child: pw.Padding(
                            padding:
                                const pw.EdgeInsets.symmetric(horizontal: 4),
                            child: pw.Column(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceEvenly,
                              children: List.generate(6, (_) => _dottedLine()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                            top: pw.BorderSide(
                                color: PdfColors.black, width: 1.0)),
                      ),
                      padding: const pw.EdgeInsets.all(4),
                      alignment: pw.Alignment.topRight,
                      child: data.generalNotes.trim().isNotEmpty
                          ? pw.Text(_ar(data.generalNotes),
                              style: regularStyle.copyWith(fontSize: 7.5))
                          : pw.SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final bool isEmptyItem =
        item.productName.isEmpty && item.productCode.isEmpty;
    return pw.Container(
      decoration: isLast
          ? null
          : const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(width: 1.5, color: PdfColors.black))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 12,
            color: PdfColors.grey400,
            padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
            alignment: pw.Alignment.center,
            child: isEmptyItem
                ? pw.SizedBox()
                : pw.Text(_ar("${item.productName} - ${item.productCode}"),
                    style: boldStyle.copyWith(fontSize: 8)),
          ),
          pw.Container(
            height: 13,
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  flex: 36,
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(left: pw.BorderSide(width: 1.0))),
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                    child: pw.Text(
                        _ar("عرض البكر : ${item.rollWidth.isEmpty ? '______' : item.rollWidth}"),
                        style: boldStyle.copyWith(fontSize: 8)),
                  ),
                ),
                pw.Expanded(
                  flex: 64,
                  child: pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                    child: pw.Row(
                      children: [
                        pw.Text(_ar("التضليع : "),
                            style: boldStyle.copyWith(fontSize: 8)),
                        pw.Expanded(
                          child: pw.Row(
                            mainAxisAlignment: isEmptyItem
                                ? pw.MainAxisAlignment.end
                                : pw.MainAxisAlignment.center,
                            children: isEmptyItem
                                ? [
                                    _corrugationCheckbox('E', false, boldStyle),
                                    pw.SizedBox(width: 6),
                                    _corrugationCheckbox('C', false, boldStyle),
                                    pw.SizedBox(width: 6),
                                    _corrugationCheckbox(
                                        'E/E', false, boldStyle),
                                    pw.SizedBox(width: 6),
                                    _corrugationCheckbox(
                                        'C/C', false, boldStyle),
                                    pw.SizedBox(width: 6),
                                    _corrugationCheckbox(
                                        'C/E', false, boldStyle),
                                  ]
                                : (item.corrugationTypes.isEmpty &&
                                        item.customCorrugation.isEmpty
                                    ? []
                                    : (item.corrugationTypes.isNotEmpty
                                        ? item.corrugationTypes
                                            .asMap()
                                            .entries
                                            .map((e) {
                                            final i = e.key;
                                            final type = e.value;
                                            return pw.Row(
                                              mainAxisSize: pw.MainAxisSize.min,
                                              children: [
                                                if (i > 0)
                                                  pw.SizedBox(width: 10),
                                                _corrugationCheckbox(
                                                    type, true, boldStyle,
                                                    isSolidBlack: true),
                                              ],
                                            );
                                          }).toList()
                                        : [
                                            _corrugationCheckbox(
                                                item.customCorrugation,
                                                true,
                                                boldStyle,
                                                isSolidBlack: true)
                                          ])),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            height: 13,
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  flex: 36,
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(left: pw.BorderSide(width: 1.0))),
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                    child: pw.Text(
                        _ar("مقاس العلبة : ${item.corrugationBoxSize.isEmpty ? '______' : item.corrugationBoxSize}"),
                        style: boldStyle.copyWith(fontSize: 8)),
                  ),
                ),
                pw.Expanded(
                  flex: 64,
                  child: pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                    child: pw.Row(
                      children: [
                        pw.Text(_ar("مقاس الشريحة : "),
                            style: boldStyle.copyWith(fontSize: 8)),
                        pw.Expanded(
                          child: pw.Container(
                            alignment: pw.Alignment.center,
                            child: pw.Directionality(
                              textDirection: pw.TextDirection.ltr,
                              child: pw.Text(
                                  item.corrugationSheetSize.isEmpty
                                      ? '  /  '
                                      : item.corrugationSheetSize
                                          .split('/')
                                          .map((e) => e.trim())
                                          .toList()
                                          .reversed
                                          .join(' / '),
                                  style: boldStyle.copyWith(fontSize: 8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            height: 13,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(_ar("طبقات الورق : "),
                    style: boldStyle.copyWith(fontSize: 7.5)),
                if (item.paperLayers.isNotEmpty)
                  ...item.paperLayers.asMap().entries.expand((e) {
                    final i = e.key;
                    final layer = e.value;
                    return [
                      if (i > 0) ...[
                        pw.SizedBox(width: 6),
                        pw.Text(_ar("/"),
                            style: boldStyle.copyWith(fontSize: 7.5)),
                        pw.SizedBox(width: 6),
                      ],
                      pw.Directionality(
                        textDirection: pw.TextDirection.ltr,
                        child: pw.Text("L${i + 1}",
                            style: boldStyle.copyWith(fontSize: 7.5)),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(_ar(layer),
                          style: regularStyle.copyWith(fontSize: 7.5)),
                    ];
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCorrugationReportTable(JobOrderData data,
      pw.TextStyle boldStyle, pw.TextStyle regularStyle, PdfColor headerColor) {
    int rowCount = 5; // تقليل من 10 إلى 5 صفوف لتوفير المساحة
    final numbersAr = ["١", "٢", "٣", "٤", "٥"];

    return pw.Container(
      height: 109, // 16 + 13 + 5 * 16 = 109
      margin: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            flex: 78,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.0),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    height: 16,
                    alignment: pw.Alignment.center,
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
                    child: pw.Text(
                      _ar("تقرير قسم التضليع ( تدوين الدفعات التى تم تشغيلها فى حالة تنفيذ الأمر على عدة دفعات )"),
                      style: boldStyle.copyWith(fontSize: 7.5),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Container(
                    height: 13,
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Expanded(flex: 8, child: pw.SizedBox()),
                        pw.Expanded(
                          flex: 92,
                          child: pw.Container(
                            alignment: pw.Alignment.center,
                            decoration: const pw.BoxDecoration(
                                border:
                                    pw.Border(left: pw.BorderSide(width: 1.0))),
                            child: pw.Text(
                              _ar("اسم القائم بالتشغيل مع التوقيع والتاريخ ."),
                              style: boldStyle.copyWith(fontSize: 7.5),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(rowCount, (index) {
                    return pw.Container(
                      height: 16,
                      decoration: index == rowCount - 1
                          ? null
                          : const pw.BoxDecoration(
                              border:
                                  pw.Border(bottom: pw.BorderSide(width: 1.0))),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Expanded(
                            flex: 8,
                            child: pw.Container(
                              alignment: pw.Alignment.center,
                              child: pw.Text(_ar(numbersAr[index]),
                                  style: boldStyle.copyWith(fontSize: 8)),
                            ),
                          ),
                          pw.Expanded(
                            flex: 92,
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                      left: pw.BorderSide(width: 1.0))),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 3),
          pw.Expanded(
            flex: 22,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.0),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    height: 16,
                    color: headerColor,
                    alignment: pw.Alignment.center,
                    child: pw.Text(_ar("ملاحظات وتعليمات"),
                        style: boldStyle.copyWith(
                            color: PdfColors.white, fontSize: 7.5)),
                  ),
                  pw.Container(
                    height: 15,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                        _ar("( ملء الخانات النادرة بواسطة الفني المختص )"),
                        style: regularStyle.copyWith(fontSize: 7)),
                  ),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                        children: List.generate(12, (_) => _dottedLine()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _corrugationCheckbox(
      String label, bool isChecked, pw.TextStyle style,
      {bool isSolidBlack = false}) {
    return pw.Directionality(
      textDirection: pw.TextDirection.ltr,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Transform.translate(
            offset: const PdfPoint(0, 2.5),
            child: pw.Text(_ar(label), style: style.copyWith(fontSize: 8)),
          ),
          pw.SizedBox(width: 4),
          pw.Container(
            width: 8,
            height: 8,
            decoration: pw.BoxDecoration(
              color: isSolidBlack ? PdfColors.black : null,
              border: pw.Border.all(color: PdfColors.black, width: 1.0),
            ),
            child: isChecked && !isSolidBlack
                ? pw.CustomPaint(
                    size: const PdfPoint(8, 8),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      canvas.moveTo(1.5, 4);
                      canvas.lineTo(3.5, 2);
                      canvas.lineTo(6.5, 6);
                      canvas.setStrokeColor(PdfColors.black);
                      canvas.setLineWidth(1.2);
                      canvas.strokePath();
                    })
                : null,
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────────

  // ignore: unused_element
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

  static pw.Widget _buildDeliveriesTable(
      pw.TextStyle boldStyle, pw.TextStyle regularStyle, PdfColor headerColor) {
    return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.0),
        ),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                height: 16,
                color: headerColor,
                alignment: pw.Alignment.center,
                child: pw.Text(_ar("تسليمات منتج تام"),
                    style: boldStyle.copyWith(
                        color: PdfColors.white, fontSize: 8)),
              ),
              pw.Container(
                  height: 24,
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(width: 1.0))),
                  child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _buildDeliveriesHeaderCell("م", 4, boldStyle),
                        _buildDeliveriesHeaderCell("بيـــان", 16, boldStyle),
                        _buildDeliveriesHeaderCell(
                            "إجمالي العدد", 8, boldStyle),
                        pw.Expanded(
                            flex: 14,
                            child: pw.Container(
                                decoration: const pw.BoxDecoration(
                                    border: pw.Border(
                                        left: pw.BorderSide(width: 1.0))),
                                child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.stretch,
                                    children: [
                                      pw.Container(
                                        height: 12,
                                        alignment: pw.Alignment.center,
                                        child: pw.Text(_ar("رقم"),
                                            style:
                                                boldStyle.copyWith(fontSize: 7),
                                            textAlign: pw.TextAlign.center),
                                      ),
                                      pw.Container(
                                          height: 12,
                                          decoration: const pw.BoxDecoration(
                                              border: pw.Border(
                                                  top: pw.BorderSide(
                                                      width: 1.0))),
                                          child: pw.Row(
                                              crossAxisAlignment:
                                                  pw.CrossAxisAlignment.stretch,
                                              children: [
                                                pw.Expanded(
                                                    flex: 1,
                                                    child: pw.Container(
                                                      alignment:
                                                          pw.Alignment.center,
                                                      child: pw.Text(_ar("إذن"),
                                                          style: boldStyle
                                                              .copyWith(
                                                                  fontSize: 6),
                                                          textAlign: pw
                                                              .TextAlign
                                                              .center),
                                                    )),
                                                pw.Container(
                                                    width: 1,
                                                    color: PdfColors.black),
                                                pw.Expanded(
                                                    flex: 1,
                                                    child: pw.Container(
                                                      alignment:
                                                          pw.Alignment.center,
                                                      child: pw.Text(
                                                          _ar("تصريح"),
                                                          style: boldStyle
                                                              .copyWith(
                                                                  fontSize: 6),
                                                          textAlign: pw
                                                              .TextAlign
                                                              .center),
                                                    )),
                                              ]))
                                    ]))),
                        _buildDeliveriesHeaderCell("بتاريخ", 9, boldStyle),
                        _buildDeliveriesHeaderCell("سيارة", 9, boldStyle),
                        _buildDeliveriesHeaderCell("اسم السائق", 14, boldStyle),
                        _buildDeliveriesHeaderCell("ملاحظات", 14, boldStyle),
                        _buildDeliveriesHeaderCell(
                            "توقيع المخازن", 12, boldStyle, false),
                      ])),
              ...List.generate(10, (index) {
                final numbersAr = [
                  "١",
                  "٢",
                  "٣",
                  "٤",
                  "٥",
                  "٦",
                  "٧",
                  "٨",
                  "٩",
                  "١٠"
                ];
                return pw.Container(
                    height: 16,
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(width: 1.0))),
                    child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          _buildDeliveriesEmptyCell(
                              4, true, regularStyle, _ar(numbersAr[index])),
                          _buildDeliveriesEmptyCell(16, true, regularStyle),
                          _buildDeliveriesEmptyCell(8, true, regularStyle),
                          _buildDeliveriesEmptyCell(7, true, regularStyle),
                          _buildDeliveriesEmptyCell(7, true, regularStyle),
                          _buildDeliveriesEmptyCell(9, true, regularStyle),
                          _buildDeliveriesEmptyCell(9, true, regularStyle),
                          _buildDeliveriesEmptyCell(14, true, regularStyle),
                          _buildDeliveriesEmptyCell(14, true, regularStyle),
                          _buildDeliveriesEmptyCell(12, false, regularStyle),
                        ]));
              }),
            ]));
  }

  static pw.Widget _buildDeliveriesHeaderCell(
      String text, int flex, pw.TextStyle style,
      [bool hasLeftBorder = true]) {
    return pw.Expanded(
        flex: flex,
        child: pw.Container(
          alignment: pw.Alignment.center,
          decoration: hasLeftBorder
              ? const pw.BoxDecoration(
                  border: pw.Border(left: pw.BorderSide(width: 1.0)))
              : null,
          child: pw.Text(_ar(text),
              style: style.copyWith(fontSize: 7),
              textAlign: pw.TextAlign.center),
        ));
  }

  static pw.Widget _buildDeliveriesEmptyCell(
      int flex, bool hasLeftBorder, pw.TextStyle style,
      [String text = ""]) {
    return pw.Expanded(
        flex: flex,
        child: pw.Container(
          alignment: pw.Alignment.center,
          decoration: hasLeftBorder
              ? const pw.BoxDecoration(
                  border: pw.Border(left: pw.BorderSide(width: 1.0)))
              : null,
          child: text.isNotEmpty
              ? pw.Text(text, style: style.copyWith(fontSize: 7))
              : pw.SizedBox(),
        ));
  }

  static pw.Widget _buildAttachmentsTable(
      pw.TextStyle boldStyle, pw.TextStyle regularStyle, PdfColor headerColor) {
    final numbersAr = ["١", "٢", "٣", "٤"];
    return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.0),
        ),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                  height: 16,
                  color: headerColor,
                  child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _buildAttachmentsHeaderCell("م", 5, boldStyle),
                        _buildAttachmentsHeaderCell("تاريخ", 15, boldStyle),
                        _buildAttachmentsHeaderCell(
                            "بيان مرفقات العميل", 40, boldStyle),
                        _buildAttachmentsHeaderCell(
                            "توقيع المختص", 20, boldStyle),
                        _buildAttachmentsHeaderCell(
                            "ملاحظات", 20, boldStyle, false),
                      ])),
              ...List.generate(4, (index) {
                return pw.Container(
                    height: 16,
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(width: 1.0))),
                    child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          _buildDeliveriesEmptyCell(
                              5, true, regularStyle, _ar(numbersAr[index])),
                          _buildDeliveriesEmptyCell(15, true, regularStyle),
                          _buildDeliveriesEmptyCell(40, true, regularStyle),
                          _buildDeliveriesEmptyCell(20, true, regularStyle),
                          _buildDeliveriesEmptyCell(20, false, regularStyle),
                        ]));
              }),
            ]));
  }

  static pw.Widget _buildAttachmentsHeaderCell(
      String text, int flex, pw.TextStyle style,
      [bool hasLeftBorder = true]) {
    return pw.Expanded(
        flex: flex,
        child: pw.Container(
          alignment: pw.Alignment.center,
          decoration: hasLeftBorder
              ? const pw.BoxDecoration(
                  border: pw.Border(left: pw.BorderSide(width: 1.0)))
              : null,
          child: pw.Text(_ar(text),
              style: style.copyWith(color: PdfColors.white, fontSize: 8)),
        ));
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
