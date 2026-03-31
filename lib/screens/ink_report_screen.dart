// lib/src/widgets/flexo/ink_report_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/ink_report_form.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import '../../../utils/pdf_export_helper.dart';

class InkReportScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const InkReportScreen({super.key, this.initialData});

  @override
  State<InkReportScreen> createState() => _InkReportScreenState();
}

class _InkReportScreenState extends State<InkReportScreen> {
  Box? _inkReportBox;
  bool _isBoxLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _openBoxSafe();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  Future<void> _openBoxSafe() async {
    try {
      if (!Hive.isBoxOpen('inkReports')) await Hive.openBox('inkReports');
      if (mounted) {
        setState(() {
          _inkReportBox = Hive.box('inkReports');
          _isBoxLoading = false;
        });

        if (widget.initialData != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAddReportDialog(widget.initialData);
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isBoxLoading = false);
    }
  }

  Future<void> _savePdfToDeviceLocally(
      List<Map<String, dynamic>> records) async {
    try {
      if (records.isEmpty) return;
      final Uint8List? pdfBytes = await generateInkReportPdfBytes(records);
      if (pdfBytes == null) return;

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ ملف PDF',
        fileName: 'تقرير_أحبار_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (outputFile != null && mounted) {
        UIUtils.showInfoSnackBar(
          message: "تم حفظ الملف بنجاح",
          backgroundColor: Colors.green,
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      debugPrint("Error saving: $e");
    }
  }

  void _deleteAllReports() {
    if (_inkReportBox == null || _inkReportBox!.isEmpty) return;
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "⚠️ تحذير: مسح شامل",
      content: "هل أنت متأكد من حذف جميع التقارير نهائياً؟",
      onConfirm: () async {
        final messenger = ScaffoldMessenger.of(context);
        final Map<dynamic, dynamic> backup = Map.from(_inkReportBox!.toMap());
        await _inkReportBox!.clear();
        if (mounted) {
          messenger.clearSnackBars();
          UIUtils.showUndoSnackBar(
            message: "تم مسح جميع التقارير",
            onUndo: () async {
              messenger.clearSnackBars();
              for (var entry in backup.entries) {
                await _inkReportBox!.put(entry.key, entry.value);
              }
            },
          );
          Future.delayed(const Duration(milliseconds: 5500), () {
            try {
              messenger.clearSnackBars();
            } catch (_) {}
          });
        }
      },
    );
  }

  void _deleteSingleReport(dynamic key, dynamic record) {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "تأكيد الحذف",
      content: "هل تريد حذف هذا التقرير؟",
      onConfirm: () async {
        final messenger = ScaffoldMessenger.of(context);
        await _inkReportBox!.delete(key);
        if (mounted) {
          messenger.clearSnackBars();
          UIUtils.showUndoSnackBar(
            message: "تم حذف التقرير",
            onUndo: () async {
              messenger.clearSnackBars();
              await _inkReportBox!.put(key, record);
            },
          );
          Future.delayed(const Duration(milliseconds: 5500), () {
            try {
              messenger.clearSnackBars();
            } catch (_) {}
          });
        }
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isBoxLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color appBarIconColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        iconTheme: IconThemeData(color: appBarIconColor),
        title: _buildSearchField(context, isDark),
        actions: [
          IconButton(
              icon: Icon(Icons.delete_sweep, color: appBarIconColor),
              tooltip: "مسح شامل",
              onPressed: _deleteAllReports),
          _buildExportMenu(appBarIconColor),
          IconButton(
              icon: Icon(Icons.sort, color: appBarIconColor),
              onPressed: _showSortSheet),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _inkReportBox!.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("🚫 لا يوجد تقارير"));
          }
          final allRecords =
              _filterAndSortRecords(box, _searchQuery, _sortDescending);
          return ListView.builder(
            itemCount: allRecords.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) =>
                _buildReportCard(allRecords[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReportDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExportMenu(Color iconColor) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor),
      onSelected: (value) async {
        final filtered = _filterAndSortRecords(
            _inkReportBox!, _searchQuery, _sortDescending);
        final records = filtered.map((e) => e.value).toList();
        if (value == 'export') await exportReportsToPdf(context, records);
        if (value == 'save') await _savePdfToDeviceLocally(records);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
            value: 'export',
            child: Row(children: [
              Icon(Icons.share, size: 18),
              SizedBox(width: 8),
              Text('تصدير ومشاركة PDF')
            ])),
        const PopupMenuItem(
            value: 'save',
            child: Row(children: [
              Icon(Icons.save_alt, size: 18),
              SizedBox(width: 8),
              Text('حفظ في الذاكرة (يدوي)')
            ])),
      ],
    );
  }

