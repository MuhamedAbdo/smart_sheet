// lib/screens/production_report_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/screens/flexo_archive_screen.dart';
import 'package:smart_sheet/widgets/production_report_form.dart';
import 'package:smart_sheet/widgets/start_session_dialog.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/flexo_production_report.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';
import 'package:smart_sheet/widgets/active_sessions_dashboard.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/flexo_report_drawer.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/services/server_time_service.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:smart_sheet/utils/auth_helper.dart';
import 'package:smart_sheet/screens/production_line/start_production_session_screen.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/utils/archive_rbac_logic.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

DateTime? _parseTimeForDieCutting(String? dateStr, String? timeStr) {
  if (dateStr == null || timeStr == null || timeStr.isEmpty || timeStr == '--:--') return null;
  try {
    final d = DateTime.parse(dateStr);
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    return DateTime(d.year, d.month, d.day, int.parse(parts[0]), int.parse(parts[1]));
  } catch (_) {
    return null;
  }
}

class FlexoProductionReportScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? department;

  const FlexoProductionReportScreen({super.key, this.initialData, this.department});

  @override
  State<FlexoProductionReportScreen> createState() => _FlexoProductionReportScreenState();
}

class _FlexoProductionReportScreenState extends State<FlexoProductionReportScreen> {
  Box? _productionReportBox;
  Box<Worker>? _workersBox;
  bool _isBoxLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  String? _selectedDate;
  bool _sortDescending = true;
  // ─── حارس منع الضغطة المزدوجة على زر إنهاء الجلسة ───
  bool _isFinishingSession = false;

