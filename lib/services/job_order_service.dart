import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

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

  bool get hasCorrugation => corrugationTypes.isNotEmpty || customCorrugation.isNotEmpty;
}

/// بيانات أمر التشغيل الكامل — يُمرَّر إلى [JobOrderService.generateHtml]
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

/// يتولى تحميل قالب HTML من assets، حقن البيانات، وفتح الملف للطباعة على سطح المكتب
class JobOrderService {
  static const _arabicNumerals = [
    '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '١٠', '١١', '١٢',
  ];

  // ── Public API ──────────────────────────────────────────────────────────────

  /// يولِّد HTML مُملَّأ بالبيانات من القالب المخزَّن في assets
  static Future<String> generateHtml(JobOrderData data) async {
    String html = await rootBundle.loadString('assets/html/order.html');

    // --- Header
    html = html.replaceAll('{{order_number}}', _safe(data.orderNumber, '____'));
    html = html.replaceAll('{{job_number}}', _safe(data.jobNumber));
    html = html.replaceAll('{{order_date}}', _safe(data.orderDate, _today()));
    html = html.replaceAll('{{created_by}}', _safe(data.createdBy));

    // --- Client info
    html = html.replaceAll('{{customer_name}}', _safe(data.customerName));
    html = html.replaceAll('{{client_code}}', _safe(data.clientCode));
    html = html.replaceAll('{{address}}', _safe(data.address));
    html = html.replaceAll('{{supervisor}}', _safe(data.supervisor));
    html = html.replaceAll('{{phone}}', _safe(data.phone));
    html = html.replaceAll('{{start_date}}', _safe(data.startDate));
    html = html.replaceAll('{{delivery_date}}', _safe(data.deliveryDate));
    html = html.replaceAll('{{received_date}}', _safe(data.receivedDate));

    html = html.replaceAll('{{items_table_rows}}', _buildItemsRows(data.items));

    // --- Corrugation dynamic blocks
    html = html.replaceAll(
      '{{corrugation_specs_blocks}}',
      _buildCorrugationSpecsBlocks(data.items),
    );

    // --- General notes
    html = html.replaceAll(
      '{{general_notes_lines}}',
      _buildNotesLines(data.generalNotes),
    );

    return html;
  }