  Widget _buildReportCard(MapEntry<dynamic, Map<String, dynamic>> entry) {
    final key = entry.key;
    final record = entry.value;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("📅 ${record['date'] ?? ''}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue)),
                const Icon(Icons.receipt_long, color: Colors.grey, size: 18),
              ],
            ),
            const Divider(),
            _buildInfoRow(
                "👤 العميل:", record['clientName']?.toString() ?? '---'),
            _buildInfoRow("📦 الصنف:", record['product']?.toString() ?? '---'),
            _buildDimensionsText(
                record['dimensions']), // تم تعديل طريقة العرض هنا
            _buildQuantityText(record['quantity']),
            _buildColorsList(record['colors'] ?? []),
            _buildNotesText(record['notes']),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => _editReport(key, record),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("تعديل"))),
                const SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white),
                  onPressed: () => _deleteSingleReport(key, record),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text("حذف"),
                )),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, bool isDark) {
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color hintColor = isDark ? Colors.white70 : Colors.black54;
    final Color containerColor =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
    return Container(
      height: 40,
      decoration: BoxDecoration(
          color: containerColor, borderRadius: BorderRadius.circular(10)),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'بحث باسم العميل أو الصنف...',
          hintStyle: TextStyle(color: hintColor, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: hintColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // ✅ التعديل الأول: ترتيب زمني فقط (الأحدث أولاً أو العكس) دون ترتيب أبجدي
  List<MapEntry<dynamic, Map<String, dynamic>>> _filterAndSortRecords(
      Box box, String query, bool descending) {
    final entries = box
        .toMap()
        .entries
        .where((e) {
          final r = e.value;
          final q = query.toLowerCase();
          return (r['clientName']?.toString() ?? '')
                  .toLowerCase()
                  .contains(q) ||
              (r['product']?.toString() ?? '').toLowerCase().contains(q);
        })
        .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value)))
        .toList();

    entries.sort((a, b) {
      // نعتمد على الـ key الخاص بـ Hive لأنه تزايدي تلقائياً مع كل إضافة
      return descending ? b.key.compareTo(a.key) : a.key.compareTo(b.key);
    });

    return entries;
  }

  Widget _buildInfoRow(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(l, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(v)
        ]),
      );

  // ✅ التعديل الثاني: عرض المقاسات بشكل صحيح (طول × عرض × ارتفاع) بجانب النص العربي
  Widget _buildDimensionsText(Map<dynamic, dynamic>? d) {
    final String length = d?['length']?.toString() ?? '0';
    final String width = d?['width']?.toString() ?? '0';
    final String height = d?['height']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Text("📏 المقاس: ",
              style: TextStyle(fontWeight: FontWeight.bold)),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text("$length / $width / $height",
                style: const TextStyle(color: Colors.blueGrey)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityText(q) => Text("🔢 الكمية: ${q ?? 0}");
  Widget _buildColorsList(List c) => c.isEmpty
      ? const SizedBox()
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("🎨 الألوان:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          ...c.map((i) => Text(" • ${i['color']} (${i['quantity']} لتر)"))
        ]);
  Widget _buildNotesText(n) => (n == null || n == '')
      ? const SizedBox()
      : Text("📝 ملاحظة: $n",
          style:
              const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));

  void _showAddReportDialog([Map<String, dynamic>? data]) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (c) => InkReportForm(
            initialData: data,
            onSave: (r) {
              _inkReportBox!.add(r);
              Navigator.pop(c);
            }));
  }

  void _editReport(key, record) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (c) => InkReportForm(
            initialData: record,
            reportKey: key.toString(),
            onSave: (r) {
              _inkReportBox!.put(key, r);
              Navigator.pop(c);
            }));
  }

  void _showSortSheet() {
    showModalBottomSheet(
        context: context,
        builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  title: const Text("الأحدث أولاً"),
                  // ignore: deprecated_member_use
                  leading: Radio(
                      value: true,
                      // ignore: deprecated_member_use
                      groupValue: _sortDescending,
                      // ignore: deprecated_member_use
                      onChanged: (v) {
                        setState(() => _sortDescending = v!);
                        Navigator.pop(c);
                      })),
              ListTile(
                  title: const Text("الأقدم أولاً"),
                  // ignore: deprecated_member_use
                  leading: Radio(
                      value: false,
                      // ignore: deprecated_member_use
                      groupValue: _sortDescending,
                      // ignore: deprecated_member_use
                      onChanged: (v) {
                        setState(() => _sortDescending = v!);
                        Navigator.pop(c);
                      })),
            ]));
  }
}