  @override
  void initState() {
    super.initState();
    _openBoxSafe();
    // فتح workers box للاستماع لتغييرات الصلاحيات
    if (Hive.isBoxOpen('workers')) {
      _workersBox = Hive.box<Worker>('workers');
    } else {
      Hive.openBox<Worker>('workers').then((box) {
        if (mounted) setState(() => _workersBox = box);
      });
    }
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  Future<void> _openBoxSafe() async {
    try {
      final targetBox = (widget.department == 'crushing' || widget.department == 'die_cutting') 
          ? 'die_cutting_production_reports' 
          : 'flexo_production_reports_box';
          
      if (!Hive.isBoxOpen(targetBox)) {
        if (targetBox == 'die_cutting_production_reports') {
          await Hive.openBox<DieCuttingProductionReport>(targetBox);
        } else {
          await Hive.openBox<FlexoProductionReport>(targetBox);
        }
      }

      // ✅ FIX: افتح flexo_live_sessions مبكّراً لضمان توفره قبل بناء الواجهة
      if (!Hive.isBoxOpen('flexo_live_sessions')) {
        await Hive.openBox<LiveSession>('flexo_live_sessions');
      }
      if (mounted) {
        setState(() {
          if (targetBox == 'die_cutting_production_reports') {
            _productionReportBox = Hive.box<DieCuttingProductionReport>(targetBox);
          } else {
            _productionReportBox = Hive.box<FlexoProductionReport>(targetBox);
          }
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _deleteSingleReport(dynamic key, dynamic record) {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "تأكيد الحذف",
      content: "هل تريد حذف هذا التقرير؟",
      onConfirm: () async {
        final messenger = ScaffoldMessenger.of(context);
        await _productionReportBox!.delete(key);

        // ✅ مزامنة الحذف مع Supabase لتحديث جميع الأجهزة
        final syncId =
            record['sync_id']?.toString() ?? record['id']?.toString();
        final String tableName = (widget.department == 'crushing' || widget.department == 'die_cutting') 
            ? 'die_cutting_production_reports' 
            : 'flexo_production_reports';
            
        if (syncId != null) {
          SyncService.instance.pushToQueue(
            tableName,
            {'sync_id': syncId, 'id': syncId},
            operation: 'delete',
          );
          debugPrint(
              '🗑️ _deleteSingleReport: تم إضافة الحذف للـ Queue (sync_id=$syncId, table=$tableName)');
        }

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

        // 1. جلب جميع المعرفات (sync_id) لحذفها من السيرفر دفعة واحدة
        final List<String> listOfIds = [];
        for (var record in backup.values) {
          final syncId =
              record['sync_id']?.toString() ?? record['id']?.toString();
          if (syncId != null && syncId.isNotEmpty) {
            listOfIds.add(syncId);
          }
        }

        final String tableName = (widget.department == 'crushing' || widget.department == 'die_cutting') 
            ? 'die_cutting_production_reports' 
            : 'flexo_production_reports';

        try {
          // 2. أمر المسح من السيرفر باستخدام inFilter
          if (listOfIds.isNotEmpty) {
            await Supabase.instance.client
                .from(tableName)
                .delete()
                .inFilter('sync_id', listOfIds);
            debugPrint(
                '🗑️ _deleteAllReports: تم مسح ${listOfIds.length} تقرير من السيرفر دفعة واحدة.');
          }

          // 3. مسح البوكس المحلي بعد السيرفر لتفادي المشاكل
          await _productionReportBox!.clear();

          if (mounted) {
            messenger.clearSnackBars();
            UIUtils.showUndoSnackBar(
              context: context,
              message: "تم مسح جميع التقارير (محلياً ومن السيرفر)",
              onUndo: () async {
                messenger.clearSnackBars();
                for (var entry in backup.entries) {
                  await _productionReportBox!.put(entry.key, entry.value);
                  // إعادة رفع المحذوفات للسيرفر في حالة التراجع
                  SyncService.instance
                      .pushToQueue(tableName, entry.value.toJson());
                }
              },
            );
          }
        } catch (e) {
          debugPrint("Error clearing reports from Supabase: $e");
          if (mounted) {
            UIUtils.showInfoSnackBar(
              message:
                  "حدث خطأ أثناء محاولة الحذف من السيرفر. تحقق من الاتصال.",
              backgroundColor: Colors.red,
            );
          }
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
          final isProdLineDept = widget.department == 'production_line';
          final archiveBoxName = isProdLineDept
              ? 'lineArchive'
              : widget.department == 'crushing'
                  ? 'crushingArchive'
                  : 'flexoArchive';
          final archiveBox = Hive.isBoxOpen(archiveBoxName)
              ? Hive.box(archiveBoxName)
              : await Hive.openBox(archiveBoxName);
          final allReports = _productionReportBox!.toMap();

          for (var entry in allReports.entries) {
            final val = entry.value;
            final r = val is DieCuttingProductionReport ? val.toJson() : Map<String, dynamic>.from(val);
            final dept = r['department']?.toString() ?? (val is DieCuttingProductionReport ? (widget.department ?? 'die_cutting') : null);
            if (isProdLineDept) {
              if (dept != 'production_line') continue;
            } else {
              if (dept == 'production_line') continue;
            }

            // ✅ ضمان وجود sync_id سليم قبل الأرشفة والمزامنة
            // إذا كان التقرير بدون sync_id فارغ أو غير موجود، نولد له UUID جديد
            final existingSyncId = r['sync_id']?.toString();
            final archiveSyncId = (existingSyncId != null &&
                    existingSyncId.isNotEmpty &&
                    existingSyncId != 'null')
                ? existingSyncId
                : const Uuid().v4();
            r['sync_id'] = archiveSyncId;

            // ✅ الحفظ بالـ sync_id كمفتاح لمنع التكرار عند وصول Insert event من Realtime
            final archiveEntry = {
              'type': 'REPORT',
              'data': r,
              'archiveDate':
                  ServerTimeService.nowLocal.toString().split('.')[0],
            };
            await archiveBox.put(archiveSyncId, archiveEntry);

            // مزامنة فورية للأرشيف (مخصصة لقسم التكسير بناءً على طلب المستخدم)
            if (widget.department == 'crushing') {
              // ✅ تمرير r مع sync_id مضمون لطابور المزامنة
              SyncService.instance.pushToQueue('archived_reports', r);
              debugPrint('📤 الأرشفة (crushing): تم إضافة للقائمة (sync_id=$archiveSyncId)');
            }
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
        automaticallyImplyLeading: true,
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
            : Text(widget.department == 'production_line'
                ? "تقرير إنتاج خط الإنتاج 🏭"
                : "تقرير الإنتاج"),
        centerTitle: !_isSearching,
        actions: [
          // ─── ربط القائمة بـ Hive لتحديث الصلاحيات فورياً ───
          if (_workersBox != null)
            ValueListenableBuilder<Box<Worker>>(
              valueListenable: _workersBox!.listenable(),
              builder: (context, _, __) {
                final bool isSuperAdmin = PermissionHelper.isSuperAdmin;

                // استخدام صلاحيات الأرشيف الجديدة (ArchiveRbacService)
                final Worker? cw = PermissionHelper.currentWorker;
                final String currentScreenDept = widget.department ?? 'flexo';
                final String normalizedDept = (currentScreenDept == 'crushing' && cw?.department == 'die_cutting') 
                    ? 'die_cutting' 
                    : currentScreenDept;

                final bool showArchiveOpen = isSuperAdmin || ArchiveRbacService.canRead(cw);
                final bool showArchiveMove = isSuperAdmin || ArchiveRbacService.canAdd(cw, normalizedDept);

                return PopupMenuButton<String>(
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
                              builder: (_) => FlexoArchiveScreen(
                                    department: widget.department,
                                  )));
                    } else if (value == 'clear') {
                      _deleteAllReports();
                    } else if (value == 'sort') {
                      _showSortSheet();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'search',
                        child: ListTile(
                            leading: Icon(Icons.search), title: Text('بحث'))),
                    const PopupMenuItem(
                        value: 'filter',
                        child: ListTile(
                            leading: Icon(Icons.calendar_month),
                            title: Text('تصفية بالتاريخ'))),
                    if (showArchiveMove)
                      const PopupMenuItem(
                          value: 'archive_move',
                          child: ListTile(
                              leading: Icon(Icons.inventory_2),
                              title: Text('نقل للأرشيف'))),
                    if (showArchiveOpen)
                      const PopupMenuItem(
                          value: 'archive_open',
                          child: ListTile(
                              leading: Icon(Icons.inventory_2_outlined),
                              title: Text('فتح الأرشيف'))),
                    const PopupMenuItem(
                        value: 'sort',
                        child: ListTile(
                            leading: Icon(Icons.sort), title: Text('الترتيب'))),
                    // ─── مسح الكل: Super Admin فقط ───
                    if (isSuperAdmin)
                      const PopupMenuItem(
                          value: 'clear',
                          child: ListTile(
                              leading:
                                  Icon(Icons.delete_sweep, color: Colors.red),
                              title: Text('مسح الكل',
                                  style: TextStyle(color: Colors.red)))),
                  ],
                );
              },
            )
          else
            // حالة fallback قبل تحميل صندوق العمال
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: appBarIconColor),
              tooltip: "خيارات التقارير",
              onSelected: (value) async {
                if (value == 'search') {
                  setState(() => _isSearching = true);
                } else if (value == 'filter') {
                  _showDateFilterDialog();
                } else if (value == 'sort') {
                  _showSortSheet();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'search',
                    child: ListTile(
                        leading: Icon(Icons.search), title: Text('بحث'))),
                const PopupMenuItem(
                    value: 'filter',
                    child: ListTile(
                        leading: Icon(Icons.calendar_month),
                        title: Text('تصفية بالتاريخ'))),
                const PopupMenuItem(
                    value: 'sort',
                    child: ListTile(
                        leading: Icon(Icons.sort), title: Text('الترتيب'))),
              ],
            ),
        ],
      ),
      drawer: const AppDrawer(),
      endDrawer: FlexoReportDrawer(department: widget.department ?? 'flexo'),
      body: ValueListenableBuilder(
        valueListenable: _productionReportBox!.listenable(),
        builder: (context, Box box, _) {
          // ✅ FIX: استمع أيضاً لـ flexo_live_sessions حتى يتحدث isLiveSessionsEmpty فوراً
          if (!Hive.isBoxOpen('flexo_live_sessions')) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<Box<LiveSession>>(
            valueListenable:
                Hive.box<LiveSession>('flexo_live_sessions').listenable(),
            builder: (context, liveSessionsBox, _) {
              final isLiveSessionsEmpty = liveSessionsBox.isEmpty;
              final allRecords =
                  _filterAndSortRecords(box, _searchQuery, _sortDescending);
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ActiveSessionsDashboard(
                      department: widget.department,
                      onFinishSession: (session) => _finishSession(session),
                      onCancelSession: (session) =>
                          _cancelSession(session), // ✅ إضافة دالة الإلغاء
                    ),
                  ),
                  if (box.isEmpty && isLiveSessionsEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text("🚫 لا يوجد تقارير أو جلسات نشطة")),
                    ),
                  if (box.isNotEmpty || !isLiveSessionsEmpty) ...[
                    SliverToBoxAdapter(
                      child: _buildSummaryBar(allRecords.length),
                    ),
                    if (_selectedDate != null)
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          color: Colors.blue.withValues(alpha: 0.1),
                          child: Row(
                            children: [
                              const Icon(Icons.filter_list,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text("تصفية بتاريخ: $_selectedDate",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue)),
                              const Spacer(),
                              TextButton(
                                  onPressed: () =>
                                      setState(() => _selectedDate = null),
                                  child: const Text("إلغاء"))
                            ],
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildReportCard(allRecords[index]);
                          },
                          childCount: allRecords.length,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: _workersBox == null
          ? null
          : ValueListenableBuilder<Box<Worker>>(
              valueListenable: _workersBox!.listenable(),
              builder: (context, _, __) {
                // فحص RBAC ديناميكي بناءً على قسم التقرير (فلكسو أو خط الإنتاج)
                final dept = widget.department ?? 'flexo';
                if (!AuthHelper.currentUserCanManageProduction(
                    dept, 'canAdd')) {
                  return const SizedBox.shrink();
                }
                return FloatingActionButton.extended(
                  onPressed: () {
                    final isSuperAdmin = PermissionHelper.isSuperAdmin;
                    if (isSuperAdmin) {
                      _showProductionOptionsSheet();
                    } else {
                      final cw = PermissionHelper.currentWorker;
                      final cDept = cw?.department ?? '';
                      // التوجيه المباشر بناءً على قسم العامل
                      if (cDept == 'flexo') {
                        _showStartSessionDialog();
                      } else if (cDept == 'production_line') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StartProductionSessionScreen(),
                          ),
                        );
                      } else {
                        // للأقسام الأخرى مثل التكسير يتم إظهار الخيارات
                        _showProductionOptionsSheet();
                      }
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('بدء إنتاج', style: TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
    );
  }

  Widget _buildSummaryBar(int totalReports) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            '$totalReports تقرير مسجل',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(MapEntry<dynamic, Map<String, dynamic>> entry) {
    final key = entry.key;
    final record = entry.value;

    final mName =
        (record['machineName'] ?? record['machine_name'])?.toString() ?? '';
    final tName =
        (record['technicianName'] ?? record['technician_name'])?.toString() ??
            '';
    final downtimeStart = record['downtimeStart'] ?? record['downtime_start'];
    final downtimeEnd = record['downtimeEnd'] ?? record['downtime_end'];
    final rawTotalDowntime = record['totalDowntime'];
    final totalDowntime = rawTotalDowntime is num
        ? rawTotalDowntime.toInt()
        : int.tryParse(rawTotalDowntime?.toString() ?? '0') ?? 0;

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
            if (record['formNumber'] != null &&
                record['formNumber'].toString().isNotEmpty)
              _buildInfoRow("📄 رقم الفورمة:", record['formNumber'].toString()),
            if ((record['startTime'] != null &&
                    record['startTime'].toString().isNotEmpty) ||
                (record['endTime'] != null &&
                    record['endTime'].toString().isNotEmpty))
              _buildInfoRow("🕒 وقت التشغيل:",
                  "${record['startTime'] ?? '--:--'} إلى ${record['endTime'] ?? '--:--'}"),
            _buildDimensionsText(record['dimensions'],
                isSheet: record['isSheet'] ?? false),
            _buildQuantityText(record['quantity']),
            Builder(
              builder: (context) {
                final dims = record['dimensions'] is Map
                    ? record['dimensions'] as Map
                    : {};
                final w =
                    record['weight'] ?? record['weight_tons'] ?? dims['weight'];
                final double weightVal = w != null
                    ? (w is num
                        ? w.toDouble()
                        : (double.tryParse(w.toString()) ?? 0.0))
                    : 0.0;
                if (weightVal <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Text("⚖️ الوزن: ",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.teal)),
                      Text("$weightVal طن",
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              },
            ),
            Builder(
              builder: (context) {
                final dims = record['dimensions'] is Map
                    ? record['dimensions'] as Map
                    : {};
                final rawLayers = record['paperLayers'] ??
                    record['paper_layers'] ??
                    dims['paperLayers'] ??
                    dims['paper_layers'];
                final List<String> layers = [];
                if (rawLayers is List) {
                  layers.addAll(rawLayers
                      .map((e) => e.toString().trim())
                      .where((e) => e.isNotEmpty));
                }
                if (layers.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("📜 طبقات الورق:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.brown)),
                      const SizedBox(height: 2),
                      Text(layers.join('  |  '),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              },
            ),
            if (widget.department != 'production_line' &&
                widget.department != 'crushing' &&
                record['department'] != 'crushing')
              _buildColorsList(record['colors'] ?? []),
            if (record['lineWaste'] != null || record['printWaste'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Text("📉 الهالك: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text((widget.department == 'production_line' ||
                            widget.department == 'crushing' ||
                            record['department'] == 'crushing')
                        ? "${record['lineWaste'] ?? 0}"
                        : "إنتاج: ${record['lineWaste'] ?? 0} | طباعة: ${record['printWaste'] ?? 0}"),
                  ],
                ),
              ),
            if (mName.isNotEmpty)
              _buildInfoRowWithIcon(Icons.settings, "الماكينة:", mName),
            if (tName.isNotEmpty)
              _buildInfoRowWithIcon(Icons.person, "الفني المسؤول:", tName),
            if (downtimeDisplay.trim().isNotEmpty)
              _buildInfoRowWithIcon(
                  Icons.timer_off, "وقت الأعطال:", downtimeDisplay.trim()),
            _buildNotesText(record['notes']),
            const SizedBox(height: 12),
            if (_workersBox != null)
              ValueListenableBuilder<Box<Worker>>(
                valueListenable: _workersBox!.listenable(),
                builder: (context, _, __) {
                  // فحص RBAC ديناميكي: يستخدم قسم التقرير نفسه (مخزّن في record['department'])
                  // هذا يجعل الفحص متوافقاً تلقائياً إذا كانت الشاشة مشتركة بين القسمين
                  final reportDept = record['department']?.toString() ??
                      (widget.department ?? 'flexo');
                  final canEdit = AuthHelper.currentUserCanManageProduction(
                      reportDept, 'canEdit');
                  final canDelete = AuthHelper.currentUserCanManageProduction(
                      reportDept, 'canDelete');
                  if (!canEdit && !canDelete) return const SizedBox.shrink();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canEdit)
                        IconButton(
                          onPressed: () => _editReport(key, record),
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: "تعديل",
                        ),
                      if (canDelete)
                        IconButton(
                          onPressed: () => _deleteSingleReport(key, record),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: "حذف",
                        ),
                    ],
                  );
                },
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
        .map((e) {
          final val = e.value;
          Map<String, dynamic> r;
          if (val is Map) {
            r = Map<String, dynamic>.from(val);
          } else if (val is DieCuttingProductionReport) {
            r = {
              'sync_id': val.id,
              'id': val.id,
              'date': val.reportDate.toIso8601String().split('T')[0],
              'clientName': val.customerName,
              'product': val.itemName,
              'productCode': val.itemCode,
              'formNumber': val.formNumber,
              'orderNumber': val.workOrder,
              'machineName': val.machineName,
              'technicianName': val.technicianName,
              'quantity': val.productionQuantity,
              'lineWaste': val.wasteQuantity,
              'notes': val.notes,
              'department': widget.department ?? 'die_cutting', 
            };
            if (val.runTimeStart != null) r['startTime'] = "${val.runTimeStart!.hour.toString().padLeft(2, '0')}:${val.runTimeStart!.minute.toString().padLeft(2, '0')}";
            if (val.runTimeEnd != null) r['endTime'] = "${val.runTimeEnd!.hour.toString().padLeft(2, '0')}:${val.runTimeEnd!.minute.toString().padLeft(2, '0')}";
            if (val.downtimeStart != null) r['downtimeStart'] = "${val.downtimeStart!.hour.toString().padLeft(2, '0')}:${val.downtimeStart!.minute.toString().padLeft(2, '0')}";
            if (val.downtimeEnd != null) r['downtimeEnd'] = "${val.downtimeEnd!.hour.toString().padLeft(2, '0')}:${val.downtimeEnd!.minute.toString().padLeft(2, '0')}";
          } else {
            try {
              r = (val as dynamic).toJson();
              r['clientName'] ??= r['client_name'];
              r['product'] ??= r['product_name'];
              r['productCode'] ??= r['product_code'];
              r['orderNumber'] ??= r['order_number'];
              r['formNumber'] ??= r['form_number'];
              r['machineName'] ??= r['machine_name'];
              r['technicianName'] ??= r['technician_name'];
              r['startTime'] ??= r['start_time'];
              r['endTime'] ??= r['end_time'];
              r['totalDowntime'] ??= r['total_downtime'];
            } catch (_) {
              r = {};
            }
          }
          return MapEntry(e.key, r);
        })
        .where((e) {
          final r = e.value;
          final dept = r['department']?.toString() ?? 'flexo';
          final targetDept = widget.department ?? 'flexo';
          // Relax department filter if they match the die cutting group
          final bool isDieCuttingGroup = (dept == 'crushing' || dept == 'die_cutting') && (targetDept == 'crushing' || targetDept == 'die_cutting');
          if (dept != targetDept && !isDieCuttingGroup) return false;
          
          final q = query.toLowerCase();
          return (r['clientName']?.toString() ?? '')
                  .toLowerCase()
                  .contains(q) ||
              (r['product']?.toString() ?? '').toLowerCase().contains(q);
        })
        .toList();

    entries.sort((a, b) {
      final dateAStr = a.value['date']?.toString() ?? '2000-01-01';
      final dateBStr = b.value['date']?.toString() ?? '2000-01-01';
      final dateA = DateTime.tryParse(dateAStr) ?? DateTime(2000);
      final dateB = DateTime.tryParse(dateBStr) ?? DateTime(2000);

      // الفرز الأساسي: التاريخ (الأحدث أولاً أو العكس حسب اختيار المستخدم)
      final int dateCompare =
          descending ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
      if (dateCompare != 0) return dateCompare;

      // الفرز الثانوي: وقت الانتهاء (endTime) داخل نفس اليوم — الأحدث أولاً دائماً
      // endTime مخزّن كـ "HH:mm" — المقارنة النصية تعمل بشكل صحيح لهذا الفورمات
      final endTimeA = a.value['endTime']?.toString() ?? '';
      final endTimeB = b.value['endTime']?.toString() ?? '';
      return endTimeB.compareTo(endTimeA);
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(l, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(v))
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
        builder: (c) => FlexoProductionReportForm(
            initialData: data,
            department: widget.department,
            onSave: (r) async {
              // FIX: UUID حقيقي بدلاً من millisecondsSinceEpoch
              final syncId = const Uuid().v4();
              r['sync_id'] = syncId;
              r['id'] = syncId; // لحماية التوافق مع الكود القديم

              final String tableName = (widget.department == 'crushing' || widget.department == 'die_cutting') 
                  ? 'die_cutting_production_reports' 
                  : 'flexo_production_reports';

              if (tableName == 'die_cutting_production_reports') {
                final report = DieCuttingProductionReport(
                  id: syncId,
                  machineName: r['machineName']?.toString() ?? '',
                  technicianName: r['technicianName']?.toString() ?? '',
                  reportDate: DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now(),
                  customerName: r['clientName']?.toString() ?? '',
                  itemName: r['product']?.toString() ?? '',
                  itemCode: r['productCode']?.toString() ?? '',
                  formNumber: r['formNumber']?.toString() ?? '',
                  workOrder: r['orderNumber']?.toString() ?? '',
                  runTimeStart: _parseTimeForDieCutting(r['date']?.toString(), r['startTime']?.toString()),
                  runTimeEnd: _parseTimeForDieCutting(r['date']?.toString(), r['endTime']?.toString()),
                  downtimeStart: _parseTimeForDieCutting(r['date']?.toString(), r['downtimeStart']?.toString()),
                  downtimeEnd: _parseTimeForDieCutting(r['date']?.toString(), r['downtimeEnd']?.toString()),
                  productionQuantity: double.tryParse(r['quantity']?.toString() ?? '0') ?? 0.0,
                  wasteQuantity: double.tryParse(r['lineWaste']?.toString() ?? '0') ?? 0.0,
                  notes: r['notes']?.toString(),
                );
                await _productionReportBox!.put(syncId, report);
                SyncService.instance.pushToQueue(tableName, report.toJson());
              } else {
                final reportObj = FlexoProductionReport.fromJson(r);
                await _productionReportBox!.put(syncId, reportObj);
                SyncService.instance.pushToQueue(tableName, reportObj.toJson());
              }
              if (c.mounted) Navigator.pop(c);
            }));
  }

  void _editReport(key, record) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (c) => FlexoProductionReportForm(
            initialData: record,
            reportKey: key.toString(),
            department: widget.department,
            onSave: (r) async {
              // إعادة استخدام الـ sync_id الأصلي — لا نغيره عند التعديل
              final existingSyncId = record['sync_id']?.toString() ??
                  record['id']?.toString() ??
                  const Uuid().v4();
              r['sync_id'] = existingSyncId;
              r['id'] = existingSyncId;

              final String tableName = (widget.department == 'crushing' || widget.department == 'die_cutting') 
                  ? 'die_cutting_production_reports' 
                  : (widget.department == 'production_line' ? 'line_production_reports' : 'flexo_production_reports');

              if (tableName == 'die_cutting_production_reports') {
                final report = DieCuttingProductionReport(
                  id: existingSyncId,
                  machineName: r['machineName']?.toString() ?? '',
                  technicianName: r['technicianName']?.toString() ?? '',
                  reportDate: DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now(),
                  customerName: r['clientName']?.toString() ?? '',
                  itemName: r['product']?.toString() ?? '',
                  itemCode: r['productCode']?.toString() ?? '',
                  formNumber: r['formNumber']?.toString() ?? '',
                  workOrder: r['orderNumber']?.toString() ?? '',
                  runTimeStart: _parseTimeForDieCutting(r['date']?.toString(), r['startTime']?.toString()),
                  runTimeEnd: _parseTimeForDieCutting(r['date']?.toString(), r['endTime']?.toString()),
                  downtimeStart: _parseTimeForDieCutting(r['date']?.toString(), r['downtimeStart']?.toString()),
                  downtimeEnd: _parseTimeForDieCutting(r['date']?.toString(), r['downtimeEnd']?.toString()),
                  productionQuantity: double.tryParse(r['quantity']?.toString() ?? '0') ?? 0.0,
                  wasteQuantity: double.tryParse(r['lineWaste']?.toString() ?? '0') ?? 0.0,
                  notes: r['notes']?.toString(),
                );
                await _productionReportBox!.put(existingSyncId, report);
                SyncService.instance.pushToQueue(tableName, report.toJson());
              } else {
                final reportObj = FlexoProductionReport.fromJson(r);
                await _productionReportBox!.put(existingSyncId, reportObj);
                SyncService.instance.pushToQueue(tableName, reportObj.toJson());
              }
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
      builder: (context) => StartSessionDialog(department: widget.department ?? 'flexo'),
    );
  }

  // ─── BottomSheet خيارات بدء الإنتاج (الـ FAB) ─────────────────────────────────
  void _showProductionOptionsSheet() {
    final dept = widget.department ?? 'flexo';
    final isProductionLine = dept == 'production_line';
    final isDieCutting = dept == 'crushing' || dept == 'die_cutting';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final isDark = theme.brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
        final subtitleColor =
            isDark ? Colors.grey.shade400 : Colors.grey.shade600;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── مقبض ─────────────────────────────────────────────────
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ─── العنوان ───────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isProductionLine
                              ? Colors.green.shade700
                              : isDieCutting
                                  ? Colors.purple.shade700
                                  : Colors.blue.shade700)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isProductionLine ? Icons.factory : isDieCutting ? Icons.content_cut : Icons.precision_manufacturing,
                      color: isProductionLine
                          ? Colors.green.shade700
                          : isDieCutting
                              ? Colors.purple.shade700
                              : Colors.blue.shade700,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isProductionLine
                        ? 'إضافة أوردر — خط الإنتاج'
                        : isDieCutting
                            ? 'إضافة أوردر — التكسير'
                            : 'إضافة أوردر — فلكسو',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ─── الخيار الأول: بدء جلسة حية ─────────────────────────────
              _buildOptionTile(
                context: sheetCtx,
                icon: Icons.play_circle_filled_rounded,
                iconColor: Colors.green.shade600,
                bgColor: Colors.green.shade600.withValues(alpha: 0.10),
                title: 'بدء تشغيل 🚀',
                subtitle: 'تشغيل المؤقت وبدء العمل الآن.',
                isDark: isDark,
                subtitleColor: subtitleColor,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  if (isProductionLine) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StartProductionSessionScreen(),
                      ),
                    );
                  } else {
                    _showStartSessionDialog();
                  }
                },
              ),

              const SizedBox(height: 12),

              // ─── الخيار الثاني: إدخال تقرير يدوي ───────────────────────
              _buildOptionTile(
                context: sheetCtx,
                icon: Icons.edit_note_rounded,
                iconColor: Colors.orange.shade700,
                bgColor: Colors.orange.shade700.withValues(alpha: 0.10),
                title: 'إدخال تقرير يدوي (منتهي) 📝',
                subtitle: 'تسجيل بيانات أوردر تم الانتهاء منه بالفعل.',
                isDark: isDark,
                subtitleColor: subtitleColor,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showAddReportDialog();
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─── بلاط خيار من الـ BottomSheet ───────────────────────────────────────
  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: subtitleColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _finishSession(LiveSession session) {
    // ─── حماية #1: منع تكرار الاستدعاء عند الضغطة المزدوجة ───
    if (_isFinishingSession) {
      debugPrint(
          '⏭️ _finishSession: تم تجاهل الضغطة المكررة — الجلسة جارٍ إنهاؤها.');
      return;
    }
    // ─── حماية #2: الجلسة يجب أن تكون موجودة في Hive ───
    if (!session.isInBox) {
      debugPrint(
          '⚠️ _finishSession: الجلسة غير موجودة في Hive (ربما تم حذفها مسبقاً). تم الخروج.');
      return;
    }

    _isFinishingSession = true;
    debugPrint('🟢 _finishSession: بدء إنهاء جلسة: ${session.machineName}');

    final now = ServerTimeService.nowLocal;
    final startLocal = session.startTime.toLocal();
    final startTimeStr =
        "${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}";
    final endTimeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // إغلاق آخر فترة عطل مفتوحة إن وجدت
    if (!session.isRunning && session.downtimeIntervals.isNotEmpty) {
      final last = session.downtimeIntervals.last;
      last.end ??= ServerTimeService.nowUtc;
    }

    // تحديد أوقات العطل (أول بداية → آخر نهاية)
    String dStart = "";
    String dEnd = "";
    if (session.downtimeIntervals.isNotEmpty) {
      final firstStart = session.downtimeIntervals.first.start.toLocal();
      final lastEnd =
          (session.downtimeIntervals.last.end ?? ServerTimeService.nowUtc)
              .toLocal();
      dStart =
          "${firstStart.hour.toString().padLeft(2, '0')}:${firstStart.minute.toString().padLeft(2, '0')}";
      dEnd =
          "${lastEnd.hour.toString().padLeft(2, '0')}:${lastEnd.minute.toString().padLeft(2, '0')}";
    }

    final totalDowntimeMin = session.totalDowntime.inMinutes;
    final sessionId = session.id; // نحتفظ بالـ id قبل الحذف

    final initialData = {
      'date':
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      'clientName': session.clientName,
      'product': session.productName,
      'productCode': session.productCode,
      'formNumber': session.formNumber ?? '',
      'orderNumber': session.orderNumber,
      'startTime': startTimeStr,
      'endTime': endTimeStr,
      'downtimeStart': dStart,
      'downtimeEnd': dEnd,
      'totalDowntime': totalDowntimeMin,
      'machineName': session.machineName,
      'technicianName': session.technicianName,
      'dimensions': {
        ...?session.dimensions,
        'weight': (session.dimensions != null &&
                session.dimensions!['weight'] != null)
            ? (double.tryParse(session.dimensions!['weight'].toString()) ?? 0.0)
            : 0.0,
        'paperLayers': session.paperLayers ?? [],
      },
      'weight': (session.dimensions != null &&
              session.dimensions!['weight'] != null)
          ? (double.tryParse(session.dimensions!['weight'].toString()) ?? 0.0)
          : 0.0,
      'shift': session.shift,
      'isSheet': session.isSheet,
      'imagePaths': session.imagePaths,
      'department': session.department ?? widget.department ?? 'flexo',
      'paperLayers': session.paperLayers ?? [],
      'paper_layers': session.paperLayers ?? [],
      'notes': "",
    };

    // ─── الترتيب الجديد: فتح نموذج التقرير أولاً وحذف الجلسة فقط عند الحفظ بنجاح ───
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      builder: (c) => FlexoProductionReportForm(
        initialData: initialData,
        department: session.department ?? widget.department,
        onSave: (r) async {
          try {
            final syncId = const Uuid().v4();
            r['sync_id'] = syncId;
            r['id'] = syncId;

            final String tableName = (session.department == 'crushing' || session.department == 'die_cutting' || widget.department == 'crushing' || widget.department == 'die_cutting') 
                ? 'die_cutting_production_reports' 
                : ((session.department == 'production_line' || widget.department == 'production_line') ? 'line_production_reports' : 'flexo_production_reports');

            if (tableName == 'die_cutting_production_reports') {
                final report = DieCuttingProductionReport(
                  id: syncId,
                  machineName: r['machineName']?.toString() ?? '',
                  technicianName: r['technicianName']?.toString() ?? '',
                  reportDate: DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now(),
                  customerName: r['clientName']?.toString() ?? '',
                  itemName: r['product']?.toString() ?? '',
                  itemCode: r['productCode']?.toString() ?? '',
                  formNumber: r['formNumber']?.toString() ?? '',
                  workOrder: r['orderNumber']?.toString() ?? '',
                  runTimeStart: _parseTimeForDieCutting(r['date']?.toString(), r['startTime']?.toString()),
                  runTimeEnd: _parseTimeForDieCutting(r['date']?.toString(), r['endTime']?.toString()),
                  downtimeStart: _parseTimeForDieCutting(r['date']?.toString(), r['downtimeStart']?.toString()),
                  downtimeEnd: _parseTimeForDieCutting(r['date']?.toString(), r['downtimeEnd']?.toString()),
                  productionQuantity: double.tryParse(r['quantity']?.toString() ?? '0') ?? 0.0,
                  wasteQuantity: double.tryParse(r['lineWaste']?.toString() ?? '0') ?? 0.0,
                  notes: r['notes']?.toString(),
                );
                // حفظ محلي بمفتاح ثابت لمنع التكرار
                await _productionReportBox!.put(syncId, report);
                SyncService.instance.pushToQueue(tableName, report.toJson());
            } else {
                final reportObj = FlexoProductionReport.fromJson(r);
                // حفظ محلي بمفتاح ثابت لمنع التكرار
                await _productionReportBox!.put(syncId, reportObj);
                SyncService.instance.pushToQueue(tableName, reportObj.toJson());
            }

            debugPrint(
                '✅ _finishSession: تم حفظ التقرير ورفعه للمزامنة (sync_id=$syncId)');

            // ─── حذف الجلسة بعد نجاح الحفظ ───
            await session.delete();
            SyncService.instance.pushToQueue(
              'live_sessions',
              {'sync_id': sessionId, 'id': sessionId},
              operation: 'delete',
            );
            debugPrint(
                '✅ _finishSession: تم حذف الجلسة الجارية بعد نجاح الحفظ (id=$sessionId)');

            if (c.mounted) Navigator.of(c).pop();
          } catch (saveError) {
            debugPrint(
                '❌ _finishSession.onSave: فشل حفظ التقرير: $saveError');
          }
        },
      ),
    ).whenComplete(() {
      // تحرير الحارس بعد إغلاق النموذج (سواء بالحفظ أو بالإغلاق)
      if (mounted) {
        _isFinishingSession = false;
        debugPrint('🔓 _finishSession: تم تحرير الحارس. جاهز لجلسة جديدة.');
      }
    });
  }

  void _cancelSession(LiveSession session) {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "إلغاء الجلسة",
      content:
          "هل أنت متأكد من إلغاء هذه الجلسة؟ سيتم حذف جميع البيانات المؤقتة الخاصة بها نهائياً.",
      confirmLabel: "إلغاء الجلسة",
      onConfirm: () async {
        final sessionId = session.id;
        await session.delete(); // حذف مباشر من Hive دون ترحيل
        SyncService.instance.pushToQueue(
          'live_sessions',
          {'sync_id': sessionId, 'id': sessionId},
          operation: 'delete',
        );

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

