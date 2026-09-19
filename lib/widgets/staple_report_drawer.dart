import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/staple_production_report.dart';
import 'package:smart_sheet/models/day_schedule.dart';
import 'package:smart_sheet/utils/pdf_export_helper.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'dart:typed_data';

class StapleReportDrawer extends StatefulWidget {
  final String department;
  const StapleReportDrawer({super.key, this.department = 'staples'});

  @override
  State<StapleReportDrawer> createState() => _StapleReportDrawerState();
}

class _StapleReportDrawerState extends State<StapleReportDrawer> {
  String _selectedShift = 'كل الورديات';

  List<String> get _shifts {
    try {
      if (!Hive.isBoxOpen('factory_schedule')) {
        return ['كل الورديات', 'الوردية الأولى', 'الوردية الثانية'];
      }
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
        return ['كل الورديات', ...schedule.shifts!.map((s) => s.name)];
      }
    } catch (_) {}
    return ['كل الورديات', 'الوردية الأولى', 'الوردية الثانية'];
  }

  String _normalizeString(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
            ),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.picture_as_pdf, size: 48, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(height: 12),
                const Text(
                  'تقارير ماكينات الدبوس',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'اختر الوردية',
                labelStyle: TextStyle(color: theme.colorScheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              initialValue: _selectedShift,
              items: _shifts.map((shift) => DropdownMenuItem(value: shift, child: Text(shift))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedShift = val);
              },
            ),
          ),
          
          const Divider(height: 1),
          
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<FlexoMachine>('flexo_machines').listenable(),
              builder: (context, Box<FlexoMachine> box, _) {
                final machines = FlexoMachine.getMachinesForDepartment(widget.department);
                
                if (machines.isEmpty) {
                  return const Center(child: Text('لا توجد ماكينات مسجلة'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: machines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final mName = machines[index].name;
                    return ExpansionTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      collapsedBackgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      leading: Icon(Icons.settings, color: theme.colorScheme.primary),
                      title: Text(mName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      children: [
                        _buildReportTile(
                          context,
                          label: "عرض تقرير الإنتاج",
                          icon: Icons.picture_as_pdf,
                          color: theme.colorScheme.primary,
                          onTap: () => _handlePdfAction(context, mName, isSave: false),
                        ),
                        _buildReportTile(
                          context,
                          label: "حفظ تقرير الإنتاج",
                          icon: Icons.download,
                          color: Colors.green,
                          onTap: () => _handlePdfAction(context, mName, isSave: true),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTile(BuildContext context, {required String label, required IconData icon, required VoidCallback onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.blue, size: 18),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _handlePdfAction(BuildContext context, String machineName, {required bool isSave}) async {
    const boxName = 'staple_production_reports_box';
    final box = Hive.isBoxOpen(boxName) 
        ? Hive.box<StapleProductionReport>(boxName)
        : await Hive.openBox<StapleProductionReport>(boxName);

    bool filterByShift(StapleProductionReport record) {
      if (_selectedShift == 'كل الورديات') return true;
      final shift = record.shiftName?.toString().trim() ?? '';
      final normalizedShift = (shift.isEmpty || shift == 'null') ? 'الوردية الأولى' : shift;
      return normalizedShift == _selectedShift;
    }

    final records = box.values
        .where((r) => _normalizeString(r.machineName) == _normalizeString(machineName) && filterByShift(r))
        .map((e) {
          final json = e.toJson();
          json['department'] = 'staples';
          return json;
        })
        .toList();

    if (records.isEmpty) {
      UIUtils.showInfoSnackBar(message: "لا توجد تقارير لهذه الماكينة", backgroundColor: Colors.orange);
      return;
    }

    // فلترة التقارير المعتمدة
    final int totalBeforeFilter = records.length;
    final approvedRecords = records
        .where((r) => r['status'] == 'approved' || r['status'] == 'معتمد')
        .toList();
    final int excludedCount = totalBeforeFilter - approvedRecords.length;

    if (approvedRecords.isEmpty) {
      UIUtils.showInfoSnackBar(
        message: "لا توجد تقارير معتمدة لهذه الماكينة. جميع التقارير قيد المراجعة.",
        backgroundColor: Colors.orange,
        icon: Icons.pending_actions,
      );
      return;
    }

    if (excludedCount > 0 && context.mounted) {
      UIUtils.showInfoSnackBar(
        message: "تم استثناء $excludedCount تقرير قيد المراجعة من ملف الـ PDF لضمان دقة البيانات.",
        backgroundColor: Colors.orange.shade700,
        icon: Icons.info_outline,
      );
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    final title = "تقرير إنتاج ماكينة: $machineName";

    if (isSave) {
      final Uint8List? pdfBytes = await generateFlexoProductionReportPdfBytes({
        'records': approvedRecords,
        'title': title,
        'department': 'staples',
        'shiftName': _selectedShift
      });
      if (pdfBytes != null && context.mounted) {
        await saveProductionPdfToDevice(context, approvedRecords);
      }
    } else {
      if (context.mounted) {
        await exportFlexoProductionReportsToPdf(
          context,
          approvedRecords,
          title: title,
          department: 'staples',
          shiftName: _selectedShift
        );
      }
    }
  }
}
