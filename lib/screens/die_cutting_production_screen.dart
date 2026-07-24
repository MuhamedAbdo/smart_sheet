import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

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
    showDialog(
      context: context,
      builder: (context) => _AddReportDialog(initialData: initialData),
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

class _AddReportDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const _AddReportDialog({this.initialData});

  @override
  State<_AddReportDialog> createState() => _AddReportDialogState();
}

class _AddReportDialogState extends State<_AddReportDialog> {
  final _formKey = GlobalKey<FormState>();
  
  final _machineController = TextEditingController();
  final _techController = TextEditingController();
  final _customerController = TextEditingController();
  final _itemController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _formNumController = TextEditingController();
  final _workOrderController = TextEditingController();
  final _prodQtyController = TextEditingController();
  final _wasteQtyController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _reportDate = DateTime.now();
  TimeOfDay? _runStart;
  TimeOfDay? _runEnd;
  TimeOfDay? _downStart;
  TimeOfDay? _downEnd;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _customerController.text = widget.initialData!['clientName']?.toString() ?? '';
      _itemController.text = widget.initialData!['productName']?.toString() ?? '';
      _itemCodeController.text = widget.initialData!['productCode']?.toString() ?? '';
      _formNumController.text = (widget.initialData!['formNumber'] ?? widget.initialData!['form_number'])?.toString() ?? '';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _reportDate = picked);
    }
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? initialTime) async {
    return showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final id = const Uuid().v4();
      
      DateTime? runStartDt;
      DateTime? runEndDt;
      DateTime? downStartDt;
      DateTime? downEndDt;

      if (_runStart != null) {
        runStartDt = DateTime(_reportDate.year, _reportDate.month, _reportDate.day, _runStart!.hour, _runStart!.minute);
      }
      if (_runEnd != null) {
        runEndDt = DateTime(_reportDate.year, _reportDate.month, _reportDate.day, _runEnd!.hour, _runEnd!.minute);
      }
      if (_downStart != null) {
        downStartDt = DateTime(_reportDate.year, _reportDate.month, _reportDate.day, _downStart!.hour, _downStart!.minute);
      }
      if (_downEnd != null) {
        downEndDt = DateTime(_reportDate.year, _reportDate.month, _reportDate.day, _downEnd!.hour, _downEnd!.minute);
      }

      final report = DieCuttingProductionReport(
        id: id,
        machineName: _machineController.text,
        technicianName: _techController.text,
        reportDate: _reportDate,
        customerName: _customerController.text,
        itemName: _itemController.text,
        itemCode: _itemCodeController.text,
        formNumber: _formNumController.text,
        workOrder: _workOrderController.text,
        runTimeStart: runStartDt,
        runTimeEnd: runEndDt,
        downtimeStart: downStartDt,
        downtimeEnd: downEndDt,
        productionQuantity: double.tryParse(_prodQtyController.text) ?? 0,
        wasteQuantity: double.tryParse(_wasteQtyController.text) ?? 0,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      final box = Hive.box<DieCuttingProductionReport>('die_cutting_production_reports');
      box.put(id, report);
      
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
      Navigator.pop(context);
    }
  }

  Widget _buildTimePickerField(String label, TimeOfDay? time, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          child: Text(time?.format(context) ?? 'اختر الوقت'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة تقرير إنتاج'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'التاريخ',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(DateFormat('yyyy/MM/dd').format(_reportDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _machineController,
                        decoration: const InputDecoration(labelText: 'الماكينة', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _techController,
                        decoration: const InputDecoration(labelText: 'الفني', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _customerController,
                        decoration: const InputDecoration(labelText: 'العميل', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _itemController,
                        decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _itemCodeController,
                        decoration: const InputDecoration(labelText: 'كود الصنف', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _formNumController,
                        decoration: const InputDecoration(labelText: 'فورمة رقم', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _workOrderController,
                        decoration: const InputDecoration(labelText: 'أمر تشغيل', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildTimePickerField('تشغيل من', _runStart, () async {
                      final t = await _pickTime(_runStart);
                      if (t != null) setState(() => _runStart = t);
                    }),
                    const SizedBox(width: 16),
                    _buildTimePickerField('تشغيل إلى', _runEnd, () async {
                      final t = await _pickTime(_runEnd);
                      if (t != null) setState(() => _runEnd = t);
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildTimePickerField('عطل من', _downStart, () async {
                      final t = await _pickTime(_downStart);
                      if (t != null) setState(() => _downStart = t);
                    }),
                    const SizedBox(width: 16),
                    _buildTimePickerField('عطل إلى', _downEnd, () async {
                      final t = await _pickTime(_downEnd);
                      if (t != null) setState(() => _downEnd = t);
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prodQtyController,
                        decoration: const InputDecoration(labelText: 'الإنتاج', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _wasteQtyController,
                        decoration: const InputDecoration(labelText: 'الهالك', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
