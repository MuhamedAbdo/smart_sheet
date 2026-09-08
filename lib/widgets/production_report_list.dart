// lib/widgets/production_report_list.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/utils/pdf_export_helper.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/models/flexo_production_report.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';

class FlexoProductionReportList extends StatelessWidget {
  final Box box;
  final void Function(dynamic, Map<String, dynamic>) onEdit;
  final void Function(dynamic) onDelete;

  const FlexoProductionReportList({
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
                        if (record['status'] == 'pending')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'قيد المراجعة',
                              style: TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold),
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
                        _buildDimensionsText(record['dimensions']),
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
                            Text("إنتاج: ${record['lineWaste'] ?? 0} | طباعة: ${record['printWaste'] ?? 0}"),
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
                            onPressed: () {
                              if (record['status']?.toString() == 'pending') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '⚠️ لا يمكن تصدير تقرير قيد المراجعة. يجب اعتماده أولاً.',
                                      style: TextStyle(fontFamily: 'Cairo'),
                                    ),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                                return;
                              }
                              exportReportToPdf(context, record, []);
                            },
                            icon: const Icon(Icons.picture_as_pdf,
                                size: 18, color: Colors.green),
                            label: const Text('تصدير PDF',
                                style: TextStyle(color: Colors.green)),
                          ),
                        ),
                        if (record['status'] == 'pending' && PermissionHelper.canApproveReports)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _approveReport(key, record);
                              },
                              icon: const Icon(Icons.check_circle, size: 18, color: Colors.orange),
                              label: const Text('اعتماد', style: TextStyle(color: Colors.orange)),
                            ),
                          ),
                        IconButton(
                          onPressed: () =>
                              onEdit(key, _convertValuesToString(record)),
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'تعديل',
                        ),
                        IconButton(
                          onPressed: () => onDelete(key),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'حذف',
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

  void _approveReport(dynamic key, Map<String, dynamic> record) {
    // الحصول على السجل الأصلي من Hive لتحديثه
    final originalRecord = box.get(key);
    if (originalRecord != null) {
      if (originalRecord is FlexoProductionReport) {
        final updated = originalRecord.copyWith(status: 'approved');
        box.put(key, updated);
        // إرسال snake_case فقط لتجنب خطأ الأعمدة
        SyncService.instance.pushToQueue('flexo_production_reports', {
          'id': updated.id,
          'sync_id': updated.id,
          'status': 'approved',
        });
      } else if (originalRecord is DieCuttingProductionReport) {
        final updated = originalRecord.copyWith(status: 'approved');
        box.put(key, updated);
        SyncService.instance.pushToQueue('die_cutting_production_reports', {
          'id': updated.id,
          'sync_id': updated.id,
          'status': 'approved',
        });
      } else if (originalRecord is Map) {
        originalRecord['status'] = 'approved';
        box.put(key, originalRecord);
        final syncId = originalRecord['sync_id']?.toString() ?? originalRecord['id']?.toString();
        if (syncId != null) {
          SyncService.instance.pushToQueue('flexo_production_reports', {
            'id': syncId,
            'sync_id': syncId,
            'status': 'approved',
          });
        }
      }
    }
  }
}

