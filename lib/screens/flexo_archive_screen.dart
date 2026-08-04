import 'package:smart_sheet/models/die_cutting_production_report.dart';
import 'package:smart_sheet/models/flexo_production_report.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/screens/archive_detail_screen.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/utils/archive_rbac_logic.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FlexoArchiveScreen extends StatefulWidget {
  final String? department;
  const FlexoArchiveScreen({super.key, this.department});

  @override
  State<FlexoArchiveScreen> createState() => _FlexoArchiveScreenState();
}

class _FlexoArchiveScreenState extends State<FlexoArchiveScreen> {
  Box? _archiveBox;
  bool _isSearching = false;
  String _searchQuery = "";
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    final boxName = widget.department == 'production_line'
        ? 'lineArchive'
        : (widget.department == 'crushing' ||
                widget.department == 'die_cutting')
            ? 'crushingArchive'
            : 'flexoArchive';
    if (Hive.isBoxOpen(boxName)) {
      _archiveBox = Hive.box(boxName);
    } else {
      Hive.openBox(boxName).then((box) {
        if (mounted) setState(() => _archiveBox = box);
      });
    }
  }

  void _deleteEntry(dynamic key) {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "تأكيد حذف الأرشيف",
      content: "هل أنت متأكد من حذف هذا السجل نهائياً؟",
      onConfirm: () async {
        final targetTable = widget.department == 'production_line'
            ? 'line_archived_reports'
            : (widget.department == 'crushing' ||
                    widget.department == 'die_cutting')
                ? 'die_cutting_archived_reports'
                : 'flexo_archived_reports';

        final data = _archiveBox!.get(key);
        if (data is Map) {
          final report = data['data'] ?? data;
          final syncId = report['sync_id'] ?? report['id'];
          if (syncId != null) {
            SyncService.instance.pushToQueue(
                targetTable, {'id': syncId, 'sync_id': syncId},
                operation: 'delete');
          }
        }
        await _archiveBox!.delete(key);
      },
    );
  }

  void _clearArchive() {
    if (_archiveBox == null || _archiveBox!.isEmpty) return;
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "⚠️ مسح الأرشيف بالكامل",
      content: "هل أنت متأكد من مسح كافة بيانات الأرشيف نهائياً؟",
      onConfirm: () async {
        // جمع جميع sync_ids في قائمة واحدة ثم إرسال batch_delete واحد
        final targetTable = widget.department == 'production_line'
            ? 'line_archived_reports'
            : (widget.department == 'crushing' ||
                    widget.department == 'die_cutting')
                ? 'die_cutting_archived_reports'
                : 'flexo_archived_reports';
        final syncIds = <String>[];
        for (var value in _archiveBox!.values) {
          if (value is Map) {
            final report = value['data'] ?? value;
            final syncId =
                report['sync_id']?.toString() ?? report['id']?.toString();
            if (syncId != null && syncId.isNotEmpty) {
              syncIds.add(syncId);
            }
          }
        }
        if (syncIds.isNotEmpty) {
          SyncService.instance.pushBatchDeleteToQueue(targetTable, syncIds);
        }
        await _archiveBox!.clear();
      },
    );
  }

  // ✅ ميزة استعادة سجل واحد للأرشيف
  void _restoreEntry(dynamic key, Map data) async {
    try {
      final reportsBox =
          Hive.box<FlexoProductionReport>('flexo_production_reports_box');
      final reportData = data['data'] ?? data;
      final parsedData = Map<String, dynamic>.from(reportData);

      final dept = parsedData['department']?.toString() ?? widget.department;

      if (dept == 'crushing' || dept == 'die_cutting') {
        final reportObj = DieCuttingProductionReport.fromJson(parsedData);
        Hive.box<DieCuttingProductionReport>('die_cutting_production_reports_box').add(reportObj);
        SyncService.instance.pushToQueue('die_cutting_production_reports', reportObj.toJson());
      } else {
        final reportObj = FlexoProductionReport.fromJson(parsedData);
        await reportsBox.add(reportObj);
        
        final targetProdTable = (dept == 'production_line') ? 'line_production_reports' : 'flexo_production_reports';
        SyncService.instance.pushToQueue(targetProdTable, reportObj.toJson());
      }

      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: "تم استعادة نسخة من تقرير الإنتاج للقسم النشط بنجاح",
          backgroundColor: Colors.green,
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      debugPrint("Restore Error: $e");
    }
  }

  // ✅ ميزة استعادة الكل
  void _restoreAllEntries() {
    if (_archiveBox == null || _archiveBox!.isEmpty) return;

    UIUtils.showDeleteConfirmation(
      context: context,
      title: "إستعادة نسخة من كافة البيانات",
      content:
          "سيتم نسخ كافة تقارير الأرشيف إلى القسم النشط مع الإبقاء عليها في الأرشيف. هل تريد الاستمرار؟",
      confirmLabel: "إستعادة الكل",
      confirmColor: Colors.green,
      onConfirm: () async {
        try {
          final reportsBox =
              Hive.box<FlexoProductionReport>('flexo_production_reports_box');
          final allArchive = _archiveBox!.toMap();

          final supabase = Supabase.instance.client;
          final List<Map<String, dynamic>> flexoArchiveToUpsert = [];
          final List<Map<String, dynamic>> dieCuttingArchiveToUpsert = [];

          for (var entry in allArchive.entries) {
            try {
              final data = entry.value as Map;
              final reportData = data['data'] ?? data;
              final parsedData = Map<String, dynamic>.from(reportData);
              final dept = parsedData['department']?.toString() ?? widget.department;

              if (dept == 'crushing' || dept == 'die_cutting') {
                final reportObj = DieCuttingProductionReport.fromJson(parsedData);
                Hive.box<DieCuttingProductionReport>('die_cutting_production_reports_box').add(reportObj);
                SyncService.instance.pushToQueue('die_cutting_production_reports', reportObj.toJson());
                SyncService.instance.pushToQueue('die_cutting_archived_reports', reportObj.toJson());
                dieCuttingArchiveToUpsert.add(reportObj.toJson());
                continue;
              } else {
                final reportObj = FlexoProductionReport.fromJson(parsedData);
                await reportsBox.add(reportObj);

                final targetProdTable = (dept == 'production_line') ? 'line_production_reports' : 'flexo_production_reports';
                final targetArchTable = (dept == 'production_line') ? 'line_archived_reports' : 'flexo_archived_reports';

                SyncService.instance.pushToQueue(targetProdTable, reportObj.toJson());
                SyncService.instance.pushToQueue(targetArchTable, reportObj.toJson());
                
                // Add to flexoArchiveToUpsert, but we should probably separate line_archived_reports if needed. 
                // Since there is only one array for direct upsert in this function, let's just rely on the Queue.
                if (targetArchTable == 'flexo_archived_reports') {
                    flexoArchiveToUpsert.add(reportObj.toJson());
                }
              }
            } catch (e) {
              debugPrint("❌ فشل استعادة تسجيلة (Exception: $e)");
              debugPrint("❌ محتوى التسجيلة المرفوضة: ${entry.value}");
              // ننتقل للتسجيلة التي تليها دون إيقاف العملية
            }
          }

          try {
            if (flexoArchiveToUpsert.isNotEmpty) {
              await supabase.from('flexo_archived_reports').upsert(flexoArchiveToUpsert);
              debugPrint('✅ تم الرفع المباشر لـ ${flexoArchiveToUpsert.length} تسجيلة أرشيف (فلكسو).');
            }
            if (dieCuttingArchiveToUpsert.isNotEmpty) {
              await supabase.from('die_cutting_archived_reports').upsert(dieCuttingArchiveToUpsert);
              debugPrint('✅ تم الرفع المباشر لـ ${dieCuttingArchiveToUpsert.length} تسجيلة أرشيف (تكسير).');
            }
          } catch (e) {
             debugPrint('⚠️ فشل الرفع المباشر للأرشيف، سيتم الاعتماد على طابور المزامنة: $e');
          }
          // تم إزالة عملية التفريغ (clear) بناءً على طلب المستخدم لإبقاء الأرشيف كنسخة دائمة

          if (mounted) {
            UIUtils.showInfoSnackBar(
              message:
                  "تم إستعادة نسخة من كافة تقارير الإنتاج للقسم النشط بنجاح",
              backgroundColor: Colors.green,
              icon: Icons.settings_backup_restore,
            );
          }
        } catch (e) {
          debugPrint("Restore All Error: $e");
        }
      },
    );
  }

  String _normalizeString(String input) {
    if (input.isEmpty) return "";
    String normalized = input.trim().toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll('ى', 'ي');
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < arabicNumbers.length; i++) {
      normalized = normalized.replaceAll(arabicNumbers[i], i.toString());
    }
    return normalized;
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
    // في حال فشل الـ parse، نحاول استخراج أول جزء (التاريخ) يدوياً
    return dateStr.split(' ')[0].split('T')[0];
  }

  List<MapEntry<dynamic, dynamic>> _getFilteredEntries(Box box) {
    final query = _normalizeString(_searchQuery);
    var entries = box.toMap().entries.toList();

    // فلترة بالقسم
    final targetDept = widget.department ?? 'flexo';
    entries = entries.where((e) {
      final data = e.value as Map;
      final report = data['data'] ?? data;
      if (targetDept == 'crushing') return true;
      final dept = report['department']?.toString() ?? 'flexo';
      return dept == targetDept;
    }).toList();

    // 1. الفلترة باسم العميل أو كود الصنف
    if (query.isNotEmpty) {
      entries = entries.where((e) {
        final data = e.value as Map;
        final report = data['data'] ?? data;
        final clientName = _normalizeString(report['clientName']?.toString() ??
            report['client_name']?.toString() ??
            report['customerName']?.toString() ??
            report['customer_name']?.toString() ??
            '');
        final productCode = _normalizeString(
            report['productCode']?.toString() ??
                report['product_code']?.toString() ??
                report['itemCode']?.toString() ??
                report['item_code']?.toString() ??
                '');
        final productName = _normalizeString(report['product']?.toString() ??
            report['itemName']?.toString() ??
            report['item_name']?.toString() ??
            '');
        return clientName.contains(query) ||
            productCode.contains(query) ||
            productName.contains(query);
      }).toList();
    }

    // 2. الفلترة بتاريخ الإنتاج المختار (بعد التطبيع)
    if (_selectedDate != null) {
      entries = entries.where((e) {
        final data = e.value as Map;
        final report = data['data'] ?? data;
        final prodDate = _normalizeDateOnly(report['date']?.toString() ??
            report['reportDate']?.toString() ??
            report['report_date']?.toString());
        return prodDate == _selectedDate;
      }).toList();
    }

    return entries;
  }



  void _showDateFilterDialog() async {
    if (_archiveBox == null || _archiveBox!.isEmpty) {
      UIUtils.showInfoSnackBar(message: "لا توجد تقارير مسجلة لعرض تواريخها", backgroundColor: Colors.orange);
      return;
    }

    final Set<String> uniqueDates = {};
    for (var entry in _archiveBox!.values) {
      if (entry is Map) {
        final report = entry['data'] ?? entry;
        final date = _normalizeDateOnly(report['date']?.toString() ??
            report['reportDate']?.toString() ??
            report['report_date']?.toString());
        if (date.isNotEmpty) {
          uniqueDates.add(date);
        }
      }
    }

    if (uniqueDates.isEmpty) {
      UIUtils.showInfoSnackBar(message: "لا توجد تواريخ مسجلة لعرضها", backgroundColor: Colors.orange);
      return;
    }

    final List<String> sortedDates = uniqueDates.toList()..sort((a, b) => b.compareTo(a));

    final String? pickedDate = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('اختر التاريخ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                return ListTile(
                  title: Text(date, style: const TextStyle(fontSize: 16)),
                  trailing: const Icon(Icons.calendar_today, size: 16, color: Colors.blueAccent),
                  onTap: () {
                    Navigator.pop(context, date);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_archiveBox == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ValueListenableBuilder<dynamic>(
        valueListenable: (Hive.isBoxOpen('workers')
            ? Hive.box<Worker>('workers').listenable()
            : ValueNotifier<Box<Worker>?>(null)) as ValueListenable<dynamic>,
        builder: (context, workersBox, _) {
          final bool isDark = Theme.of(context).brightness == Brightness.dark;
          final Color appBarIconColor = isDark ? Colors.white : Colors.black87;

          final Worker? cw = PermissionHelper.currentWorker;
          final String currentScreenDept = widget.department ?? 'flexo';
          final String normalizedDept = (currentScreenDept == 'crushing' &&
                  cw?.department == 'die_cutting')
              ? 'die_cutting'
              : currentScreenDept;

          return Scaffold(
            appBar: AppBar(
              iconTheme: IconThemeData(color: appBarIconColor),
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
              title: _isSearching
                  ? Container(
                      height: 40,
                      decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10)),
                      child: TextField(
                        autofocus: true,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87),
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'بحث باسم العميل...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => setState(() {
                                    _isSearching = false;
                                    _searchQuery = '';
                                    _selectedDate = null;
                                  })),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    )
                  : Text(widget.department == 'production_line'
                      ? "أرشيف خط الإنتاج"
                      : widget.department == 'crushing'
                          ? "أرشيف تقارير التكسير"
                          : "أرشيف تقارير الفلكسو"),
              centerTitle: !_isSearching,
              actions: [

                // ✅ تم نقل مسح الكل إلى القائمة المنسدلة
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: appBarIconColor),
                  tooltip: "خيارات الأرشيف",
                  onSelected: (value) async {
                    if (value == 'search') {
                      setState(() => _isSearching = true);
                    } else if (value == 'filter') {
                      _showDateFilterDialog();
                    } else if (value == 'archive') {
                      _showDateFilterDialog();
                    } else if (value == 'restore') {
                      _restoreAllEntries();
                    } else if (value == 'clear_all') {
                      _clearArchive();
                    } else if (value == 'open_archive') {
                      // no-op
                    } else if (value == 'sort') {
                      // no-op
                    }
                  },
                  itemBuilder: (context) {
                    final bool showRestoreAll = PermissionHelper.isSuperAdmin ||
                        ArchiveRbacService.canRestore(cw, normalizedDept);

                    return [
                      const PopupMenuItem(
                          value: 'search',
                          child: ListTile(
                              leading: Icon(Icons.search), title: Text('بحث'))),
                      const PopupMenuItem(
                          value: 'filter',
                          child: ListTile(
                              leading: Icon(Icons.calendar_month),
                              title: Text('تصفية بالتاريخ'))),
                      if (showRestoreAll)
                        const PopupMenuItem(
                            value: 'restore',
                            child: ListTile(
                                leading: Icon(Icons.settings_backup_restore),
                                title: Text('استعادة الكل'))),
                      if (PermissionHelper.isSuperAdmin || (cw?.canDeleteArchive ?? false))
                        const PopupMenuItem(
                            value: 'clear_all',
                            child: ListTile(
                                leading: Icon(Icons.delete_sweep, color: Colors.red),
                                title: Text('مسح الأرشيف بالكامل', style: TextStyle(color: Colors.red)))),
                    ];
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(40.0),
                child: ValueListenableBuilder(
                  valueListenable: _archiveBox!.listenable(),
                  builder: (context, Box box, _) {
                    final filteredCount = _getFilteredEntries(box).length;
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;

                    return Container(
                      height: 40,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.blueGrey[50],
                        border: Border(
                          bottom: BorderSide(
                            color:
                                isDark ? Colors.black54 : Colors.blueGrey[100]!,
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 16,
                            color: isDark
                                ? Colors.blueAccent[100]
                                : Colors.blueAccent,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'إجمالي التقارير: $filteredCount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.blueGrey[800],
                            ),
                          ),
                          if (_selectedDate != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event,
                                      size: 14, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedDate!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedDate = null),
                                    child: const Icon(Icons.close,
                                        size: 14, color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            body: ValueListenableBuilder(
              valueListenable: _archiveBox!.listenable(),
              builder: (context, Box box, _) {
                if (box.isEmpty) {
                  return const Center(child: Text("📂 الأرشيف فارغ"));
                }

                var entries = _getFilteredEntries(box);

                if (entries.isEmpty && _isSearching) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "لا توجد تقارير مؤرشفة لهذا العميل",
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                if (entries.isEmpty) {
                  return const Center(child: Text("📂 لا توجد بيانات"));
                }

                // ✅ الفرز النهائي: التاريخ (تنازلي) ثم اسم العميل (تصاعدي)
                entries.sort((a, b) {
                  final dataA = a.value as Map;
                  final dataB = b.value as Map;

                  final reportA = dataA['data'] ?? dataA;
                  final reportB = dataB['data'] ?? dataB;

                  final dateAStr = reportA['date']?.toString() ?? '2000-01-01';
                  final dateBStr = reportB['date']?.toString() ?? '2000-01-01';

                  final dateA = DateTime.tryParse(dateAStr) ?? DateTime(2000);
                  final dateB = DateTime.tryParse(dateBStr) ?? DateTime(2000);

                  int dateCompare = dateB.compareTo(dateA);
                  if (dateCompare != 0) return dateCompare;

                  final nameA =
                      (reportA['clientName'] ?? reportA['client_name'] ?? '')
                          .toString()
                          .toLowerCase();
                  final nameB =
                      (reportB['clientName'] ?? reportB['client_name'] ?? '')
                          .toString()
                          .toLowerCase();

                  return nameA.compareTo(nameB);
                });

                return ListView.builder(
                  itemCount: entries.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _buildArchiveCard(entry.key, entry.value as Map);
                  },
                );
              },
            ),
          );
        });
  }

  Widget _buildArchiveInfoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveCard(dynamic key, Map data) {
    final report = data['data'] ?? data;
    final String clientName = report['clientName'] ??
        report['client_name'] ??
        report['customerName'] ??
        report['customer_name'] ??
        "";
    final String product = report['product'] ??
        report['product_name'] ??
        report['itemName'] ??
        report['item_name'] ??
        "";
    final String productCode = report['productCode']?.toString() ??
        report['product_code']?.toString() ??
        report['itemCode']?.toString() ??
        report['item_code']?.toString() ??
        '';
    final String displayDate = report['date'] ??
        report['reportDate'] ??
        report['report_date'] ??
        "---";
    final String orderNumber = report['orderNumber']?.toString() ??
        report['order_number']?.toString() ??
        report['workOrder']?.toString() ??
        report['work_order']?.toString() ??
        '';
    final String formNumber = report['formNumber']?.toString() ??
        report['form_number']?.toString() ??
        (report['dimensions'] is Map
            ? (report['dimensions'] as Map)['form_number']?.toString()
            : null) ??
        '';
    final String startTime = report['startTime']?.toString() ??
        report['start_time']?.toString() ??
        report['runTimeStart']?.toString() ??
        report['run_time_start']?.toString() ??
        '';
    final String endTime = report['endTime']?.toString() ??
        report['end_time']?.toString() ??
        report['runTimeEnd']?.toString() ??
        report['run_time_end']?.toString() ??
        '';
    final String machineName =
        (report['machineName'] ?? report['machine_name'])?.toString() ?? '';
    final String technicianName =
        (report['technicianName'] ?? report['technician_name'])?.toString() ??
            '';
    final String dept = report['department']?.toString() ?? '';
    final bool isProdLine = dept == 'production_line' ||
        machineName == 'خط الإنتاج' ||
        widget.department == 'production_line';
    final bool isCrushing =
        dept == 'crushing' || dept == 'die_cutting' ||
        widget.department == 'crushing' || widget.department == 'die_cutting';

    final dims = report['dimensions'];
    final bool isSheet = report['isSheet'] ?? false;
    final String length = dims?['length']?.toString() ?? '0';
    final String width = dims?['width']?.toString() ?? '0';
    final String height = dims?['height']?.toString() ?? '0';
    final String dimStr =
        dims != null && (dims['length'] != 0 || dims['width'] != 0)
            ? (isCrushing || isProdLine)
                // التكسير وخط الإنتاج: طول / عرض / ارتفاع (من اليمين لليسار)
                ? "$length / $width / $height"
                : (isSheet ? "$width / $length" : "$height / $width / $length")
            : "";

    final quantity = report['quantity'] ??
        report['production_quantity'] ??
        report['productionQuantity'] ??
        0;
    final lineWaste = report['lineWaste'] ?? report['line_waste'] ?? report['waste_quantity'] ?? report['wasteQuantity'] ?? 0;
    final printWaste = report['printWaste'] ?? report['print_waste'] ?? 0;

    final w = report['weight'];
    final double weightVal = w != null
        ? (w is num ? w.toDouble() : (double.tryParse(w.toString()) ?? 0.0))
        : 0.0;

    final rawLayers = report['paperLayers'] ?? report['paper_layers'];
    final List<String> layers = [];
    if (rawLayers is List) {
      layers.addAll(
          rawLayers.map((e) => e.toString().trim()).where((e) => e.isNotEmpty));
    }

    // ─── تنسيق الوقت: تحويل ISO 8601 أو أي صيغة إلى HH:mm بدون تغيير المنطقة الزمنية ─────────────────
    String formatCardTime(dynamic raw) {
      if (raw == null) return '';
      final s = raw.toString().trim();
      if (s.isEmpty || s == 'null' || s == '--:--') return '';
      
      // استخراج الوقت مباشرة من نص ISO 8601 لتجنب تغيير المنطقة الزمنية (toLocal)
      final isoMatch = RegExp(r'T(\d{2}:\d{2})').firstMatch(s);
      if (isoMatch != null) {
        return isoMatch.group(1)!;
      }
      
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(s)) return s.substring(0, 5);
      return s;
    }

    final startFormatted = formatCardTime(startTime.isNotEmpty ? startTime : null);
    final endFormatted = formatCardTime(endTime.isNotEmpty ? endTime : null);

    final downtimeStart = report['downtimeStart'] ?? report['downtime_start'];
    final downtimeEnd = report['downtimeEnd'] ?? report['downtime_end'];
    final rawTotalDowntime = report['totalDowntime'];
    final int totalDowntime = rawTotalDowntime is num
        ? rawTotalDowntime.toInt()
        : int.tryParse(rawTotalDowntime?.toString() ?? '0') ?? 0;

    String downtimeDisplay = "";
    if ((downtimeStart != null && downtimeStart.toString().isNotEmpty) ||
        (downtimeEnd != null && downtimeEnd.toString().isNotEmpty) ||
        totalDowntime > 0) {
      if (downtimeStart != null && downtimeStart.toString().isNotEmpty) {
        final ds = formatCardTime(downtimeStart);
        final de = formatCardTime(downtimeEnd);
        downtimeDisplay += "${ds.isNotEmpty ? ds : downtimeStart}  ◀  ${de.isNotEmpty ? de : (downtimeEnd ?? '')}";
      }
      if (totalDowntime > 0) {
        downtimeDisplay += " (إجمالي: $totalDowntime دقيقة)";
      }
    }

    final colors = report['colors'] as List? ?? [];

    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onLongPress: () => _deleteEntry(key),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArchiveDetailScreen(
                record: {
                  ...Map<String, dynamic>.from(report),
                  'archiveDate': data['archiveDate'] ?? '---',
                },
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 420;

                  // ─── الأزرار (مشتركة بين الحالتين) ───────────────
                  final Worker? cw = PermissionHelper.currentWorker;
                  final String currentScreenDept = widget.department ?? 'flexo';
                  final String normalizedDept =
                      (currentScreenDept == 'crushing' &&
                              cw?.department == 'die_cutting')
                          ? 'die_cutting'
                          : currentScreenDept;

                  final bool showRestore = PermissionHelper.isSuperAdmin ||
                      ArchiveRbacService.canRestore(cw, normalizedDept);
                  final bool showDelete = PermissionHelper.isSuperAdmin ||
                      (cw?.canDeleteArchive ?? false);

                  final actionButtons = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showRestore)
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.settings_backup_restore,
                              color: Colors.green),
                          onPressed: () => _restoreEntry(key, data),
                          tooltip: "إستعادة للرئيسية",
                        ),
                      if (showRestore && showDelete) const SizedBox(width: 12),
                      if (showDelete)
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.delete_outline,
                              color: Colors.red.shade300),
                          onPressed: () => _deleteEntry(key),
                          tooltip: "حذف من الأرشيف",
                        ),
                    ],
                  );

                  final dateText = Text(
                    displayDate.split('T')[0].split(' ')[0],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  );

                  final clientText = Text(
                    clientName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                    overflow: TextOverflow.ellipsis,
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: clientText),
                            actionButtons,
                          ],
                        ),
                        const SizedBox(height: 4),
                        dateText,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: clientText),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          dateText,
                          const SizedBox(width: 8),
                          actionButtons,
                        ],
                      ),
                    ],
                  );
                },
              ),
              const Divider(height: 24, thickness: 1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87,
                          fontSize: 15,
                        ),
                        children: [
                          TextSpan(
                            text: product.replaceAll("\n", " "),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (productCode.isNotEmpty)
                            TextSpan(
                              text: " [ $productCode ]",
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (orderNumber.isNotEmpty)
                _buildArchiveInfoRow(
                    Icons.numbers, "أمر التشغيل:", orderNumber),
              if (formNumber.isNotEmpty)
                _buildArchiveInfoRow(
                    Icons.description, "رقم الفورمة:", formNumber),
              if (startFormatted.isNotEmpty || endFormatted.isNotEmpty)
                _buildArchiveInfoRow(Icons.schedule, "وقت التشغيل:",
                    "${startFormatted.isNotEmpty ? startFormatted : '--:--'}  ◀  ${endFormatted.isNotEmpty ? endFormatted : '--:--'}"),
              if (dimStr.isNotEmpty)
                _buildArchiveInfoRow(Icons.straighten, "المقاس:", dimStr,
                    valueColor: Colors.blueAccent),
              _buildArchiveInfoRow(
                  Icons.format_list_numbered, "الكمية:", "$quantity"),
              if (weightVal > 0)
                _buildArchiveInfoRow(Icons.scale, "الوزن:", "$weightVal طن",
                    valueColor: Colors.teal),
              if (layers.isNotEmpty)
                _buildArchiveInfoRow(
                    Icons.layers, "طبقات الورق:", layers.join('  |  '),
                    valueColor: Colors.brown),
              _buildArchiveInfoRow(
                Icons.trending_down,
                "الهالك:",
                (isProdLine || isCrushing)
                    ? "$lineWaste"
                    : "إنتاج: $lineWaste | طباعة: $printWaste",
              ),
              if (machineName.isNotEmpty)
                _buildArchiveInfoRow(
                    Icons.precision_manufacturing, "الماكينة:", machineName),
              if (technicianName.isNotEmpty)
                _buildArchiveInfoRow(
                    Icons.person, "الفني المسؤول:", technicianName),
              if (downtimeDisplay.isNotEmpty)
                _buildArchiveInfoRow(
                    Icons.timer_off, "وقت الأعطال:", downtimeDisplay,
                    valueColor: Colors.redAccent),
              if (report['notes'] != null &&
                  report['notes'].toString().trim().isNotEmpty &&
                  !report['notes'].toString().contains("مستورد"))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            report['notes'].toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.orange.shade100
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!isProdLine && !isCrushing && colors.isNotEmpty) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: colors.map((c) {
                      final name = c['color'] ?? '---';
                      final qty = c['quantity'] ?? '0';
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle,
                                size: 10, color: Colors.blueAccent),
                            const SizedBox(width: 6),
                            Text(
                              "$name: $qty ل",
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
