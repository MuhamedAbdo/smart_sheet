// lib/src/widgets/flexo/ink_report_list.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/utils/pdf_export_helper.dart';

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
                    if (productCode != null &&
                        productCode.toString().isNotEmpty)
                      _buildInfoRow("🔢 كود الصنف:", productCode.toString()),
                    const SizedBox(height: 8),
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
                    _buildQuantityText(quantity),
                    const SizedBox(height: 8),
                    _buildColorsList(colors),
                    const SizedBox(height: 8),
                    _buildNotesText(notes),
                    const SizedBox(height: 8),

                    // ✅ تم تعديل دالة الصور هنا
                    _buildImagesList(images, context),

                    const SizedBox(height: 12),
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
                                  exportReportToPdf(context, record, images),
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

  Widget _buildDimensionsText(dynamic dimensions) {
    if (dimensions is! Map) return const Text("غير محدد");
    final length = dimensions['length']?.toString() ?? '';
    final width = dimensions['width']?.toString() ?? '';
    final height = dimensions['height']?.toString() ?? '';

    String formatNumber(String value) {
      if (value.contains('.')) {
        final parts = value.split('.');
        if (parts.length > 1 && parts[1] == '0') return parts[0];
        return value
            .replaceAll(RegExp(r'0*$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }
      return value;
    }

    return Text(
        "${formatNumber(length)}/${formatNumber(width)}/${formatNumber(height)}");
  }

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
          if (quantity.startsWith('.')) quantity = '0$quantity';
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text("• $color - $quantity لتر"),
          );
        }),
      ],
    );
  }

  Widget _buildQuantityText(dynamic quantity) {
    final qty = quantity?.toString() ?? '0';
    return Text("🔢 عدد الشيتات: $qty");
  }

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

  // ✅ التعديل الجوهري لعرض الصور (سحابية + محلية)
  Widget _buildImagesList(List<String> images, BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    // نقوم بفلترة الروابط: إما رابط إنترنت أو ملف موجود فعلياً على الجهاز
    final validImages = images.where((path) {
      if (path.startsWith('http')) {
        return true; // روابط السحاب دائماً صالحة للعرض
      }
      return File(path).existsSync(); // الملفات المحلية يجب التأكد من وجودها
    }).toList();

    if (validImages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("📸 الصور المرفقة:",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 70, // زيادة الارتفاع قليلاً للوضوح
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: validImages.length,
            itemBuilder: (context, i) {
              final path = validImages[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: path.startsWith('http')
                      ? Image.network(
                          path,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          // إضافة مؤشر تحميل للصور السحابية
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, error, stack) => const Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey),
                        )
                      : Image.file(
                          File(path),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

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