  /// يفتح الـ HTML للطباعة بطريقة متوافقة مع جميع المنصات (بما في ذلك الويب وسطح المكتب)
  static Future<void> openForPrinting(String html) async {
    try {
      // استخدام حزمة printing المدمجة لعرض نافذة الطباعة مباشرة
      await Printing.layoutPdf(
        // ignore: deprecated_member_use
        onLayout: (format) async => await Printing.convertHtml(
          html: html,
          format: format,
        ),
        name: 'order_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      debugPrint("⚠️ Printing failed, trying fallback: $e");
      if (!kIsWeb) {
        await openHtmlInBrowserFallback(html);
      } else {
        rethrow;
      }
    }
  }

  /// خطة بديلة لفتح ملف الـ HTML في المتصفح الافتراضي للطباعة إذا تعذر تحميل المعاينة المدمجة
  static Future<void> openHtmlInBrowserFallback(String html) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/job_order_$timestamp.html');
      await file.writeAsString(html);
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("⚠️ Printing fallback failed: $e");
    }
  }

  /// يفتح نافذة معاينة تفاعلية فاخرة للـ PDF تتيح للمستخدم استعراض الصفحات، تحميل الملف، أو طباعته
  static Future<void> showPreview(BuildContext context, String html) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                // Header of preview dialog
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1A3A6E),
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
                          Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'معاينة أمر التشغيل PDF',
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
                // Body - PdfPreview
                Expanded(
                  child: PdfPreview(
                    build: (format) async => await Printing.convertHtml( // ignore: deprecated_member_use
                      html: html,
                      format: format,
                    ),
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: 'order_${DateTime.now().millisecondsSinceEpoch}.pdf',
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1A3A6E),
                      ),
                    ),
                    previewPageMargin: const EdgeInsets.all(12),
                    onError: (previewCtx, error) {
                      final bool isMissingPlugin = error is MissingPluginException || error.toString().contains('MissingPluginException');
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                isMissingPlugin 
                                  ? 'عذراً، يجب إعادة تشغيل التطبيق بالكامل (Cold Run / Rebuild)'
                                  : 'خطأ في معالجة ملف PDF',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isMissingPlugin
                                  ? 'تم إضافة حزم برمجية جديدة تتطلب إعادة بناء وتجميع ملفات الـ C++ الخاصة بنظام تشغيل Windows.\nيرجى إغلاق نافذة التطبيق تماماً (Stop) وإعادة تشغيله من جديد (Run) لتفعيل محرك المعاينة.'
                                  : 'حدث خطأ غير متوقع أثناء معالجة القالب: $error',
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(color: Colors.grey, height: 1.5, fontSize: 12),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A3A6E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.open_in_browser, size: 18),
                                label: const Text('الفتح في المتصفح الافتراضي كبديل مؤقت', style: TextStyle(fontSize: 12)),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await JobOrderService.openHtmlInBrowserFallback(html);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Private Helpers ─────────────────────────────────────────────────────────

  static String _safe(String value, [String fallback = '']) =>
      value.trim().isEmpty ? fallback : value.trim();

  static String _today() {
    final now = DateTime.now();
    return '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
  }



  /// يبني صفوف الجدول الديناميكي للأصناف
  static String _buildItemsRows(List<JobOrderItem> items) {
    if (items.isEmpty) {
      // صف فارغ احتياطي
      return '''
<tr>
  <td class="col-m">١</td>
  <td class="col-desc"></td>
  <td class="col-quantity"></td>
  <td class="col-dims"></td>
  <td class="col-notes"></td>
  <td class="col-review">
    <div class="dotted-cell-lines">
      <div class="dotted-line-placeholder"></div>
      <div class="dotted-line-placeholder"></div>
      <div class="dotted-line-placeholder"></div>
    </div>
  </td>
</tr>''';
    }

    final buffer = StringBuffer();
    final reviewLines = (items.length * 3).clamp(4, 12);

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final num = i < _arabicNumerals.length ? _arabicNumerals[i] : '${i + 1}';
      final dims = [item.length, item.width, item.height]
          .where((v) => v.isNotEmpty)
          .join(' × ');

      buffer.write('<tr>');
      buffer.write('<td class="col-m">$num</td>');
      buffer.write(
        '<td class="col-desc">${_esc(item.productName)}'
        '${item.productCode.isNotEmpty ? " (${_esc(item.productCode)})" : ""}</td>',
      );
      buffer.write('<td class="col-quantity">${_esc(item.quantity)}</td>');
      buffer.write('<td class="col-dims">${_esc(dims)}</td>');
      buffer.write('<td class="col-notes">${_esc(item.itemNotes)}</td>');

      // عمود المراجعة — rowspan يغطي كل الأصناف (يُضاف فقط في الصف الأول)
      if (i == 0) {
        buffer.write(
          '<td rowspan="${items.length}" class="col-review">'
          '<div class="dotted-cell-lines">',
        );
        for (int j = 0; j < reviewLines; j++) {
          buffer.write('<div class="dotted-line-placeholder"></div>');
        }
        buffer.write('</div></td>');
      }
      buffer.writeln('</tr>');
    }

    return buffer.toString();
  }

  /// يبني أسطر الملاحظات في قسم "ملاحظات وتعليمات"
  static String _buildNotesLines(String notes) {
    if (notes.trim().isEmpty) {
      return List.generate(
        5,
        (_) => '<div class="dotted-line-placeholder"></div>',
      ).join('\n');
    }
    return notes
        .split('\n')
        .map(
          (line) =>
              '<div class="dotted-line-placeholder" '
              'style="color: #1a202c; font-weight: 500;">'
              '${_esc(line)}</div>',
        )
        .join('\n');
  }

  static String _buildCorrugationSpecsBlocks(List<JobOrderItem> items) {
    final corrugationItems = items.where((i) => i.hasCorrugation).toList();
    
    if (corrugationItems.isEmpty) {
      return _buildCorrugationTable(
        index: null,
        types: [],
        custom: '',
        samples: '',
        boxSize: '',
        sheetSize: '',
        sheetCount: '',
      );
    }
    
    final buffer = StringBuffer();
    for (int i = 0; i < corrugationItems.length; i++) {
      final item = corrugationItems[i];
      buffer.write(_buildCorrugationTable(
        index: i + 1,
        types: item.corrugationTypes,
        custom: item.customCorrugation,
        samples: item.corrugationSamples,
        boxSize: item.corrugationBoxSize,
        sheetSize: item.corrugationSheetSize,
        sheetCount: item.corrugationSheetCount,
      ));
    }
    return buffer.toString();
  }

  static String _buildCorrugationTable({
    required int? index,
    required List<String> types,
    required String custom,
    required String samples,
    required String boxSize,
    required String sheetSize,
    required String sheetCount,
  }) {
    final title = index != null ? 'التضليع (صنف $index)' : 'التضليع';
    
    final isE = types.contains('E') ? 'checked' : '';
    final isC = types.contains('C') ? 'checked' : '';
    final isEE = types.contains('E/E') ? 'checked' : '';
    final isCC = types.contains('C/C') ? 'checked' : '';
    final isCE = types.contains('C/E') ? 'checked' : '';
    
    final eTick = isE.isNotEmpty ? '&#10003;' : '';
    final cTick = isC.isNotEmpty ? '&#10003;' : '';
    final eeTick = isEE.isNotEmpty ? '&#10003;' : '';
    final ccTick = isCC.isNotEmpty ? '&#10003;' : '';
    final ceTick = isCE.isNotEmpty ? '&#10003;' : '';

    return '''
<table class="corrugation-item-table" style="width: 100%; border: 1.5px solid #000; border-collapse: collapse; margin-bottom: 8px;">
  <tbody>
    <!-- Header Title Bar -->
    <tr>
      <td colspan="3" style="background-color: #000000; color: #ffffff; text-align: center; font-weight: bold; font-size: 8.5px; padding: 2.5px;">$title</td>
    </tr>
    <!-- Row 1: Corrugation Type -->
    <tr>
      <!-- Column 1: Labels -->
      <td class="bold" style="width: 12%; text-align: center; border: 1px solid #000; padding: 3px; font-size: 8.5px; background-color: var(--bg-header);">التضليع</td>
      <!-- Column 2: Checkboxes and other -->
      <td colspan="2" style="width: 88%; border: 1px solid #000; padding: 3px 6px; font-size: 8px; text-align: right;">
        <div style="display: inline-flex; align-items: center; gap: 8px; direction: rtl;">
          <span style="font-weight: bold;">( ${_esc(custom)} )</span>
          <span class="inline-group"><span class="checkbox-box $isCE" style="${isCE.isNotEmpty ? 'background:#000;color:#fff;text-align:center;line-height:8px;font-size:8px;' : ''}">$ceTick</span> C/E</span>
          <span class="inline-group"><span class="checkbox-box $isCC" style="${isCC.isNotEmpty ? 'background:#000;color:#fff;text-align:center;line-height:8px;font-size:8px;' : ''}">$ccTick</span> C/C</span>
          <span class="inline-group"><span class="checkbox-box $isEE" style="${isEE.isNotEmpty ? 'background:#000;color:#fff;text-align:center;line-height:8px;font-size:8px;' : ''}">$eeTick</span> E/E</span>
          <span class="inline-group"><span class="checkbox-box $isC" style="${isC.isNotEmpty ? 'background:#000;color:#fff;text-align:center;line-height:8px;font-size:8px;' : ''}">$cTick</span> C</span>
          <span class="inline-group"><span class="checkbox-box $isE" style="${isE.isNotEmpty ? 'background:#000;color:#fff;text-align:center;line-height:8px;font-size:8px;' : ''}">$eTick</span> E</span>
        </div>
      </td>
    </tr>
    <!-- Row 2: Samples & Signature -->
    <tr>
      <td class="bold" style="text-align: center; border: 1px solid #000; padding: 3px; font-size: 8.5px; background-color: var(--bg-header);">عينات</td>
      <td style="border: 1px solid #000; padding: 3px 6px; font-size: 8px; text-align: right; width: 63%;">
        <span class="dotted-line" style="width: 90%;">${_esc(samples)}</span>
      </td>
      <!-- Signature cell spanning Rows 2, 3, 4 -->
      <td rowspan="3" style="width: 25%; border: 1px solid #000; text-align: center; vertical-align: middle; padding: 4px; font-size: 8px; background: #fff;">
        <div class="bold" style="margin-bottom: 4px;">توقيع فني التضليع والتاريخ</div>
        <div class="dotted-line" style="width: 90%; height: 35px; border-bottom: none;"></div>
      </td>
    </tr>
    <!-- Row 3: Box Size -->
    <tr>
      <td class="bold" style="text-align: center; border: 1px solid #000; padding: 3px; font-size: 8.5px; background-color: var(--bg-header);">مقاس العلبة</td>
      <td style="border: 1px solid #000; padding: 3px 6px; font-size: 8.5px; text-align: center; font-weight: bold;">
        ${_esc(boxSize)}
      </td>
    </tr>
    <!-- Row 4: Sheet Size -->
    <tr>
      <td class="bold" style="text-align: center; border: 1px solid #000; padding: 3px; font-size: 8.5px; background-color: var(--bg-header);">مقاس الشريحة</td>
      <td style="border: 1px solid #000; padding: 3px 6px; font-size: 8.5px; text-align: center; font-weight: bold;">
        <div style="display: flex; justify-content: center; align-items: center; gap: 15px; direction: rtl;">
          <span>${_esc(sheetSize)}</span>
          <span>( عدد الشرائح: ${_esc(sheetCount)} )</span>
        </div>
      </td>
    </tr>
  </tbody>
</table>
''';
  }

  /// تحويل أحرف HTML الخاصة لمنع XSS في الحقول المُدخلة
  static String _esc(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
