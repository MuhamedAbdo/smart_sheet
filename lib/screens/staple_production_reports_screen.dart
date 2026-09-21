import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/widgets/smart_sheet_card.dart';
import 'package:smart_sheet/screens/add_staple_production_report_screen.dart';
import 'package:smart_sheet/screens/start_staple_job_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/day_schedule.dart';
import 'package:smart_sheet/widgets/active_sessions_dashboard.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:smart_sheet/utils/archive_rbac_logic.dart';
import 'package:smart_sheet/utils/auth_helper.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/staple_production_report.dart';
import 'package:smart_sheet/screens/staple_archived_reports_screen.dart' as smart_sheet;

class StapleProductionReportsScreen extends StatefulWidget {
  const StapleProductionReportsScreen({super.key});

  @override
  State<StapleProductionReportsScreen> createState() => _StapleProductionReportsScreenState();
}

class _StapleProductionReportsScreenState extends State<StapleProductionReportsScreen> {
  Box<StapleProductionReport>? _productionReportBox;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String? _selectedDate;
  bool _sortDescending = true;

  final Set<dynamic> _selectedReportKeys = {};
  bool get _isSelectionMode => _selectedReportKeys.isNotEmpty;

  String _selectedShift = 'الكل';

  @override
  void initState() {
    super.initState();
    _initBoxes();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  Future<void> _initBoxes() async {
    if (!Hive.isBoxOpen('workers')) {
      await Hive.openBox<Worker>('workers');
    }
    if (!Hive.isBoxOpen('staple_production_reports_box')) {
      await Hive.openBox<StapleProductionReport>('staple_production_reports_box');
    }
    if (mounted) {
      setState(() {
        _productionReportBox = Hive.box<StapleProductionReport>('staple_production_reports_box');
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectAll() {
    if (_productionReportBox == null) return;
    setState(() {
      if (_selectedReportKeys.length == _productionReportBox!.length) {
        _selectedReportKeys.clear();
      } else {
        _selectedReportKeys.addAll(_productionReportBox!.keys);
      }
    });
  }

  List<MapEntry<dynamic, Map<String, dynamic>>> _filterAndSortRecords(
      Box box, String query, bool descending, String shiftFilter) {
    var entries = box.toMap().entries.map((e) {
      Map<String, dynamic> record = {};
      if (e.value is StapleProductionReport) {
        record = (e.value as StapleProductionReport).toJson();
      } else if (e.value is Map) {
        record = Map<String, dynamic>.from(e.value);
      }
      return MapEntry(e.key, record);
    }).toList();

    // 1. تصفية بالوردية
    if (shiftFilter != 'الكل') {
      entries = entries.where((e) => e.value['shift_name'] == shiftFilter || e.value['shift'] == shiftFilter).toList();
    }

    // 2. تصفية بالبحث
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      entries = entries.where((e) {
        final r = e.value;
        return (r['customer_name']?.toString().toLowerCase().contains(q) ?? false) ||
            (r['clientName']?.toString().toLowerCase().contains(q) ?? false) ||
            (r['item_name']?.toString().toLowerCase().contains(q) ?? false) ||
            (r['productName']?.toString().toLowerCase().contains(q) ?? false) ||
            (r['item_code']?.toString().toLowerCase().contains(q) ?? false) ||
            (r['itemCode']?.toString().toLowerCase().contains(q) ?? false) ||
            (r['work_order']?.toString().toLowerCase().contains(q) ?? false) ||
            (r['orderNumber']?.toString().toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // 3. تصفية بالتاريخ
    if (_selectedDate != null) {
      entries = entries.where((e) {
        final dateStr = (e.value['report_date'] ?? e.value['date'])?.toString();
        if (dateStr == null) return false;
        return dateStr.startsWith(_selectedDate!);
      }).toList();
    }

    // 4. الترتيب
    entries.sort((a, b) {
      final dA = (a.value['report_date'] ?? a.value['date'])?.toString() ?? '';
      final dB = (b.value['report_date'] ?? b.value['date'])?.toString() ?? '';
      return descending ? dB.compareTo(dA) : dA.compareTo(dB);
    });

    return entries;
  }

  Future<void> _showDateFilterDialog() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.blueAccent),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _selectedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.blue),
              title: const Text('الأحدث أولاً'),
              onTap: () {
                setState(() => _sortDescending = true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.blue),
              title: const Text('الأقدم أولاً'),
              onTap: () {
                setState(() => _sortDescending = false);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
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
        final backup = Map<dynamic, StapleProductionReport>.from(_productionReportBox!.toMap());
        final List<String> listOfIds = [];
        for (var record in backup.values) {
          listOfIds.add(record.id);
        }

        try {
          if (listOfIds.isNotEmpty) {
            await Supabase.instance.client
                .from('staple_production_reports')
                .delete()
                .inFilter('id', listOfIds);
          }
          await _productionReportBox!.clear();
          setState(() { _selectedReportKeys.clear(); });
          
          if (mounted) {
            messenger.clearSnackBars();
            UIUtils.showUndoSnackBar(
              context: context,
              message: "تم مسح جميع التقارير",
              onUndo: () async {
                messenger.clearSnackBars();
                for (var entry in backup.entries) {
                  await _productionReportBox!.put(entry.key, entry.value);
                  SyncService.instance.pushToQueue('staple_production_reports', entry.value.toJson());
                }
              },
            );
          }
        } catch (e) {
          debugPrint("Error clearing reports: $e");
        }
      },
    );
  }

  void _moveToArchive() async {
    if (_productionReportBox == null) return;
    final allEntries = _productionReportBox!.toMap();
    final approvedEntries = allEntries.entries.where((e) {
      return e.value.status == 'approved';
    }).toList();

    if (approvedEntries.isEmpty) {
      UIUtils.showInfoSnackBar(message: "لا توجد تقارير معتمدة لنقلها للأرشيف!", backgroundColor: Colors.orange);
      return;
    }

    UIUtils.showDeleteConfirmation(
      context: context,
      title: "نقل للأرشيف",
      content: "سيتم عمل نسخة من التقارير (${approvedEntries.length}) في الأرشيف مع بقائها هنا. هل تريد الاستمرار؟",
      confirmLabel: "نقل للأرشيف",
      confirmColor: Colors.blueAccent,
      onConfirm: () async {
        if (!Hive.isBoxOpen('stapleArchive')) await Hive.openBox('stapleArchive');
        final archiveBox = Hive.box('stapleArchive');
        
        int count = 0;
        final List<String> listOfIds = [];
        for (var entry in approvedEntries) {
          final id = entry.value.id;
          if (!archiveBox.containsKey(id)) {
            await archiveBox.put(id, entry.value.toJson());
            count++;
          }
          listOfIds.add(id);
        }

        if (listOfIds.isNotEmpty) {
           for (var entry in approvedEntries) {
             SyncService.instance.pushToQueue(
               'staple_archived_reports',
               entry.value.toJson(),
             );
           }
        }

        if (mounted) {
          UIUtils.showInfoSnackBar(message: "تم نقل $count تقرير للأرشيف بنجاح!", backgroundColor: Colors.green);
        }
      },
    );
  }

  List<String> get _shifts {
    try {
      if (!Hive.isBoxOpen('factory_schedule')) return ['الكل', 'الوردية الأولى', 'الوردية الثانية'];
      final scheduleBox = Hive.box<DaySchedule>('factory_schedule');
      String dayName = '';
      final dt = DateTime.now();
      switch (dt.weekday) {
        case DateTime.monday: dayName = 'Monday'; break;
        case DateTime.tuesday: dayName = 'Tuesday'; break;
        case DateTime.wednesday: dayName = 'Wednesday'; break;
        case DateTime.thursday: dayName = 'Thursday'; break;
        case DateTime.friday: dayName = 'Friday'; break;
        case DateTime.saturday: dayName = 'Saturday'; break;
        case DateTime.sunday: dayName = 'Sunday'; break;
      }
      final schedule = scheduleBox.get(dayName);
      if (schedule != null && schedule.isWorkingDay && (schedule.shifts?.isNotEmpty ?? false)) {
        return ['الكل', ...schedule.shifts!.map((s) => s.name)];
      }
    } catch (_) {}
    return ['الكل', 'الوردية الأولى', 'الوردية الثانية'];
  }

  Future<void> _finishSession(LiveSession session) async {
    final now = DateTime.now();
    final startLocal = session.startTime.toLocal();
    final startTimeStr =
        "${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}";
    final endTimeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    if (!session.isRunning && session.downtimeIntervals.isNotEmpty) {
      final last = session.downtimeIntervals.last;
      last.end ??= DateTime.now().toUtc();
    }

    String dStart = "";
    String dEnd = "";
    if (session.downtimeIntervals.isNotEmpty) {
      final firstStart = session.downtimeIntervals.first.start.toLocal();
      final lastEnd =
          (session.downtimeIntervals.last.end ?? DateTime.now().toUtc())
              .toLocal();
      dStart =
          "${firstStart.hour.toString().padLeft(2, '0')}:${firstStart.minute.toString().padLeft(2, '0')}";
      dEnd =
          "${lastEnd.hour.toString().padLeft(2, '0')}:${lastEnd.minute.toString().padLeft(2, '0')}";
    }

    final totalDowntimeMin = session.totalDowntime.inMinutes;

    final initialData = {
      'date': "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      'clientName': session.clientName,
      'productName': session.productName,
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
      'dimensions': session.dimensions,
      'shift': session.shift,
      'department': session.department ?? 'staples',
      'crewMembers': session.crewMembers,
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStapleProductionReportScreen(initialData: initialData),
      ),
    );
    
    if (result == true) {
      Hive.box<LiveSession>('flexo_live_sessions').delete(session.id);
    }
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
        try {
          if (Hive.isBoxOpen('flexo_live_sessions')) {
            await Hive.box<LiveSession>('flexo_live_sessions')
                .delete(sessionId);
          }
          if (Hive.isBoxOpen('live_sessions')) {
            await Hive.box<LiveSession>('live_sessions').delete(sessionId);
          }
        } catch (e) {
          debugPrint('⚠️ فشل حذف الجلسة محلياً: $e');
        }

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

  void _showCrewMembersDialog(List<dynamic> crewMembers) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.people, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text('طاقم العمل (${crewMembers.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: crewMembers.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      crewMembers[index].toString(),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _approveReport(String id) async {
    try {
      await Supabase.instance.client
          .from('staple_production_reports')
          .update({'status': 'approved'})
          .eq('id', id);
      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: 'تم الاعتماد بنجاح',
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الاعتماد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shiftsList = _shifts;
    
    // Ensure selected shift is valid
    if (!shiftsList.contains(_selectedShift)) {
      _selectedShift = shiftsList.first;
    }

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedReportKeys.clear()),
              )
            : Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
        title: _isSelectionMode
            ? Text('تم تحديد ${_selectedReportKeys.length}', style: const TextStyle(fontWeight: FontWeight.bold))
            : _isSearching
                ? Container(
                    height: 40,
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10)),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
                : const Text(
                    'تقرير الإنتاج - الدبوس',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
        centerTitle: !_isSearching && !_isSelectionMode,
        elevation: 1,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'تحديد الكل',
              onPressed: _selectAll,
            ),
            Builder(builder: (context) {
              final canDelete = PermissionHelper.isSuperAdmin ||
                  AuthHelper.currentUserCanManageProduction('staples', 'canDelete');
              if (!canDelete) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.delete_sweep, color: Colors.red.shade400),
                tooltip: 'حذف المحدد',
                onPressed: () async {
                   // _deleteSelectedReports() can be implemented if needed
                },
              );
            }),
          ],
          if (!_isSelectionMode)
            Builder(
              builder: (context) {
                final cw = PermissionHelper.currentWorker;
                final canViewArchive = PermissionHelper.isSuperAdmin || ArchiveRbacService.canRead(cw);
                final canMoveArchive = PermissionHelper.isSuperAdmin || ArchiveRbacService.canAdd(cw, 'staples');
                final canClearAll = PermissionHelper.isSuperAdmin || AuthHelper.currentUserCanManageProduction('staples', 'canDelete');
                    
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: "خيارات التقارير",
                  onSelected: (value) {
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
                          builder: (_) => const smart_sheet.StapleArchivedReportsScreen(),
                        ),
                      );
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
                            leading: Icon(Icons.search),
                            title: Text('بحث'))),
                    const PopupMenuItem(
                        value: 'filter',
                        child: ListTile(
                            leading: Icon(Icons.calendar_month),
                            title: Text('تصفية بالتاريخ'))),
                    if (canMoveArchive)
                      const PopupMenuItem(
                          value: 'archive_move',
                          child: ListTile(
                              leading: Icon(Icons.inventory_2),
                              title: Text('نقل للأرشيف'))),
                    if (canViewArchive)
                      const PopupMenuItem(
                        value: 'archive_open',
                        child: ListTile(
                          leading: Icon(Icons.inventory_2_outlined),
                          title: Text('فتح الأرشيف'),
                        ),
                      ),
                    const PopupMenuItem(
                        value: 'sort',
                        child: ListTile(
                            leading: Icon(Icons.sort),
                            title: Text('الترتيب'))),
                    if (canClearAll)
                      const PopupMenuItem(
                          value: 'clear',
                          child: ListTile(
                              leading: Icon(Icons.delete_sweep, color: Colors.red),
                              title: Text('مسح الكل', style: TextStyle(color: Colors.red)))),
                  ],
                );
              }
            ),
        ],
      ),
      floatingActionButton: (PermissionHelper.isSuperAdmin || ((PermissionHelper.currentWorker?.department == 'staple' || PermissionHelper.currentWorker?.department == 'staples') && PermissionHelper.currentWorker?.canAdd == true))
          ? FloatingActionButton.extended(
              onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
            ),
            builder: (BuildContext context) {
              final bottomSheetTheme = Theme.of(context);
              final isDarkMode = bottomSheetTheme.brightness == Brightness.dark;

              return Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: bottomSheetTheme.colorScheme.primary, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'إضافة أوردر — الدبوس',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 0,
                        color: isDarkMode ? const Color(0xFF1E293B) : Colors.blue.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.rocket_launch, color: Colors.white),
                          ),
                          title: const Text('بدء تشغيل 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('تشغيل المؤقت وبدء العمل الآن.'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StartStapleJobScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: isDarkMode ? const Color(0xFF1E293B) : Colors.green.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade600,
                            child: const Icon(Icons.edit_document, color: Colors.white),
                          ),
                          title: const Text('إدخال تقرير يدوي (منتهي) 📝', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('تسجيل بيانات أوردر تم الانتهاء منه بالفعل.'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddStapleProductionReportScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('بدء إنتاج', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ) : null,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFF0F172A) 
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: _productionReportBox == null
                  ? const Center(child: CircularProgressIndicator())
                  : ValueListenableBuilder(
                      valueListenable: _productionReportBox!.listenable(),
                      builder: (context, Box box, _) {
                        final allRecords = _filterAndSortRecords(
                            box, _searchQuery, _sortDescending, _selectedShift);

                        return Column(
                          children: [
                            ActiveSessionsDashboard(
                              department: 'staples',
                              onFinishSession: _finishSession,
                              onCancelSession: _cancelSession,
                            ),
                            if (_selectedDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                                border: Border(bottom: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.2))),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt_long, color: Colors.blueAccent),
                                      const SizedBox(width: 8),
                                      Text(
                                        'إجمالي التقارير: ${allRecords.length}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedShift,
                                        items: shiftsList.map((String shift) {
                                          return DropdownMenuItem<String>(
                                            value: shift,
                                            child: Text(shift, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _selectedShift = newValue;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            Expanded(
                              child: allRecords.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'لا توجد تقارير مطابقة',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16.0),
                                      itemCount: allRecords.length,
                                      itemBuilder: (context, index) {
                                        final entry = allRecords[index];
                                        final key = entry.key;
                                        final report = entry.value;
                                        
                                        final dimensions = report['dimensions'] as Map<String, dynamic>?;
                                        final length = dimensions?['length'] ?? 0;
                                        final width = dimensions?['width'] ?? 0;
                                        final height = dimensions?['height'] ?? 0;
                                        final crewMembers = report['crew_members'] as List<dynamic>? ?? report['crewMembers'] as List<dynamic>? ?? [];
                                        final notes = report['notes']?.toString().trim() ?? '';
                                        final rawStatus = report['status']?.toString() ?? 'approved';
                                        final status = rawStatus == 'approved' ? 'معتمد' : (rawStatus == 'pending' ? 'قيد المراجعة' : rawStatus);
                                        final isSelected = _selectedReportKeys.contains(key);

                                        return GestureDetector(
                                          onLongPress: () {
                                            setState(() {
                                              _selectedReportKeys.add(key);
                                            });
                                          },
                                          onTap: _isSelectionMode
                                              ? () {
                                                  setState(() {
                                                    if (_selectedReportKeys.contains(key)) {
                                                      _selectedReportKeys.remove(key);
                                                    } else {
                                                      _selectedReportKeys.add(key);
                                                    }
                                                  });
                                                }
                                              : null,
                                          child: Padding(
                                            padding: const EdgeInsets.only(bottom: 16.0),
                                            child: SmartSheetCard(
                                              padding: const EdgeInsets.all(0.0),
                                              child: Container(
                                                decoration: isSelected
                                                    ? BoxDecoration(
                                                        color: Colors.blue.withValues(alpha: 0.08),
                                                        borderRadius: BorderRadius.circular(15),
                                                        border: Border.all(color: Colors.blue.shade400, width: 2),
                                                      )
                                                    : null,
                                                child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : Colors.blueGrey.shade50,
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      (report['report_date'] != null && report['report_date'].toString().isNotEmpty)
                                                          ? report['report_date'].toString().split('T')[0].split(' ')[0]
                                                          : '-',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: status == 'معتمد' ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: status == 'معتمد' ? Colors.green : Colors.orange),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(
                                                      color: status == 'معتمد' ? Colors.green : Colors.orange,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.person, color: Colors.blueAccent, size: 20),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: RichText(
                                                        text: TextSpan(
                                                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                                                          children: [
                                                            const TextSpan(text: 'العميل: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                                            TextSpan(text: report['customer_name'] ?? '-'),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if (report['work_order'] != null && report['work_order'].toString().isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.blueAccent.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          'أمر: ${report['work_order']}',
                                                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                
                                                Row(
                                                  children: [
                                                    const Icon(Icons.inventory_2, color: Colors.brown, size: 20),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: RichText(
                                                        text: TextSpan(
                                                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                                                          children: [
                                                            const TextSpan(text: 'الصنف: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                                            TextSpan(text: report['item_name'] ?? '-'),
                                                            if (report['item_code'] != null && report['item_code'].toString().isNotEmpty)
                                                              TextSpan(text: '  [ ${report['item_code']} ]', style: const TextStyle(color: Colors.blueGrey)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),

                                                Row(
                                                  children: [
                                                    const Icon(Icons.straighten, color: Colors.orange, size: 20),
                                                    const SizedBox(width: 8),
                                                    RichText(
                                                      text: TextSpan(
                                                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                                                        children: [
                                                          const TextSpan(text: 'المقاس: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          TextSpan(text: '$length / $width / $height', style: const TextStyle(color: Colors.blueGrey)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),

                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                                          const SizedBox(width: 8),
                                                          RichText(
                                                            text: TextSpan(
                                                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                                                              children: [
                                                                const TextSpan(text: 'الكمية: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                                                TextSpan(text: '${report['production_quantity'] ?? 0}'),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.trending_down, color: Colors.redAccent, size: 20),
                                                          const SizedBox(width: 8),
                                                          RichText(
                                                            text: TextSpan(
                                                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                                                              children: [
                                                                const TextSpan(text: 'الهالك: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                                                TextSpan(text: '${report['waste_quantity'] ?? 0}'),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),

                                                Row(
                                                  children: [
                                                    const Icon(Icons.precision_manufacturing, color: Colors.teal, size: 20),
                                                    const SizedBox(width: 8),
                                                    RichText(
                                                      text: TextSpan(
                                                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                                                        children: [
                                                          const TextSpan(text: 'الماكينة: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          TextSpan(text: report['machine_name'] ?? '-'),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),

                                                Row(
                                                  children: [
                                                    const Icon(Icons.engineering, color: Colors.blueGrey, size: 20),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: RichText(
                                                        text: TextSpan(
                                                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                                                          children: [
                                                            const TextSpan(text: 'الفني المسؤول: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                                            TextSpan(text: report['technician_name'] ?? '-'),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),

                                                Row(
                                                  children: [
                                                    const Icon(Icons.groups, color: Colors.indigo, size: 20),
                                                    const SizedBox(width: 8),
                                                    const Text('طاقم العمل: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                    if (crewMembers.isNotEmpty)
                                                      InkWell(
                                                        onTap: () => _showCrewMembersDialog(crewMembers),
                                                        child: Text(
                                                          'عرض (${crewMembers.length} عمال)',
                                                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                                        ),
                                                      )
                                                    else
                                                      const Text('لا يوجد طاقم', style: TextStyle(color: Colors.blueGrey)),
                                                  ],
                                                ),
                                                
                                                if (notes.isNotEmpty) ...[
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border(right: BorderSide(color: Colors.orange.shade300, width: 4)),
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Icon(Icons.notes, size: 16, color: Colors.blueGrey),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            notes,
                                                            style: const TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border(top: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.2))),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: [
                                                if (report['status'] == 'pending' && PermissionHelper.canApproveReports)
                                                  IconButton(
                                                    icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                                    tooltip: 'اعتماد',
                                                    onPressed: () => _approveReport(report['id']),
                                                  ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                  tooltip: 'حذف التقرير',
                                                  onPressed: () {
                                                    UIUtils.showDeleteConfirmation(
                                                      context: context,
                                                      title: 'حذف التقرير',
                                                      content: 'هل أنت متأكد من رغبتك في حذف هذا التقرير؟',
                                                      onConfirm: () async {
                                                        final reportId = report['id'] ?? report['sync_id'];
                                                        if (reportId == null) return;
                                                        
                                                        final originalReport = _productionReportBox!.get(key);
                                                        _productionReportBox!.delete(key);
                                                        
                                                        bool isUndone = false;
                                                        
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: const Text('تم مسح التقرير', style: TextStyle(fontFamily: 'Cairo')),
                                                            action: SnackBarAction(
                                                              label: 'تراجع',
                                                              textColor: Colors.yellow,
                                                              onPressed: () {
                                                                isUndone = true;
                                                                if (originalReport != null) {
                                                                  _productionReportBox!.put(key, originalReport);
                                                                }
                                                              },
                                                            ),
                                                            duration: const Duration(seconds: 5),
                                                          ),
                                                        ).closed.then((reason) {
                                                          if (!isUndone) {
                                                            SyncService.instance.pushToQueue(
                                                              'staple_production_reports',
                                                              {'sync_id': reportId, 'id': reportId},
                                                              operation: 'delete',
                                                            );
                                                          }
                                                        });
                                                      },
                                                    );
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                                                  tooltip: 'تعديل التقرير',
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => AddStapleProductionReportScreen(
                                                          initialData: report,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                 ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
            ),
          ),
        ),
      ),
    );
  }
}
