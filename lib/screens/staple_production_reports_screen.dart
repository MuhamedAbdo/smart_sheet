import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/widgets/smart_sheet_card.dart';
import 'package:smart_sheet/screens/add_staple_production_report_screen.dart';
import 'package:smart_sheet/screens/start_staple_job_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/day_schedule.dart';
import 'package:smart_sheet/widgets/active_sessions_dashboard.dart';
import 'package:smart_sheet/models/live_session.dart';

class StapleProductionReportsScreen extends StatefulWidget {
  const StapleProductionReportsScreen({super.key});

  @override
  State<StapleProductionReportsScreen> createState() => _StapleProductionReportsScreenState();
}

class _StapleProductionReportsScreenState extends State<StapleProductionReportsScreen> {
  String _selectedShift = 'الكل';

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

  void _finishSession(LiveSession session) {
    Hive.box<LiveSession>('flexo_live_sessions').delete(session.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddStapleProductionReportScreen(),
      ),
    );
  }

  void _cancelSession(LiveSession session) {
    Hive.box<LiveSession>('flexo_live_sessions').delete(session.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إلغاء الجلسة بنجاح'), backgroundColor: Colors.red),
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
        title: const Text(
          'تقرير الإنتاج - الدبوس',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
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
      ),
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
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('staple_production_reports')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حدث خطأ أثناء جلب البيانات',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    );
                  }

                  final allReports = snapshot.data ?? [];
                  
                  final reports = _selectedShift == 'الكل'
                      ? allReports
                      : allReports.where((r) => r['shift_name'] == _selectedShift).toList();

                  return Column(
                    children: [
                      ActiveSessionsDashboard(
                        department: 'staples',
                        onFinishSession: _finishSession,
                        onCancelSession: _cancelSession,
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
                                  'إجمالي التقارير: ${reports.length}',
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
                        child: reports.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد تقارير مطابقة',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: reports.length,
                                itemBuilder: (context, index) {
                                  final report = reports[index];
                                  
                                  final dimensions = report['dimensions'] as Map<String, dynamic>?;
                                  final length = dimensions?['length'] ?? 0;
                                  final width = dimensions?['width'] ?? 0;
                                  final height = dimensions?['height'] ?? 0;
                                  final crewMembers = report['crew_members'] as List<dynamic>? ?? [];
                                  final notes = report['notes']?.toString().trim() ?? '';
                                  final status = report['status'] ?? 'معتمد';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: SmartSheetCard(
                                      padding: const EdgeInsets.all(0.0),
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
                                                      report['report_date'] ?? '-',
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
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                  tooltip: 'حذف التقرير',
                                                  onPressed: () {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('سيتم تفعيل الحذف لاحقاً')),
                                                    );
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                                                  tooltip: 'تعديل التقرير',
                                                  onPressed: () {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('سيتم تفعيل التعديل لاحقاً')),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
