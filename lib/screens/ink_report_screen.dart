// lib/src/widgets/flexo/ink_report_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/full_screen_image_page.dart';
import 'package:smart_sheet/widgets/ink_report_form.dart';
import '../../../utils/pdf_export_helper.dart';

class InkReportScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const InkReportScreen({super.key, this.initialData});

  @override
  State<InkReportScreen> createState() => _InkReportScreenState();
}

class _InkReportScreenState extends State<InkReportScreen> {
  // تم تغيير النوع إلى nullable للتعامل مع مرحلة ما قبل التحميل
  Box? _inkReportBox;
  bool _isBoxLoading = true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  bool _sortDescending = true;
  bool _onlyWithImages = false;

  @override
  void initState() {
    super.initState();
    _openBoxSafe(); // فتح الصندوق بأمان عند الدخول للشاشة

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  // دالة لضمان فتح الصندوق قبل أي عملية قراءة
  Future<void> _openBoxSafe() async {
    try {
      if (!Hive.isBoxOpen('inkReports')) {
        await Hive.openBox('inkReports');
      }
      if (mounted) {
        setState(() {
          _inkReportBox = Hive.box('inkReports');
          _isBoxLoading = false;
        });

        // تنفيذ إضافة التقرير إذا كان قادماً من شاشة أخرى
        if (widget.initialData != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAddReportDialog(widget.initialData);
          });
        }
      }
    } catch (e) {
      debugPrint("Error opening inkReports box: $e");
      if (mounted) {
        setState(() => _isBoxLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _showAddReportDialog([Map<String, dynamic>? prefillData]) {
    if (_inkReportBox == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return InkReportForm(
          initialData: prefillData,
          onSave: (report) {
            _inkReportBox!.add(report);
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

  // --- دوال المساعدة والبناء (كما هي مع إضافة التحقق من null) ---

  @override
  Widget build(BuildContext context) {
    // 1. حالة التحميل: تمنع خطأ "Box not found"
    if (_isBoxLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. حالة فشل فتح الصندوق (نادرة جداً مع وجود الكود في main)
    if (_inkReportBox == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("خطأ في البيانات")),
        body: const Center(
            child: Text("❌ تعذر الوصول إلى قاعدة بيانات التقارير")),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: _buildSearchField(),
        actions: [
          _buildExportMenu(),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _inkReportBox!.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("🚫 لا يوجد تقارير"));
          }

          final allRecords = _filterAndSortRecords(
              box, _searchQuery, _onlyWithImages, _sortDescending);

          if (allRecords.isEmpty) {
            return Center(
              child: Text(_searchQuery.isNotEmpty
                  ? 'لا توجد نتائج مطابقة لـ "$_searchQuery"'
                  : 'لا توجد تقارير تطابق الفلاتر'),
            );
          }

          return ListView.builder(
            itemCount: allRecords.length,
            itemBuilder: (context, index) {
              final entry = allRecords[index];
              return _buildReportCard(entry);
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

  // --- أجزاء بناء الواجهة المفصلة (لجعل الكود أنظف) ---

  Widget _buildSearchField() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: 'ابحث بالعميل، الصنف، الكود...',
          hintStyle: const TextStyle(color: Colors.white70, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
        ),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildExportMenu() {
    final filtered = _filterAndSortRecords(
        _inkReportBox!, _searchQuery, _onlyWithImages, _sortDescending);
    final recordsForExport = filtered.map((e) => e.value).toList();

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'export') _exportFilteredReports(recordsForExport);
        if (value == 'save') _saveFilteredReports(recordsForExport);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'export', child: Text('تصدير ومشاركة PDF')),
        const PopupMenuItem(value: 'save', child: Text('حفظ في ذاكرة الهاتف')),
      ],
    );
  }

  Widget _buildReportCard(MapEntry<dynamic, Map<String, dynamic>> entry) {
    final key = entry.key;
    final record = entry.value;

    // استخراج البيانات مع التعامل مع الأنواع
    final images = (record['imagePaths'] is List)
        ? List<String>.from(record['imagePaths'])
        : <String>[];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📅 ${record['date'] ?? ''}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blue)),
            const Divider(),
            _buildInfoRow(
                "👤 العميل:", record['clientName']?.toString() ?? 'غير محدد'),
            _buildInfoRow(
                "📦 الصنف:", record['product']?.toString() ?? 'غير محدد'),
            _buildDimensionsText(record['dimensions']),
            _buildQuantityText(record['quantity']),
            _buildColorsList(record['colors'] ?? []),
            _buildNotesText(record['notes']),
            _buildImagesList(images),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editReport(key, record),
                    icon: const Icon(Icons.edit),
                    label: const Text("تعديل"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _confirmDelete(key),
                    icon: const Icon(Icons.delete),
                    label: const Text("حذف"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- دوال العمليات (الحذف والتعديل) ---

  void _editReport(dynamic key, Map<String, dynamic> record) {
    final sanitizedRecord = _convertValuesToString(record);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InkReportForm(
        initialData: sanitizedRecord,
        reportKey: key.toString(),
        onSave: (updatedReport) {
          _inkReportBox!.put(key, updatedReport);
          Navigator.pop(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("✅ تم التحديث")));
        },
      ),
    );
  }

  void _confirmDelete(dynamic key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل تريد حذف هذا التقرير نهائياً؟"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              _inkReportBox!.delete(key);
              Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- منطق الفلترة (تم تحسينه للتعامل مع Supabase Restore) ---

  List<MapEntry<dynamic, Map<String, dynamic>>> _filterAndSortRecords(
      Box box, String searchQuery, bool onlyWithImages, bool sortDescending) {
    final entries = box.toMap().entries.where((entry) {
      final record = entry.value;
      if (record is! Map) return false;

      if (onlyWithImages) {
        final images = record['imagePaths'];
        if (images is! List || images.isEmpty) return false;
      }

      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        final client = (record['clientName']?.toString() ?? '').toLowerCase();
        final product = (record['product']?.toString() ?? '').toLowerCase();
        final code = (record['productCode']?.toString() ?? '').toLowerCase();
        return client.contains(query) ||
            product.contains(query) ||
            code.contains(query);
      }
      return true;
    }).toList();

    entries.sort((a, b) {
      final dtA = DateTime.tryParse(a.value['date']?.toString() ?? '') ??
          DateTime(1970);
      final dtB = DateTime.tryParse(b.value['date']?.toString() ?? '') ??
          DateTime(1970);
      return sortDescending ? dtB.compareTo(dtA) : dtA.compareTo(dtB);
    });

    return entries.map((e) {
      final safeMap = Map<String, dynamic>.from(e.value as Map);
      return MapEntry(e.key, safeMap);
    }).toList();
  }

  // --- باقي الـ Widgets المساعدة (نفس كودك السابق مع تحسينات طفيفة) ---

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
    if (dimensions is! Map) return const Text("📏 المقاسات: غير محدد");
    return Text(
        "📏 المقاسات: ${dimensions['length']}/${dimensions['width']}/${dimensions['height']}");
  }

  Widget _buildQuantityText(dynamic quantity) =>
      Text("🔢 عدد الشيتات: ${quantity ?? 0}");

  Widget _buildColorsList(List<dynamic> colors) {
    if (colors.isEmpty) return const SizedBox.shrink();
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

  Widget _buildImagesList(List<String> images) {
    final validImages =
        images.where((path) => File(path).existsSync()).toList();
    if (validImages.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: validImages.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _showFullScreenImage(validImages, i),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.file(File(validImages[i]),
                width: 60, height: 60, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(List<String> validPaths, int index) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => FullScreenImagePage(
                  images: validPaths.map((p) => File(p)).toList(),
                  initialIndex: index,
                )));
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setST) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text("صور فقط"),
                value: _onlyWithImages,
                onChanged: (v) =>
                    setState(() => setST(() => _onlyWithImages = v)),
              ),
              ListTile(
                title: const Text("الترتيب"),
                trailing: DropdownButton<bool>(
                  value: _sortDescending,
                  items: const [
                    DropdownMenuItem(value: true, child: Text("الأحدث")),
                    DropdownMenuItem(value: false, child: Text("الأقدم")),
                  ],
                  onChanged: (v) =>
                      setState(() => setST(() => _sortDescending = v!)),
                ),
              ),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إغلاق"))
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportFilteredReports(
      List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    await exportReportsToPdf(context, records);
  }

  Future<void> _saveFilteredReports(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    await savePdfToDevice(context, records);
  }

  Map<String, dynamic> _convertValuesToString(Map<String, dynamic> input) {
    return input.map((k, v) {
      if (v is Map) {
        return MapEntry(
            k, _convertValuesToString(Map<String, dynamic>.from(v)));
      }
      if (v is List) {
        return MapEntry(
            k,
            v
                .map((e) => e is Map
                    ? _convertValuesToString(Map<String, dynamic>.from(e))
                    : e.toString())
                .toList());
      }
      return MapEntry(k, v?.toString() ?? '');
    });
  }
}
