import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:smart_sheet/widgets/production_report_form.dart';

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
        _showAddDialog(initialData: widget.initialData);
      });
    }
  }

  void _showAddDialog({Map<String, dynamic>? initialData}) {
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
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

