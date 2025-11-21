// lib/src/screens/flexo/ink_report_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/ink_report_form.dart';
// ✅ استيراد الـ Widget الجديد لعرض الصور ملء الشاشة
import 'package:smart_sheet/widgets/full_screen_image_page.dart'; // <-- هنا

class InkReportScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const InkReportScreen({super.key, this.initialData});

  @override
  State<InkReportScreen> createState() => _InkReportScreenState();
}

class _InkReportScreenState extends State<InkReportScreen> {
  late Box _inkReportBox;

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  // Filter / Sort
  bool _sortDescending = true; // true => الأحدث (الأعلى)
  bool _onlyWithImages = false;

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

    // ✅ إضافة مستمع للبحث
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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

  // ✅ دالة جديدة لفتح الصور ملء الشاشة
  void _showFullScreenImage(List<String> imagePaths, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(
          images: imagePaths
              .map((path) => File(path))
              .toList(), // تحويل المسارات إلى ملفات
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // --- دالتي الفلترة والبحث ---
  bool _matchesSearch(Map<String, dynamic> report, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    final client = (report['clientName'] ?? '').toString().toLowerCase();
    final product = (report['product'] ?? '').toString().toLowerCase();
    final code = (report['productCode'] ?? '').toString().toLowerCase();
    return client.contains(lower) ||
        product.contains(lower) ||
        code.contains(lower);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        bool tempOnlyWithImages = _onlyWithImages;
        bool tempSortDescending = _sortDescending;
        return StatefulBuilder(builder: (context, setStateSB) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('خيارات الفلترة والترتيب',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('اتجاه الترتيب:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<bool>(
                        value: tempSortDescending,
                        items: const [
                          DropdownMenuItem(
                              value: true, child: Text('الأحدث أولاً')),
                          DropdownMenuItem(
                              value: false, child: Text('الأقدم أولاً')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setStateSB(() => tempSortDescending = v);
                        },
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: tempOnlyWithImages,
                  onChanged: (v) {
                    setStateSB(() => tempOnlyWithImages = v ?? false);
                  },
                  title: const Text('إظهار التقارير التي تحتوي على صور فقط'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _onlyWithImages = tempOnlyWithImages;
                            _sortDescending = tempSortDescending;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('تطبيق'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );
  }

  List<MapEntry<dynamic, Map<String, dynamic>>> _prepareRecords(Box box) {
    var entries = box.toMap().entries.toList();

    // الترتيب حسب التاريخ (date) الموجود في record
    entries.sort((a, b) {
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
      return db.compareTo(da); // ترتيب تنازلي (الأحدث أولاً)
    });

    // عكس الترتيب إذا كان _sortDescending = false (الأقدم أولاً)
    if (!_sortDescending) {
      entries = entries.reversed.toList();
    }

    var filtered = entries;
    if (_onlyWithImages) {
      filtered = filtered
          .where((e) =>
              (e.value as Map)['imagePaths']?.length ??
              0 > 0) // ✅ casting إلى Map
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((e) => _matchesSearch(e.value as Map<String, dynamic>,
              _searchQuery)) // ✅ casting إلى Map<String, dynamic>
          .toList();
    }

    return filtered
        .map(
            (entry) => MapEntry(entry.key, entry.value as Map<String, dynamic>))
        .toList(); // ✅ casting النهائي للقائمة
  }
  // ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              setState(() {
                _searchQuery = _searchController.text.trim();
              });
              _searchFocus.unfocus();
            },
            decoration: InputDecoration(
              hintText: 'ابحث بكود الصنف، الصنف أو اسم العميل',
              hintStyle: const TextStyle(color: Colors.white70),
              filled: false,
              prefixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _searchQuery = _searchController.text.trim();
                  });
                  _searchFocus.unfocus();
                },
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _inkReportBox.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("🚫 لا يوجد تقارير"));
          }

          final prepared = _prepareRecords(box);

          if (prepared.isEmpty) {
            return Center(
              child: Text(_searchQuery.isNotEmpty
                  ? 'لا توجد نتائج مطابقة لـ "$_searchQuery"'
                  : 'لا توجد تقارير تطابق الفلاتر'),
            );
          }

          return ListView.builder(
            itemCount: prepared.length,
            itemBuilder: (context, index) {
              final entry = prepared[index];
              final key = entry.key;
              final record =
                  entry.value; // ✅ الآن record هو Map<String, dynamic>
              // ✅ تعديل كيفية تحويل imagePaths إلى List<String>
              final images = (record['imagePaths'] is List)
                  ? (record['imagePaths'] as List)
                      .map((e) => e.toString())
                      .toList() // <-- تم التعديل هنا
                  : <String>[];

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
                              child: GestureDetector(
                                // ✅ إضافة GestureDetector
                                onTap: () => _showFullScreenImage(images,
                                    i), // ✅ استدعاء الدالة الجديدة عند النقر
                                child: Image.file(
                                  File(images[i]), // ✅ تحويل المسار إلى ملف
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
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
