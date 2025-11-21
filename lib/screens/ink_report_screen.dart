// lib/src/screens/flexo/ink_report_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/ink_report_form.dart';
import 'package:smart_sheet/widgets/full_screen_image_page.dart';

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
  bool _sortDescending = true;
  bool _onlyWithImages = false;

  @override
  void initState() {
    super.initState();
    _inkReportBox = Hive.box('inkReports');

    if (widget.initialData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddReportDialog(widget.initialData);
      });
    }

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

  void _showFullScreenImage(List<String> imagePaths, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(
          images: imagePaths.map((path) => File(path)).toList(),
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // ✅ دالة لعرض المقاسات بالتنسيق المطلوب
  Widget _buildDimensionsText(dynamic dimensions) {
    if (dimensions is! Map) return const Text("📏 غير محدد");

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

    return Text("📏 $formattedLength/$formattedWidth/$formattedHeight");
  }

  // ✅ دالة لعرض الألوان والكميات
  Widget _buildColorsList(List<dynamic> colors) {
    if (colors.isEmpty) return const Text("🎨 لا توجد ألوان");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: colors.map<Widget>((c) {
        final color = c['color'] ?? '';
        var quantity = (c['quantity'] ?? '').toString();
        if (quantity.startsWith('.')) {
          quantity = '0$quantity';
        }
        return Text("🎨 $color - $quantity لتر");
      }).toList(),
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
        Text(notes.toString()),
      ],
    );
  }

  // ✅ دالة لعرض الصور
  Widget _buildImagesList(List<String> images) {
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
              child: GestureDetector(
                onTap: () => _showFullScreenImage(images, i),
                child: Image.file(
                  File(images[i]),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

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

  // ✅ تعديل نوع البيانات المُعادة
  List<MapEntry<dynamic, Map<String, dynamic>>> _prepareRecords(Box box) {
    var entries = box.toMap().entries.toList();

    entries.sort((a, b) {
      DateTime parseDate(dynamic value) {
        if (value is String) {
          return DateTime.tryParse(value) ?? DateTime(1970);
        } else if (value is int) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
        return DateTime(1970);
      }

      // ✅ التأكد من أن a.value و b.value من نوع Map قبل الوصول إلى 'date'
      final aValue = a.value;
      final bValue = b.value;
      if (aValue is Map && bValue is Map) {
        final da = parseDate(aValue['date']);
        final db = parseDate(bValue['date']);
        return db.compareTo(da);
      } else {
        return 0; // إذا لم تكن Maps، لا تغيّر الترتيب
      }
    });

    if (!_sortDescending) {
      entries = entries.reversed.toList();
    }

    var filtered = entries;
    if (_onlyWithImages) {
      filtered = filtered.where((e) {
        final value = e.value;
        // ✅ تحقق من أن القيمة عبارة عن Map قبل محاولة الوصول إلى 'imagePaths'
        if (value is Map) {
          final imagePaths = value['imagePaths'];
          // ✅ تحقق من أن imagePaths هو List قبل محاولة الوصول إلى length
          if (imagePaths is List) {
            return imagePaths.isNotEmpty;
          }
        }
        // ✅ إذا لم تكن Map أو imagePaths ليست List، أعد false
        return false;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) {
        final value = e.value;
        if (value is Map<String, dynamic>) {
          // ✅ استخدام _matchesSearch بعد التأكد من النوع
          return _matchesSearch(value, _searchQuery);
        }
        return false; // إذا لم يكن Map<String, dynamic>، لا يطابق البحث
      }).toList();
    }

    // ✅ التحويل الآمن من dynamic إلى Map<String, dynamic>
    return filtered.map((entry) {
      final dynamic key = entry.key;
      final dynamic value = entry.value;
      if (value is Map) {
        // استخدام cast لتحويل Map<dynamic, dynamic> إلى Map<String, dynamic>
        final typedValue = Map<String, dynamic>.from(value);
        return MapEntry(key, typedValue);
      } else {
        // إذا لم يكن Map، أعد مدخلًا فارغًا أو تجاهل
        return MapEntry(key, <String, dynamic>{});
      }
    }).toList();
  }

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
              final dynamic key = entry.key;
              // ✅ الآن، entry.value هو Map<String, dynamic> مضمون
              final Map<String, dynamic> record = entry.value;

              final images = (record['imagePaths'] is List)
                  ? (record['imagePaths'] as List)
                      .map((e) => e.toString())
                      .toList()
                  : <String>[];
              final colors = (record['colors'] is List)
                  ? List<dynamic>.from(record['colors'])
                  : [];
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
                              "📅 ${record['date'] ?? ''}",
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
                              child:
                                  _buildDimensionsText(record['dimensions'])),
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

                      // ✅ الصور
                      _buildImagesList(images),

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
                                onPressed: () {
                                  // ✅ التأكد من أن record هو Map<String, dynamic> قبل التمرير
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      "✅ تم تحديث التقرير")),
                                            );
                                            Navigator.pop(context);
                                          }
                                        },
                                      );
                                    },
                                  );
                                },
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('تعديل'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _inkReportBox.delete(key);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("🗑️ تم حذف التقرير")),
                                  );
                                },
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReportDialog(),
        child: const Icon(Icons.add),
      ),
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
              return _convertValuesToString(Map<String, dynamic>.from(item));
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
