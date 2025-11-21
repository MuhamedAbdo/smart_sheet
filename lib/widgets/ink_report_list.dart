// lib/src/widgets/flexo/ink_report_list.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class InkReportList extends StatelessWidget {
  final Box box;
  final void Function(dynamic, Map<String, dynamic>) onEdit;
  final void Function(dynamic) onDelete;

  const InkReportList({
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
          final record = _convertToTypedMap(data);
          return MapEntry(key, record);
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

            // ✅ إصلاح تحويل imagePaths إلى List<String>
            final images = (record['imagePaths'] is List)
                ? (record['imagePaths'] as List)
                    .map((e) => e.toString())
                    .toList()
                : <String>[];

            final colors = (record['colors'] is List) ? record['colors'] : [];
            final quantity = record['quantity'];
            final notes = record['notes'];
            final productCode = record['productCode'];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ العنوان والتاريخ
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

                    // ✅ المعلومات الأساسية
                    _buildInfoRow("👤 العميل:",
                        record['clientName']?.toString() ?? 'غير محدد'),
                    _buildInfoRow("📦 الصنف:",
                        record['product']?.toString() ?? 'غير محدد'),
                    if (productCode != null &&
                        productCode.toString().isNotEmpty)
                      _buildInfoRow("🔢 كود الصنف:", productCode.toString()),

                    const SizedBox(height: 8),

                    // ✅ المقاسات
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("📏 المقاسات:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildDimensionsText(record['dimensions'])),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ✅ عدد الشيتات
                    _buildQuantityText(quantity),

                    const SizedBox(height: 8),

                    // ✅ الألوان
                    _buildColorsList(colors),

                    const SizedBox(height: 8),

                    // ✅ الملاحظات
                    _buildNotesText(notes),

                    const SizedBox(height: 8),

                    // ✅ الصور - تم إصلاح نوع البيانات هنا
                    _buildImagesList(images, context),

                    const SizedBox(height: 12),

                    // ✅ أزرار التحكم
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        children: [
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

  // ✅ دالة لعرض المقاسات بالتنسيق المطلوب
  Widget _buildDimensionsText(dynamic dimensions) {
    if (dimensions is! Map) return const Text("غير محدد");

    final length = dimensions['length']?.toString() ?? '';
    final width = dimensions['width']?.toString() ?? '';
    final height = dimensions['height']?.toString() ?? '';

    String formatNumber(String value) {
      if (value.contains('.')) {
        final parts = value.split('.');
        if (parts[1] == '0') {
          return parts[0];
        }
        return value
            .replaceAll(RegExp(r'0*$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }
      return value;
    }

    final formattedLength = formatNumber(length);
    final formattedWidth = formatNumber(width);
    final formattedHeight = formatNumber(height);

    return Text("$formattedLength/$formattedWidth/$formattedHeight");
  }

  // ✅ دالة لعرض الألوان والكميات
  Widget _buildColorsList(List<dynamic> colors) {
    if (colors.isEmpty) return const Text("🎨 لا توجد ألوان");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("🎨 الألوان:",
            style: TextStyle(fontWeight: FontWeight.bold)),
        ...colors.map<Widget>((c) {
          final color = c['color'] ?? '';
          var quantity = (c['quantity'] ?? '').toString();
          if (quantity.startsWith('.')) {
            quantity = '0$quantity';
          }
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text("• $color - $quantity لتر"),
          );
        }),
      ],
    );
  }

  // ✅ دالة لعرض عدد الشيتات
  Widget _buildQuantityText(dynamic quantity) {
    final qty = quantity?.toString() ?? '0';
    return Text("🔢 عدد الشيتات: $qty");
  }

  // ✅ دالة لعرض الملاحظات
  Widget _buildNotesText(dynamic notes) {
    if (notes == null || notes.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("📝 الملاحظات:",
            style: TextStyle(fontWeight: FontWeight.bold)),
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 4),
          child: Text(notes.toString()),
        ),
      ],
    );
  }

  // ✅ دالة لعرض الصور - تم إصلاح نوع المعامل
  Widget _buildImagesList(List<String> images, BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("📸 الصور المرفقة:",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Image.file(
                File(images[i]),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ دالة مساعدة لعرض صفوف المعلومات
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Map<String, dynamic> _convertToTypedMap(dynamic data) {
    if (data is! Map) return {};
    Map<String, dynamic> result = {};
    data.forEach((key, value) {
      final String stringKey = key.toString();
      if (value is Map) {
        result[stringKey] = _convertToTypedMap(value);
      } else if (value is List) {
        result[stringKey] = value.map((item) {
          if (item is Map) return _convertToTypedMap(item);
          return item;
        }).toList();
      } else {
        result[stringKey] = value;
      }
    });
    return result;
  }

  Map<String, dynamic> _convertValuesToString(Map<String, dynamic> data) {
    return data.map((k, v) {
      if (v is int || v is double) {
        return MapEntry(k, v.toString());
      } else if (v is List) {
        return MapEntry(
            k,
            v.map((item) {
              if (item is Map) {
                return _convertValuesToString(Map<String, dynamic>.from(item));
              }
              if (item is int || item is double) return item.toString();
              return item;
            }).toList());
      } else if (v is Map) {
        return MapEntry(
            k, _convertValuesToString(Map<String, dynamic>.from(v)));
      }
      return MapEntry(k, v);
    });
  }
}
