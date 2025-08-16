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

          // تحويل Map<dynamic, dynamic> إلى Map<String, dynamic>
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
                ? List<String>.from(record['imagePaths'])
                : [];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text("📅 ${record['date']}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("👤 ${record['clientName']}"),
                    Text("📦 ${record['product']}"),
                    Text("📏 ${record['dimensions']}"),
                    if (record['colors'] is List)
                      ...record['colors'].map<Widget>((c) {
                        final color = c['color'] ?? '';
                        final quantity = (c['quantity'] ?? 0).toString();
                        return Text("🎨 $color - $quantity لتر");
                      }).toList(),
                    if (images.isNotEmpty)
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          itemBuilder: (context, i) => Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
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
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      // ✅ تحويل القيم إلى نصوص قبل التعديل
                      onPressed: () =>
                          onEdit(key, _convertValuesToString(record)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => onDelete(key),
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

  // تحويل Map<dynamic, dynamic> إلى Map<String, dynamic>
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

  // ✅ دالة لتحويل كل القيم (حتى الأرقام) إلى نصوص
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
