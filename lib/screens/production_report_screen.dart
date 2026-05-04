// lib/screens/production_report_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:smart_sheet/screens/flexo_archive_screen.dart';
import 'package:smart_sheet/widgets/production_report_form.dart';
import 'package:smart_sheet/widgets/start_session_dialog.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/widgets/active_sessions_dashboard.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import '../../../utils/pdf_export_helper.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'dart:async';
class ProductionReportScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const ProductionReportScreen({super.key, this.initialData});

  @override
  State<ProductionReportScreen> createState() => _ProductionReportScreenState();
}

class _ProductionReportScreenState extends State<ProductionReportScreen> {
  Box? _productionReportBox;
  bool _isBoxLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  String? _selectedDate;
  bool _sortDescending = true;
  StreamSubscription? _supabaseSubscription;

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
          _productionReportBox = Hive.box('inkReports');
          _isBoxLoading = false;
        });

        _setupSupabaseStream();

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

  Future<void> _setupSupabaseStream() async {
    final stream = await SupabaseManager.streamData('production_reports', primaryKey: ['id']);
    if (stream != null) {
      _supabaseSubscription = stream.listen((data) async {
        if (_productionReportBox == null) return;
        
        final existingRecords = _productionReportBox!.toMap();
        for (var record in data) {
           final recordId = record['id']?.toString();
           if (recordId == null) continue;
           
           dynamic existingKey;
           for (var entry in existingRecords.entries) {
             if (entry.value is Map && entry.value['id']?.toString() == recordId) {
               existingKey = entry.key;
               break;
             }
           }
           
           if (existingKey == null) {
             await _productionReportBox!.add(record);
           } else {
             await _productionReportBox!.put(existingKey, record);
           }
        }
      });
    }
  }

  @override
  void dispose() {
    _supabaseSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _savePdfToDeviceLocally(
      List<Map<String, dynamic>> records, {required bool isPrinting}) async {
    try {
      if (records.isEmpty) return;
      final Uint8List? pdfBytes = isPrinting
          ? await generatePrintingReportPdfBytes(records)
          : await generateProductionReportPdfBytes(records);
          
      if (pdfBytes == null) return;

      String prefix = isPrinting ? 'تقرير_طباعة' : 'تقرير_إنتاج';

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ ملف PDF',
        fileName: '${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf',
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

  void _deleteSingleReport(dynamic key, dynamic record) {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "تأكيد الحذف",
      content: "هل تريد حذف هذا التقرير؟",
      onConfirm: () async {
        final messenger = ScaffoldMessenger.of(context);
        await _productionReportBox!.delete(key);
        if (mounted) {
          messenger.clearSnackBars();
          UIUtils.showUndoSnackBar(
            context: context,
            message: "تم حذف التقرير",
            onUndo: () async {
              messenger.clearSnackBars();
              await _productionReportBox!.put(key, record);
            },
          );
        }
      },
    );
  }

  void _deleteAllReports() {
    if (_productionReportBox == null || _productionReportBox!.isEmpty) return;
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "⚠️ تحذير: مسح شامل",
      content: "هل أنت متأكد من حذف جميع التقارير نهائياً؟",
      onConfirm: () async {
        final messenger = ScaffoldMessenger.of(context);
        final Map<dynamic, dynamic> backup =
            Map.from(_productionReportBox!.toMap());
        await _productionReportBox!.clear();
        if (mounted) {
          messenger.clearSnackBars();
          UIUtils.showUndoSnackBar(
            context: context,
            message: "تم مسح جميع التقارير",
            onUndo: () async {
              messenger.clearSnackBars();
              for (var entry in backup.entries) {
                await _productionReportBox!.put(entry.key, entry.value);
              }
            },
          );
        }
      },
    );
  }

  // ✅ ميزة الأرشفة الشاملة (نسخ فقط مع بقاء الأصل)
  void _moveToArchive() {
    if (_productionReportBox == null || _productionReportBox!.isEmpty) return;

    UIUtils.showDeleteConfirmation(
      context: context,
      title: "نقل التقارير للأرشيف",
      content:
          "سيتم عمل نسخة من التقارير الحالية في الأرشيف مع بقائها هنا. هل تريد الاستمرار؟",
      confirmLabel: "نقل للأرشيف",
      confirmColor: Colors.blueAccent,
      onConfirm: () async {
        try {
          final archiveBox = await Hive.openBox('flexoArchive');
          final allReports = _productionReportBox!.toMap();

          for (var entry in allReports.entries) {
            final archiveEntry = {
              'type': 'REPORT',
              'data': Map<String, dynamic>.from(entry.value),
              'archiveDate': DateTime.now().toString().split('.')[0],
            };
            await archiveBox.add(archiveEntry);
          }

          if (mounted) {
            UIUtils.showInfoSnackBar(
              message:
                  "تم نقل التقارير للأرشيف بنجاح. يمكنك الآن مسحها يدوياً من هذه الصفحة إذا أردت.",
              backgroundColor: Colors.blueAccent,
              icon: Icons.inventory_2,
            );
          }
        } catch (e) {
          debugPrint("Archive Error: $e");
          if (mounted) {
            UIUtils.showInfoSnackBar(
              message: "فشل نسخ البيانات للأرشيف",
              backgroundColor: Colors.red,
            );
          }
        }
      },
    );
  }

  // ✅ توحيد صيغة التاريخ وتجاهل الوقت (YYYY-MM-DD)
  String _normalizeDateOnly(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == "---") return "";
    try {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      }
    } catch (_) {}
    return dateStr.split(' ')[0].split('T')[0];
  }

  List<String> _getUniqueDates() {
    if (_productionReportBox == null) return [];
    final Set<String> dates = {};
    for (var value in _productionReportBox!.values) {
      final data = Map<String, dynamic>.from(value);
      final rawDate = data['date']?.toString();
      final normalizedDate = _normalizeDateOnly(rawDate);
      if (normalizedDate.isNotEmpty) {
        dates.add(normalizedDate);
      }
    }
    final sortedDates = dates.toList();
    sortedDates.sort((a, b) {
      final dA = DateTime.tryParse(a) ?? DateTime(2000);
      final dB = DateTime.tryParse(b) ?? DateTime(2000);
      return dB.compareTo(dA);
    });
    return sortedDates;
  }

  void _showDateFilterDialog() {
    final uniqueDates = _getUniqueDates();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: const Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.white),
              SizedBox(width: 10),
              Text("اختر تاريخ الإنتاج",
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: Colors.green),
                title: const Text("عرض الكل",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
                onTap: () {
                  setState(() => _selectedDate = null);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              if (uniqueDates.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("لا توجد تواريخ متاحة"))
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: uniqueDates.length,
                    itemBuilder: (ctx, index) {
                      final date = uniqueDates[index];
                      final isSelected = _selectedDate == date;
                      return ListTile(
                        leading: Icon(Icons.date_range,
                            color:
                                isSelected ? Colors.blueAccent : Colors.grey),
                        title: Text(date,
                            style: TextStyle(
                                color: isSelected ? Colors.blueAccent : null,
                                fontWeight:
                                    isSelected ? FontWeight.bold : null)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.blueAccent)
                            : null,
                        onTap: () {
                          setState(() => _selectedDate = date);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
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
      appBar: AppBar(
        iconTheme: IconThemeData(color: appBarIconColor),
        title: _isSearching
            ? Container(
                height: 40,
                decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'بحث...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                              _searchController.clear();
                            })),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              )
            : const Text("تقرير الإنتاج"),
        centerTitle: !_isSearching,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: appBarIconColor),
            tooltip: "خيارات التقارير",
            onSelected: (value) async {
              if (value == 'search') {
                setState(() => _isSearching = true);
              } else if (value == 'filter') {
                _showDateFilterDialog();
              } else if (value == 'archive_move') {
                _moveToArchive();
              } else if (value == 'archive_open') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FlexoArchiveScreen()));
              } else if (value == 'pdf_view_prod') {
                final records = _filterAndSortRecords(
                        _productionReportBox!, _searchQuery, _sortDescending)
                    .map((e) => e.value)
                    .toList();
                await exportProductionReportsToPdf(context, records);
              } else if (value == 'pdf_save_prod') {
                final records = _filterAndSortRecords(
                        _productionReportBox!, _searchQuery, _sortDescending)
                    .map((e) => e.value)
                    .toList();
                await _savePdfToDeviceLocally(records, isPrinting: false);
              } else if (value == 'pdf_view_print') {
                final records = _filterAndSortRecords(
                        _productionReportBox!, _searchQuery, _sortDescending)
                    .map((e) => e.value)
                    .toList();
                await exportPrintingReportsToPdf(context, records);
              } else if (value == 'pdf_save_print') {
                final records = _filterAndSortRecords(
                        _productionReportBox!, _searchQuery, _sortDescending)
                    .map((e) => e.value)
                    .toList();
                await _savePdfToDeviceLocally(records, isPrinting: true);
              } else if (value == 'clear') {
                _deleteAllReports();
              } else if (value == 'sort') {
                _showSortSheet();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'search',
                  child:
                      ListTile(leading: Icon(Icons.search), title: Text('بحث'))),
              const PopupMenuItem(
                  value: 'filter',
                  child: ListTile(
                      leading: Icon(Icons.calendar_month),
                      title: Text('تصفية بالتاريخ'))),
              const PopupMenuItem(
                  value: 'archive_move',
                  child: ListTile(
                      leading: Icon(Icons.inventory_2),
                      title: Text('نقل للأرشيف'))),
              const PopupMenuItem(
                  value: 'archive_open',
                  child: ListTile(
                      leading: Icon(Icons.inventory_2_outlined),
                      title: Text('فتح الأرشيف'))),
              const PopupMenuItem(
                  value: 'pdf_view_prod',
                  child: ListTile(
                      leading: Icon(Icons.picture_as_pdf),
                      title: Text('عرض/طباعة تقرير إنتاج'))),
              const PopupMenuItem(
                  value: 'pdf_save_prod',
                  child: ListTile(
                      leading: Icon(Icons.save_alt),
                      title: Text('حفظ تقرير إنتاج'))),
              const PopupMenuItem(
                  value: 'pdf_view_print',
                  child: ListTile(
                      leading:
                          Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
                      title: Text('عرض/طباعة تقرير طباعة'))),
              const PopupMenuItem(
                  value: 'pdf_save_print',
                  child: ListTile(
                      leading: Icon(Icons.save_alt, color: Colors.blueAccent),
                      title: Text('حفظ تقرير طباعة'))),
              const PopupMenuItem(
                  value: 'sort',
                  child: ListTile(
                      leading: Icon(Icons.sort), title: Text('الترتيب'))),
              const PopupMenuItem(
                  value: 'clear',
                  child: ListTile(
                      leading: Icon(Icons.delete_sweep, color: Colors.red),
                      title: Text('مسح الكل',
                          style: TextStyle(color: Colors.red)))),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _productionReportBox!.listenable(),
        builder: (context, Box box, _) {
          return Column(
            children: [
              ActiveSessionsDashboard(
                onFinishSession: (session) => _finishSession(session),
                onCancelSession: (session) => _cancelSession(session), // ✅ إضافة دالة الإلغاء
              ),
              if (box.isEmpty && Hive.box<LiveSession>('flexo_live_sessions').isEmpty)
                const Expanded(child: Center(child: Text("🚫 لا يوجد تقارير أو جلسات نشطة"))),
              if (box.isNotEmpty || Hive.box<LiveSession>('flexo_live_sessions').isNotEmpty)
                ...[
                  if (_selectedDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.blue.withValues(alpha: 0.1),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text("تصفية بتاريخ: $_selectedDate",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          const Spacer(),
                          TextButton(
                              onPressed: () => setState(() => _selectedDate = null),
                              child: const Text("إلغاء"))
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filterAndSortRecords(box, _searchQuery, _sortDescending).length,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemBuilder: (context, index) {
                        final allRecords = _filterAndSortRecords(box, _searchQuery, _sortDescending);
                        return _buildReportCard(allRecords[index]);
                      },
                    ),
                  ),
                ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStartSessionDialog(),
        child: const Icon(Icons.play_arrow),
      ),
    );
  }

  Widget _buildReportCard(MapEntry<dynamic, Map<String, dynamic>> entry) {
    final key = entry.key;
    final record = entry.value;

    final mName = (record['machineName'] ?? record['machine_name'])?.toString() ?? '';
    final tName = (record['technicianName'] ?? record['technician_name'])?.toString() ?? '';
    final downtimeStart = record['downtimeStart'] ?? record['downtime_start'];
    final downtimeEnd = record['downtimeEnd'] ?? record['downtime_end'];
    final totalDowntime = record['totalDowntime'] ?? 0;

    String downtimeDisplay = "";
    if ((downtimeStart != null && downtimeStart.toString().isNotEmpty) ||
        (downtimeEnd != null && downtimeEnd.toString().isNotEmpty) ||
        totalDowntime > 0) {
      if (downtimeStart != null && downtimeStart.toString().isNotEmpty) {
        downtimeDisplay += "$downtimeStart إلى ${downtimeEnd ?? ''}";
      }
      if (totalDowntime > 0) {
        downtimeDisplay += " (إجمالي: $totalDowntime دقيقة)";
      }
    }

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
            _buildInfoRow("📦 الصنف:",
                "${record['product']?.toString() ?? '---'} [ ${record['productCode']?.toString() ?? '---'} ]"),
            if (record['orderNumber'] != null &&
                record['orderNumber'].toString().isNotEmpty)
              _buildInfoRow(
                  "🔢 أمر التشغيل:", record['orderNumber'].toString()),
            if ((record['startTime'] != null &&
                    record['startTime'].toString().isNotEmpty) ||
                (record['endTime'] != null &&
                    record['endTime'].toString().isNotEmpty))
              _buildInfoRow("🕒 وقت التشغيل:",
                  "${record['startTime'] ?? '--:--'} إلى ${record['endTime'] ?? '--:--'}"),
            _buildDimensionsText(record['dimensions'],
                isSheet: record['isSheet'] ?? false),
            _buildQuantityText(record['quantity']),
            _buildColorsList(record['colors'] ?? []),
            if (record['lineWaste'] != null || record['printWaste'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Text("📉 الهالك: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        "إنتاج: ${record['lineWaste'] ?? 0} | طباعة: ${record['printWaste'] ?? 0}"),
                  ],
                ),
              ),
            if (mName.isNotEmpty)
              _buildInfoRowWithIcon(Icons.settings, "الماكينة:", mName),
            if (tName.isNotEmpty)
              _buildInfoRowWithIcon(Icons.person, "الفني المسؤول:", tName),
            if (downtimeDisplay.trim().isNotEmpty)
              _buildInfoRowWithIcon(Icons.timer_off, "وقت الأعطال:", downtimeDisplay.trim()),

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
      final dateAStr = a.value['date']?.toString() ?? '2000-01-01';
      final dateBStr = b.value['date']?.toString() ?? '2000-01-01';
      final dateA = DateTime.tryParse(dateAStr) ?? DateTime(2000);
      final dateB = DateTime.tryParse(dateBStr) ?? DateTime(2000);

      // الفرز الأساسي: التاريخ (حسب اختيار المستخدم)
      int dateCompare =
          descending ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
      if (dateCompare != 0) return dateCompare;

      // الفرز الثانوي: المفتاح التقني (Key) لضمان ظهور الأحدث إضافياً أولاً عند تساوي التواريخ
      return b.key.toString().compareTo(a.key.toString());
    });

    // إضافة فلترة التاريخ في النهاية إذا كان مختاراً
    if (_selectedDate != null) {
      return entries.where((e) {
        final prodDate = _normalizeDateOnly(e.value['date']?.toString());
        return prodDate == _selectedDate;
      }).toList();
    }

    return entries;
  }

  Widget _buildInfoRowWithIcon(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
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
  Widget _buildDimensionsText(Map<dynamic, dynamic>? d,
      {bool isSheet = false}) {
    final String length = d?['length']?.toString() ?? '0';
    final String width = d?['width']?.toString() ?? '0';
    final String height = d?['height']?.toString() ?? '0';

    final String displayText =
        isSheet ? "$length / $width" : "$length / $width / $height";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Text("📏 المقاس: ",
              style: TextStyle(fontWeight: FontWeight.bold)),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(displayText,
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
        builder: (c) => ProductionReportForm(
            initialData: data,
            onSave: (r) async {
              r['id'] ??= DateTime.now().millisecondsSinceEpoch.toString();
              await _productionReportBox!.add(r);
              SupabaseManager.pushData('production_reports', r);
              if (c.mounted) Navigator.pop(c);
            }));
  }

  void _editReport(key, record) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (c) => ProductionReportForm(
            initialData: record,
            reportKey: key.toString(),
            onSave: (r) async {
              r['id'] = record['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
              await _productionReportBox!.put(key, r);
              SupabaseManager.pushData('production_reports', r);
              if (c.mounted) Navigator.pop(c);
            }));
  }

  void _showStartSessionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const StartSessionDialog(),
    );
  }



  void _finishSession(LiveSession session) {
    final now = DateTime.now();
    final startTimeStr = "${session.startTime.hour.toString().padLeft(2, '0')}:${session.startTime.minute.toString().padLeft(2, '0')}";
    final endTimeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // If session was in downtime, close the last interval
    if (!session.isRunning && session.downtimeIntervals.isNotEmpty) {
      final last = session.downtimeIntervals.last;
      last.end ??= now;
    }

    // Correct Downtime Mapping (First Start -> Last End)
    String dStart = "";
    String dEnd = "";
    if (session.downtimeIntervals.isNotEmpty) {
      final firstStart = session.downtimeIntervals.first.start;
      final lastEnd = session.downtimeIntervals.last.end ?? now;
      dStart = "${firstStart.hour.toString().padLeft(2, '0')}:${firstStart.minute.toString().padLeft(2, '0')}";
      dEnd = "${lastEnd.hour.toString().padLeft(2, '0')}:${lastEnd.minute.toString().padLeft(2, '0')}";
    }

    final totalDowntimeMin = session.totalDowntime.inMinutes;

    final initialData = {
      'date': "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      'clientName': session.clientName,
      'product': session.productName,
      'productCode': session.productCode,
      'order_number': session.orderNumber,
      'start_time': startTimeStr,
      'end_time': endTimeStr,
      'downtime_start': dStart,
      'downtime_end': dEnd,
      'totalDowntime': totalDowntimeMin,
      'machineName': session.machineName,
      'technicianName': session.technicianName,
      'dimensions': session.dimensions,
      'isSheet': session.isSheet,
      'imagePaths': session.imagePaths,
      'notes': "", // Total was moved to dedicated field
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => ProductionReportForm(
        initialData: initialData,
        onSave: (r) async {
          r['id'] ??= DateTime.now().millisecondsSinceEpoch.toString();
          await _productionReportBox!.add(r);
          SupabaseManager.pushData('production_reports', r);
          await session.delete(); // Remove the session once saved as report
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  void _cancelSession(LiveSession session) {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "إلغاء الجلسة",
      content: "هل أنت متأكد من إلغاء هذه الجلسة؟ سيتم حذف جميع البيانات المؤقتة الخاصة بها نهائياً.",
      confirmLabel: "إلغاء الجلسة",
      onConfirm: () async {
        await session.delete(); // حذف مباشر من Hive دون ترحيل
        if (mounted) {
          UIUtils.showInfoSnackBar(
            message: "تم إلغاء الجلسة بنجاح",
            backgroundColor: Colors.orange,
            icon: Icons.delete_sweep,
          );
        }
      },
    );
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
