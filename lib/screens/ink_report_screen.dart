// lib/src/screens/flexo/ink_report_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/ink_report.dart';
import 'package:smart_sheet/widgets/ink_report_form.dart';
import 'package:smart_sheet/widgets/ink_report_list.dart';

class InkReportScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const InkReportScreen({super.key, this.initialData});

  @override
  State<InkReportScreen> createState() => _InkReportScreenState();
}

class _InkReportScreenState extends State<InkReportScreen> {
  late Box<InkReport> box;

  @override
  void initState() {
    super.initState();
    _initBox();
  }

  void _initBox() {
    if (Hive.isBoxOpen('inkReports')) {
      box = Hive.box<InkReport>('inkReports');
    } else {
      throw StateError('صندوق inkReports لم يُفتح في main.dart');
    }

    if (widget.initialData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openReportForm(report: widget.initialData);
      });
    }
  }

  void _openReportForm({String? reportKey, Map<String, dynamic>? report}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => InkReportForm(
        initialData: report,
        reportKey: reportKey,
        onSave: (data) => _saveReport(reportKey, data),
      ),
    );
  }

  Future<void> _saveReport(String? key, Map<String, dynamic> report) async {
    final inkReport = InkReport.fromJson(report);
    final id = key ?? "report_${DateTime.now().millisecondsSinceEpoch}";
    inkReport.id = id;
    await box.put(id, inkReport);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteReport(dynamic key) async {
    await box.delete(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تقارير الحبر")),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<InkReport>('inkReports').listenable(),
        builder: (context, Box<InkReport> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("لا توجد تقارير بعد"));
          }
          return InkReportList(
            box: box,
            onEdit: (key, report) {
              _openReportForm(reportKey: key.toString(), report: report);
            },
            onDelete: (key) {
              _deleteReport(key);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openReportForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
