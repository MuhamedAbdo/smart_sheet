// lib/src/widgets/maintenance/maintenance_form.dart

import 'package:flutter/material.dart';

class MaintenanceForm extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final void Function(Map<String, dynamic>) onSave;

  const MaintenanceForm({
    super.key,
    this.existingData,
    required this.onSave,
  });

  @override
  State<MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends State<MaintenanceForm> {
  late TextEditingController issueDateController;
  late TextEditingController machineController;
  late TextEditingController issueDescController;
  late TextEditingController reportDateController;
  late TextEditingController reportedToTechnicianController;
  late TextEditingController actionController;
  late TextEditingController actionDateController;
  late TextEditingController repairedByController;
  late TextEditingController notesController;

  bool isFixed = false;
  String repairLocation = 'في المصنع';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    issueDateController =
        TextEditingController(text: widget.existingData?['issueDate'] ?? '');
    machineController =
        TextEditingController(text: widget.existingData?['machine'] ?? '');
    issueDescController = TextEditingController(
        text: widget.existingData?['issueDescription'] ?? '');
    reportDateController =
        TextEditingController(text: widget.existingData?['reportDate'] ?? '');
    reportedToTechnicianController = TextEditingController(
        text: widget.existingData?['reportedToTechnician'] ?? '');
    actionController =
        TextEditingController(text: widget.existingData?['actionTaken'] ?? '');
    actionDateController =
        TextEditingController(text: widget.existingData?['actionDate'] ?? '');
    repairedByController =
        TextEditingController(text: widget.existingData?['repairedBy'] ?? '');
    notesController =
        TextEditingController(text: widget.existingData?['notes'] ?? '');

    isFixed = widget.existingData?['isFixed'] ?? false;
    repairLocation = widget.existingData?['repairLocation'] ?? 'في المصنع';
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.tryParse(controller.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    // ✅ تحقق من أن picked ليس null قبل استخدامه
    if (picked != null) {
      controller.text = "${picked.year}-${picked.month}-${picked.day}";
    }
  }

  void _saveRecord() {
    final record = {
      'issueDate': issueDateController.text,
      'machine': machineController.text,
      'issueDescription': issueDescController.text,
      'reportDate': reportDateController.text,
      'reportedToTechnician': reportedToTechnicianController.text,
      'actionTaken': actionController.text,
      'actionDate': actionDateController.text,
      'isFixed': isFixed,
      'repairLocation': repairLocation,
      'repairedBy': repairedByController.text,
      'notes': notesController.text,
    };

    widget.onSave(record);
  }

  @override
  void dispose() {
    issueDateController.dispose();
    machineController.dispose();
    issueDescController.dispose();
    reportDateController.dispose();
    reportedToTechnicianController.dispose();
    actionController.dispose();
    actionDateController.dispose();
    repairedByController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.existingData == null ? "➕ إضافة سجل" : "✏️ تعديل السجل"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: issueDateController,
                readOnly: true,
                decoration:
                    const InputDecoration(labelText: "📅 تاريخ ظهور العطل"),
                onTap: () => _selectDate(context, issueDateController)),
            TextField(
                controller: machineController,
                decoration:
                    const InputDecoration(labelText: "🏭 اسم الماكينة")),
            TextField(
                controller: issueDescController,
                decoration: const InputDecoration(labelText: "⚠️ وصف العطل")),
            TextField(
                controller: reportDateController,
                readOnly: true,
                decoration:
                    const InputDecoration(labelText: "🗓️ تاريخ التبليغ"),
                onTap: () => _selectDate(context, reportDateController)),
            TextField(
                controller: reportedToTechnicianController,
                decoration:
                    const InputDecoration(labelText: "👷‍♂️ تم التبليغ إلى")),
            TextField(
                controller: actionController,
                decoration:
                    const InputDecoration(labelText: "🔧 الإجراء المتخذ")),
            TextField(
                controller: actionDateController,
                readOnly: true,
                decoration:
                    const InputDecoration(labelText: "📆 تاريخ التنفيذ"),
                onTap: () => _selectDate(context, actionDateController)),
            Row(children: [
              const Text("✅ تم الإصلاح؟"),
              Checkbox(
                  value: isFixed,
                  onChanged: (v) => setState(() => isFixed = v ?? false)),
            ]),
            DropdownButtonFormField<String>(
              initialValue: repairLocation,
              items: const [
                DropdownMenuItem(value: 'في المصنع', child: Text('في المصنع')),
                DropdownMenuItem(
                    value: 'ورشة خارجية', child: Text('ورشة خارجية')),
              ],
              onChanged: (v) =>
                  setState(() => repairLocation = v ?? 'في المصنع'),
              decoration: const InputDecoration(labelText: "🏠 مكان الإصلاح"),
            ),
            TextField(
                controller: repairedByController,
                decoration:
                    const InputDecoration(labelText: "🛠 تم الإصلاح بواسطة")),
            TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "📝 ملاحظات")),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("❌ إلغاء")),
        ElevatedButton(onPressed: _saveRecord, child: const Text("💾 حفظ")),
      ],
    );
  }
}
