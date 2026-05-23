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

  JobOrderItem({
    required this.productName,
    required this.productCode,
    this.length = '',
    this.width = '',
    this.height = '',
    this.quantity = '',
    this.itemNotes = '',
    this.review = '',
  });
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

  final List<String> selectedTypes;

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
    this.selectedTypes = const [],
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
    html = html.replaceAll(
      '{{item_names_summary}}',
      data.items.map((i) => i.productName).join(' / '),
    );
    html = html.replaceAll(
      '{{item_code_summary}}',
      data.items.map((i) => i.productCode).where((c) => c.isNotEmpty).join(' / '),
    );
    html = html.replaceAll('{{address}}', _safe(data.address));
    html = html.replaceAll('{{supervisor}}', _safe(data.supervisor));
    html = html.replaceAll('{{phone}}', _safe(data.phone));
    html = html.replaceAll('{{start_date}}', _safe(data.startDate));
    html = html.replaceAll('{{delivery_date}}', _safe(data.deliveryDate));
    html = html.replaceAll('{{received_date}}', _safe(data.receivedDate));

    // --- Type checkboxes (R/T/E/C/B)
    html = html.replaceAll('{{type_checkboxes}}', _buildTypeCheckboxes(data.selectedTypes));

    html = html.replaceAll('{{items_table_rows}}', _buildItemsRows(data.items));

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

  /// يبني HTML لصناديق اختيار النوع مع علامة ✓ خضراء للمُختارة
  static const _allTypes = ['R', 'T', 'E', 'C', 'B'];

  static String _buildTypeCheckboxes(List<String> selected) {
    final buffer = StringBuffer();
    for (final type in _allTypes) {
      final isChecked = selected.contains(type);
      if (isChecked) {
        buffer.write(
          '<div class="checkbox-container">'
          '<span class="checkbox-custom" style="background:#22c55e;border-color:#22c55e;'
          'display:inline-flex;align-items:center;justify-content:center;'
          'color:#fff;font-size:8px;font-weight:900;">&#10003;</span> $type'
          '</div>',
        );
      } else {
        buffer.write(
          '<div class="checkbox-container">'
          '<span class="checkbox-custom"></span> $type'
          '</div>',
        );
      }
    }
    return buffer.toString();
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

  /// تحويل أحرف HTML الخاصة لمنع XSS في الحقول المُدخلة
  static String _esc(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
