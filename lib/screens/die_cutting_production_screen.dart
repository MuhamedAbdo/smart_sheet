import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:smart_sheet/widgets/production_report_form.dart';
import 'package:smart_sheet/widgets/start_session_dialog.dart';

class DieCuttingProductionScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const DieCuttingProductionScreen({super.key, this.initialData});

  @override
  State<DieCuttingProductionScreen> createState() => _DieCuttingProductionScreenState();
}

class _DieCuttingProductionScreenState extends State<DieCuttingProductionScreen> {
  final Box<DieCuttingProductionReport> box = Hive.box<DieCuttingProductionReport>('die_cutting_production_reports');

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddReportDialog(initialData: widget.initialData);
      });
    }
  }

  void _showAddReportDialog({Map<String, dynamic>? initialData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      builder: (c) => ProductionReportForm(
        initialData: initialData,
        department: 'crushing',
        onSave: (r) async {
          final id = const Uuid().v4();
          
          final reportDateStr = r['date']?.toString() ?? DateTime.now().toIso8601String();
          final reportDate = DateTime.tryParse(reportDateStr) ?? DateTime.now();
          
          final runStartStr = r['startTime']?.toString();
          final runEndStr = r['endTime']?.toString();
          
          DateTime? runStartDt;
          if (runStartStr != null && runStartStr.isNotEmpty) {
            runStartDt = DateTime.tryParse(runStartStr);
          }
          DateTime? runEndDt;
          if (runEndStr != null && runEndStr.isNotEmpty) {
            runEndDt = DateTime.tryParse(runEndStr);
          }

          final report = DieCuttingProductionReport(
            id: id,
            machineName: r['machineName']?.toString() ?? '',
            technicianName: r['technicianName']?.toString() ?? '',
            reportDate: reportDate,
            customerName: r['clientName']?.toString() ?? '',
            itemName: r['product']?.toString() ?? '',
            itemCode: r['productCode']?.toString() ?? '',
            formNumber: r['formNumber']?.toString() ?? '',
            workOrder: r['orderNumber']?.toString() ?? '',
            runTimeStart: runStartDt,
            runTimeEnd: runEndDt,
            downtimeStart: null,
            downtimeEnd: null,
            productionQuantity: double.tryParse(r['quantity']?.toString() ?? '0') ?? 0,
            wasteQuantity: double.tryParse(r['lineWaste']?.toString() ?? '0') ?? 0,
            notes: r['notes']?.toString(),
          );

          final box = Hive.box<DieCuttingProductionReport>('die_cutting_production_reports');
          await box.put(id, report);
          
          SyncService.instance.pushToQueue(
            'die_cutting_production_reports',
            report.toJson(),
            operation: 'upsert',
          );

          UIUtils.showInfoSnackBar(
            message: 'تم حفظ التقرير بنجاح',
            backgroundColor: Colors.green,
            icon: Icons.check_circle,
          );
          if (c.mounted) Navigator.pop(c);
        },
      ),
    );
  }

  void _showStartSessionDialog({Map<String, dynamic>? initialData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StartSessionDialog(
        initialData: initialData,
        department: 'crushing',
      ),
    );
  }

  void _showProductionOptionsSheet({Map<String, dynamic>? initialData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final isDark = theme.brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
        final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

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
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.content_cut,
                      color: Colors.orange.shade700,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'إضافة أوردر — تكسير',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildOptionTile(
                context: sheetCtx,
                icon: Icons.play_circle_filled_rounded,
                iconColor: Colors.green.shade600,
                bgColor: Colors.green.shade600.withValues(alpha: 0.10),
                title: 'بدء جلسة حية 🚀',
                subtitle: 'تشغيل المؤقت وبدء العمل الآن.',
                isDark: isDark,
                subtitleColor: subtitleColor,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showStartSessionDialog(initialData: initialData);
                },
              ),
              const SizedBox(height: 12),
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
                  _showAddReportDialog(initialData: initialData);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

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
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
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
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير إنتاج التكسير'),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<DieCuttingProductionReport> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('لا توجد تقارير بعد.'));
          }

          final reports = box.values.toList().reversed.toList();

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                columns: const [
                  DataColumn(label: Text('م')),
                  DataColumn(label: Text('تاريخ')),
                  DataColumn(label: Text('ماكينة')),
                  DataColumn(label: Text('فني')),
                  DataColumn(label: Text('العميل')),
                  DataColumn(label: Text('الصنف')),
                  DataColumn(label: Text('كود الصنف')),
                  DataColumn(label: Text('فورمة رقم')),
                  DataColumn(label: Text('أمر تشغيل')),
                  DataColumn(label: Text('التشغيل (من|إلى)')),
                  DataColumn(label: Text('الأعطال (من|إلى)')),
                  DataColumn(label: Text('الإنتاج')),
                  DataColumn(label: Text('الهالك')),
                  DataColumn(label: Text('ملاحظات')),
                ],
                rows: List.generate(reports.length, (index) {
                  final report = reports[index];
                  final dateFormat = DateFormat('yyyy/MM/dd');
                  final timeFormat = DateFormat('hh:mm a');
                  
                  String runTimeStr = '-';
                  if (report.runTimeStart != null && report.runTimeEnd != null) {
                    runTimeStr = '${timeFormat.format(report.runTimeStart!)} | ${timeFormat.format(report.runTimeEnd!)}';
                  }
                  
                  String downTimeStr = '-';
                  if (report.downtimeStart != null && report.downtimeEnd != null) {
                    downTimeStr = '${timeFormat.format(report.downtimeStart!)} | ${timeFormat.format(report.downtimeEnd!)}';
                  }

                  return DataRow(cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(Text(dateFormat.format(report.reportDate))),
                    DataCell(Text(report.machineName)),
                    DataCell(Text(report.technicianName)),
                    DataCell(Text(report.customerName)),
                    DataCell(Text(report.itemName)),
                    DataCell(Text(report.itemCode)),
                    DataCell(Text(report.formNumber)),
                    DataCell(Text(report.workOrder)),
                    DataCell(Text(runTimeStr)),
                    DataCell(Text(downTimeStr)),
                    DataCell(Text(report.productionQuantity.toString())),
                    DataCell(Text(report.wasteQuantity.toString())),
                    DataCell(Text(report.notes ?? '-')),
                  ]);
                }),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductionOptionsSheet(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

