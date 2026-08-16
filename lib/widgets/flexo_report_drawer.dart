import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/flexo_production_report.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';
import 'package:smart_sheet/utils/pdf_export_helper.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:smart_sheet/models/day_schedule.dart';

class FlexoReportDrawer extends StatefulWidget {
  final String department;
  const FlexoReportDrawer({super.key, this.department = 'flexo'});

  @override
  State<FlexoReportDrawer> createState() => _FlexoReportDrawerState();
}

class _FlexoReportDrawerState extends State<FlexoReportDrawer> {
  String _selectedShift = 'كل الورديات';
  List<String> _availableShifts = ['كل الورديات', 'الوردية الأولى'];

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  void _loadShifts() async {
    try {
      const boxName = 'factory_schedule';
      final box = Hive.isBoxOpen(boxName) ? Hive.box<DaySchedule>(boxName) : await Hive.openBox<DaySchedule>(boxName);
      
      final todayNames = {
        DateTime.monday: 'Monday',
        DateTime.tuesday: 'Tuesday',
        DateTime.wednesday: 'Wednesday',
        DateTime.thursday: 'Thursday',
        DateTime.friday: 'Friday',
        DateTime.saturday: 'Saturday',
        DateTime.sunday: 'Sunday',
      };
      
      final todayName = todayNames[DateTime.now().weekday] ?? 'Saturday';
      final schedule = box.get(todayName);
      
      List<String> shifts = ['كل الورديات'];
      
      if (schedule != null) {
        if (schedule.shiftNames != null && schedule.shiftNames!.isNotEmpty) {
          shifts.addAll(schedule.shiftNames!);
        } else if (schedule.shifts != null && schedule.shifts!.isNotEmpty) {
          shifts.addAll(schedule.shifts!.map((s) => s.name));
        } else {
          shifts.add('الوردية الأولى');
        }
      } else {
         shifts.add('الوردية الأولى');
      }
      
      if (mounted) {
        setState(() {
          _availableShifts = shifts.toSet().toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading shifts: $e");
    }
  }

  String _normalizeString(String input) {
    return input
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final department = widget.department;
    final isProductionLine = department == 'production_line';
    final isCrushing = department == 'crushing';
    final drawerTitle = isProductionLine
        ? "تقارير ماكينات خط الإنتاج"
        : isCrushing
            ? "تقارير ماكينات التكسير"
            : "تقارير ماكينات الفلكسو";

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blueAccent),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  Text(
                    drawerTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "اختر الوردية",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              initialValue: _availableShifts.contains(_selectedShift) ? _selectedShift : _availableShifts.first,
              items: _availableShifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedShift = val);
              },
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<FlexoMachine>('flexo_machines').listenable(),
              builder: (context, Box<FlexoMachine> machineBox, _) {
                final machines = FlexoMachine.getMachinesForDepartment(department);
                
                if (machines.isEmpty) {
                  return const Center(child: Text("لا توجد ماكينات مسجلة"));
                }
                
                return ListView.builder(
                  itemCount: machines.length,
                  itemBuilder: (context, index) {
                    final machine = machines[index];
                    final mName = machine.name;
                    
                    return ExpansionTile(
                      leading: const Icon(Icons.settings),
                      title: Text(mName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      children: [
                        _buildReportTile(
                          context,
                          label: "عرض تقرير الإنتاج",
                          icon: Icons.picture_as_pdf,
                          onTap: () => _handlePdfAction(context, mName, isPrinting: false, isSave: false),
                        ),
                        _buildReportTile(
                          context,
                          label: "حفظ تقرير إنتاج",
                          icon: Icons.save_alt,
                          onTap: () => _handlePdfAction(context, mName, isPrinting: false, isSave: true),
                        ),
                        if (!isCrushing && !isProductionLine) ...[
                          _buildReportTile(
                            context,
                            label: "عرض تقرير طباعة",
                            icon: Icons.picture_as_pdf,
                            color: Colors.blueAccent,
                            onTap: () => _handlePdfAction(context, mName, isPrinting: true, isSave: false),
                          ),
                          _buildReportTile(
                            context,
                            label: "حفظ تقرير طباعة",
                            icon: Icons.save_alt,
                            color: Colors.blueAccent,
                            onTap: () => _handlePdfAction(context, mName, isPrinting: true, isSave: true),
                          ),
                        ],
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

  Future<void> _handlePdfAction(BuildContext context, String machineName, {required bool isPrinting, required bool isSave}) async {
    final department = widget.department;
    final bool isDieCutting = (department == 'crushing' || department == 'die_cutting');
    List<Map<String, dynamic>> records = [];

    bool filterByShift(dynamic record) {
      if (_selectedShift == 'كل الورديات') return true;
      final shift = record.shiftName?.toString().trim() ?? '';
      final normalizedShift = (shift.isEmpty || shift == 'null') ? 'الوردية الأولى' : shift;
      return normalizedShift == _selectedShift;
    }

    if (isDieCutting) {
      const boxName = 'die_cutting_production_reports';
      final box = Hive.isBoxOpen(boxName) 
          ? Hive.box<DieCuttingProductionReport>(boxName)
          : await Hive.openBox<DieCuttingProductionReport>(boxName);
          
      final newRecords = box.values
          .where((r) => _normalizeString(r.machineName) == _normalizeString(machineName) && filterByShift(r))
          .map((e) {
            final json = e.toJson();
            json['department'] = department;
            return json;
          })
          .toList();
          
      const oldBoxName = 'flexo_production_reports_box';
      final oldBox = Hive.isBoxOpen(oldBoxName) 
          ? Hive.box<FlexoProductionReport>(oldBoxName)
          : await Hive.openBox<FlexoProductionReport>(oldBoxName);
          
      final oldRecords = oldBox.values
          .where((r) => (r.department == 'crushing' || r.department == 'die_cutting') && _normalizeString(r.machineName ?? '') == _normalizeString(machineName) && filterByShift(r))
          .map((e) => e.toJson())
          .toList();

      records = [...newRecords, ...oldRecords];
    } else {
      const boxName = 'flexo_production_reports_box';
      final box = Hive.isBoxOpen(boxName) 
          ? Hive.box<FlexoProductionReport>(boxName)
          : await Hive.openBox<FlexoProductionReport>(boxName);
          
      records = box.values
          .where((r) {
            final m = r.machineName ?? '';
            final dept = r.department;
            if (department == 'production_line') {
              if (dept != 'production_line') return false;
            } else {
              if (dept == 'crushing' || dept == 'die_cutting' || dept == 'production_line') return false;
            }
            return _normalizeString(m) == _normalizeString(machineName) && filterByShift(r);
          })
          .map((e) => e.toJson())
          .toList();
    }

    if (records.isEmpty) {
      UIUtils.showInfoSnackBar(message: "لا توجد تقارير لهذه الماكينة", backgroundColor: Colors.orange);
      return;
    }

    final title = isPrinting
        ? "تقرير طباعة ماكينة: $machineName"
        : (department == 'crushing'
            ? "تقرير إنتاج تكسير ماكينة: $machineName"
            : (department == 'production_line'
                ? "تقرير إنتاج خط الإنتاج ماكينة: $machineName"
                : "تقرير إنتاج ماكينة: $machineName"));

    if (isSave) {
      final Uint8List? pdfBytes = isPrinting
          ? await generatePrintingReportPdfBytes({'records': records, 'title': title, 'department': department, 'shiftName': _selectedShift})
          : await generateFlexoProductionReportPdfBytes({'records': records, 'title': title, 'department': department, 'shiftName': _selectedShift});
      
      if (pdfBytes == null) return;

      await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ PDF',
        fileName: '${title.replaceAll(RegExp(r'[\s:/\\*?"<>|]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );
    } else {
      if (!context.mounted) return;
      if (isPrinting) {
        await exportPrintingReportsToPdf(context, records, title: title, department: department, shiftName: _selectedShift);
      } else {
        await exportFlexoProductionReportsToPdf(context, records, title: title, department: department, shiftName: _selectedShift);
      }
    }
  }
}
