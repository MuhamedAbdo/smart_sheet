// lib/widgets/production_report_list.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/utils/pdf_export_helper.dart';

class ProductionReportList extends StatelessWidget {
  final Box box;
  final void Function(dynamic, Map<String, dynamic>) onEdit;
  final void Function(dynamic) onDelete;

  const ProductionReportList({
    super.key,
    required this.box,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) {
          return const Center(child: Text("🚫 لا يوجد تقارير"));
        }

        final records = box.toMap().entries.map((entry) {
          final key = entry.key;
          final data = entry.value;
          return MapEntry(key, _convertToTypedMap(data));
        }).toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a.value['date']?.toString() ?? '') ??
                DateTime(1970);
            final db = DateTime.tryParse(b.value['date']?.toString() ?? '') ??
                DateTime(1970);
            return db.compareTo(da);
          });

        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final entry = records[index];
            final key = entry.key;
            final record = entry.value;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description,
                            color: Colors.blue, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "📅 ${record['date']}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow("👤 العميل:",
                        record['clientName']?.toString() ?? 'غير محدد'),
                    _buildInfoRow("📦 الصنف:",
                        record['product']?.toString() ?? 'غير محدد'),
                    
                    if (record['productCode'] != null &&
                        record['productCode'].toString().isNotEmpty)
                      _buildInfoRow(
                          "🔢 كود الصنف:", record['productCode'].toString()),
                    
                    if (record['orderNumber'] != null &&
                        record['orderNumber'].toString().isNotEmpty)
                      _buildInfoRow("🔢 رقم أمر التشغيل:", record['orderNumber'].toString()),
                    
                    if ((record['startTime'] != null && record['startTime'].toString().isNotEmpty) || 
                        (record['endTime'] != null && record['endTime'].toString().isNotEmpty))
                      _buildInfoRow("🕒 وقت التشغيل:", "${record['startTime'] ?? '--:--'} إلى ${record['endTime'] ?? '--:--'}"),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("📏 المقاسات: ",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: _buildDimensionsText(record['dimensions'])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("🔢 عدد الشيتات: ${record['quantity'] ?? 0}"),
                    const SizedBox(height: 8),
                    _buildColorsList(record['colors'] ?? []),
                    
                    if (record['lineWaste'] != null || record['printWaste'] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Text("📉 الهالك: ", style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(child: Text("إنتاج: ${record['lineWaste'] ?? 0} | طباعة: ${record['printWaste'] ?? 0}")),
                          ],
                        ),
                      ),
                    
                    if ((record['downtimeStart'] != null && record['downtimeStart'].toString().isNotEmpty) || 
                        (record['downtimeEnd'] != null && record['downtimeEnd'].toString().isNotEmpty))
                      _buildInfoRow("⏱️ وقت الأعطال:", "${record['downtimeStart'] ?? '--:--'} إلى ${record['downtimeEnd'] ?? '--:--'}"),

                    const SizedBox(height: 8),
                    _buildNotesText(record['notes']),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                exportReportToPdf(context, record, []),
                            icon: const Icon(Icons.picture_as_pdf,
                                size: 18, color: Colors.green),
                            label: const Text('تصدير PDF',
                                style: TextStyle(color: Colors.green)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                onEdit(key, _convertValuesToString(record)),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('تعديل'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => onDelete(key),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('حذف'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDimensionsText(dynamic dimensions) {
    if (dimensions is! Map) return const Text("غير محدد");
    return Text(
        "${dimensions['length']}/${dimensions['width']}/${dimensions['height']}");
  }

  Widget _buildColorsList(List<dynamic> colors) {
    if (colors.isEmpty) return const Text("🎨 لا توجد ألوان");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("🎨 الألوان:",
            style: TextStyle(fontWeight: FontWeight.bold)),
        ...colors.map((c) => Text(" • ${c['color']} - ${c['quantity']} لتر")),
      ],
    );
  }

  Widget _buildNotesText(dynamic notes) {
    if (notes == null || notes.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Text("📝 ملاحظات: $notes");
  }

  Map<String, dynamic> _convertToTypedMap(dynamic data) {
    if (data is! Map) return {};
    return Map<String, dynamic>.from(data);
  }

  Map<String, dynamic> _convertValuesToString(Map<String, dynamic> data) {
    return data
        .map((k, v) => MapEntry(k, v is Map || v is List ? v : v.toString()));
  }
}
