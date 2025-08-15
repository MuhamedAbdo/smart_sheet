// lib/src/screens/flexo/ink_report_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/ink_report_form.dart';

class InkReportScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const InkReportScreen({super.key, this.initialData});

  @override
  State<InkReportScreen> createState() => _InkReportScreenState();
}

class _InkReportScreenState extends State<InkReportScreen> {
  late Box _inkReportBox;

  @override
  void initState() {
    super.initState();
    _inkReportBox = Hive.box('inkReports');

    // ✅ إذا وُجد initialData، افتح الـ dialog فورًا بعد رسم الشاشة
    if (widget.initialData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddReportDialog(widget.initialData);
      });
    }
  }

  void _showAddReportDialog([Map<String, dynamic>? prefillData]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return InkReportForm(
          initialData: prefillData,
          onSave: (report) {
            _inkReportBox.add(report);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ تم إضافة التقرير")),
              );
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("📄 تقارير الأحبار"),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: _inkReportBox.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("🚫 لا يوجد تقارير"));
          }

          final List<MapEntry<dynamic, Map<String, dynamic>>> records =
              box.toMap().entries.map((entry) {
            final key = entry.key;
            final data = _convertToTypedMap(entry.value);
            final sanitized = _convertValuesToString(data);
            return MapEntry(key, sanitized);
          }).toList()
                ..sort((a, b) {
                  DateTime parseDate(dynamic value) {
                    if (value is String) {
                      return DateTime.tryParse(value) ?? DateTime(1970);
                    } else if (value is int) {
                      return DateTime.fromMillisecondsSinceEpoch(value);
                    }
                    return DateTime(1970);
                  }

                  final da = parseDate(a.value['date']);
                  final db = parseDate(b.value['date']);
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
                  title: Text("📅 ${record['date'] ?? ''}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("👤 ${record['clientName'] ?? ''}"),
                      Text("📦 ${record['product'] ?? ''}"),
                      Text("📏 ${record['dimensions'] ?? ''}"),
                      if (record['colors'] is List)
                        ...record['colors'].map<Widget>((c) {
                          final color = c['color'] ?? '';
                          var quantity = (c['quantity'] ?? '').toString();
                          if (quantity.startsWith('.')) {
                            quantity = '0$quantity';
                          }
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
                        onPressed: () {
                          final sanitizedRecord =
                              _convertValuesToString(record);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) {
                              return InkReportForm(
                                initialData: sanitizedRecord,
                                reportKey: key.toString(),
                                onSave: (updatedReport) {
                                  _inkReportBox.put(key, updatedReport);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("✅ تم تحديث التقرير")),
                                    );
                                    Navigator.pop(context);
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _inkReportBox.delete(key);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("🗑️ تم حذف التقرير")),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReportDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Map<String, dynamic> _convertToTypedMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
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

  Map<String, dynamic> _convertValuesToString(Map<String, dynamic> input) {
    return input.map((k, v) {
      if (v is int || v is double || v == null) {
        return MapEntry(k, v?.toString() ?? '');
      } else if (v is List) {
        return MapEntry(
          k,
          v.map((item) {
            if (item is Map) {
              return _convertValuesToString(
                Map<String, dynamic>.from(item),
              );
            }
            return item?.toString() ?? '';
          }).toList(),
        );
      } else if (v is Map) {
        return MapEntry(
          k,
          _convertValuesToString(Map<String, dynamic>.from(v)),
        );
      }
      return MapEntry(k, v.toString());
    });
  }
}
