// lib/src/screens/workers/worker_details_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';

class WorkerDetailsScreen extends StatefulWidget {
  final Worker worker;

  const WorkerDetailsScreen({super.key, required this.worker});

  @override
  State<WorkerDetailsScreen> createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen> {
  void _refresh() => setState(() {});

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text("👤 ${widget.worker.name}"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📞 ${widget.worker.phone}"),
            Text("🛠 ${widget.worker.job}"),
            const SizedBox(height: 16),
            const Text("📜 الإجراءات",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: widget.worker.actions.isEmpty
                  ? const Text("لا توجد إجراءات لهذا العامل بعد")
                  : ListView.builder(
                      itemCount: widget.worker.actions.length,
                      itemBuilder: (context, index) {
                        final action = widget.worker.actions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          child: ListTile(
                            title: Text("${action.type} (${action.days} يوم)"),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("📆 من: ${_formatDate(action.date)}"),
                                if (action.returnDate != null)
                                  Text(
                                      "🗓️ إلى: ${_formatDate(action.returnDate!)}"),
                                if (action.startTime != null)
                                  Text(
                                      "⏰ خرج: ${action.startTime!.format(context)}"),
                                if (action.endTime != null)
                                  Text(
                                      "🔙 رجع: ${action.endTime!.format(context)}"),
                                if (action.notes?.isNotEmpty == true)
                                  Text("📝 ملاحظات: ${action.notes!}"),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () async {
                                    await _showEditActionDialog(
                                        context, action, index);
                                    _refresh();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () async {
                                    widget.worker.actions.removeAt(index);
                                    await widget.worker.save();
                                    _refresh();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              onPressed: () => _showAddActionDialog(context),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _showAddActionDialog(BuildContext context) {
    final actionType = ValueNotifier<String>('إجازة');
    final days = ValueNotifier<double>(1.0);
    final date = ValueNotifier<DateTime>(DateTime.now());
    final returnDate = ValueNotifier<DateTime?>(null);
    final startTime = ValueNotifier<TimeOfDay?>(null);
    final endTime = ValueNotifier<TimeOfDay?>(null);
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("➕ إضافة إجراء"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: actionType.value,
                  items: const [
                    DropdownMenuItem(value: 'إجازة', child: Text('إجازة')),
                    DropdownMenuItem(value: 'غياب', child: Text('غياب')),
                    DropdownMenuItem(value: 'مكافئة', child: Text('مكافئة')),
                    DropdownMenuItem(value: 'جزاء', child: Text('جزاء')),
                    DropdownMenuItem(value: 'إذن', child: Text('إذن')),
                    DropdownMenuItem(
                        value: 'تأمين صحي', child: Text('تأمين صحي')),
                  ],
                  onChanged: (val) => actionType.value = val ?? 'إجازة',
                  decoration: const InputDecoration(labelText: "نوع الإجراء"),
                ),
                TextField(
                  readOnly: true,
                  controller:
                      TextEditingController(text: _formatDate(date.value)),
                  decoration:
                      const InputDecoration(labelText: "📅 تاريخ الإجراء"),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date.value,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      date.value = picked;
                      setState(() {});
                    }
                  },
                ),
                if (actionType.value == 'إجازة')
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: returnDate.value != null
                          ? _formatDate(returnDate.value!)
                          : '',
                    ),
                    decoration:
                        const InputDecoration(labelText: "🗓️ تاريخ العودة"),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: returnDate.value ?? date.value,
                        firstDate: date.value,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        returnDate.value = picked;
                        setState(() {});
                      }
                    },
                  ),
                if (actionType.value == 'إذن' ||
                    actionType.value == 'تأمين صحي') ...[
                  _buildTimeField("⏰ وقت الخروج", startTime, context, setState),
                  _buildTimeField("🔙 وقت الرجوع", endTime, context, setState),
                ],
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: "📝 ملاحظات"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("❌ إلغاء"),
            ),
            ElevatedButton(
              onPressed: () async {
                final actionBox = Hive.box<WorkerAction>('worker_actions');
                final newAction = WorkerAction(
                  type: actionType.value,
                  days: days.value,
                  date: date.value,
                  returnDate: returnDate.value,
                  notes: notesController.text,
                  startTimeHour: startTime.value?.hour,
                  startTimeMinute: startTime.value?.minute,
                  endTimeHour: endTime.value?.hour,
                  endTimeMinute: endTime.value?.minute,
                );
                final key = await actionBox.add(newAction);
                final savedAction = actionBox.get(key);
                if (savedAction != null) {
                  widget.worker.actions.add(savedAction);
                  await widget.worker.save();
                }
                Navigator.pop(context);
                _refresh();
              },
              child: const Text("✅ حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(
    String label,
    ValueNotifier<TimeOfDay?> timeNotifier,
    BuildContext context,
    StateSetter setState,
  ) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(
          onPressed: () async {
            final now = TimeOfDay.now();
            final initialTime = timeNotifier.value ?? now;
            final picked = await showTimePicker(
                context: context, initialTime: initialTime);
            if (picked != null) {
              timeNotifier.value = picked;
              setState(() {});
            }
          },
          child: Text(timeNotifier.value?.format(context) ?? "اختر الوقت"),
        ),
      ],
    );
  }

  Future<void> _showEditActionDialog(
      BuildContext context, WorkerAction action, int index) async {
    final actionType = ValueNotifier<String>(action.type);
    final days = ValueNotifier<double>(action.days);
    final date = ValueNotifier<DateTime>(action.date);
    final returnDate = ValueNotifier<DateTime?>(action.returnDate);
    final startTime = ValueNotifier<TimeOfDay?>(action.startTime);
    final endTime = ValueNotifier<TimeOfDay?>(action.endTime);
    final notesController = TextEditingController(text: action.notes ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("🔄 تعديل الإجراء"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: actionType.value,
                  items: const [
                    DropdownMenuItem(value: 'إجازة', child: Text('إجازة')),
                    DropdownMenuItem(value: 'غياب', child: Text('غياب')),
                    DropdownMenuItem(value: 'مكافئة', child: Text('مكافئة')),
                    DropdownMenuItem(value: 'جزاء', child: Text('جزاء')),
                    DropdownMenuItem(value: 'إذن', child: Text('إذن')),
                    DropdownMenuItem(
                        value: 'تأمين صحي', child: Text('تأمين صحي')),
                  ],
                  onChanged: (val) => actionType.value = val ?? 'إجازة',
                  decoration: const InputDecoration(labelText: "نوع الإجراء"),
                ),
                TextField(
                  readOnly: true,
                  controller:
                      TextEditingController(text: _formatDate(date.value)),
                  decoration:
                      const InputDecoration(labelText: "📅 تاريخ الإجراء"),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date.value,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      date.value = picked;
                      setState(() {});
                    }
                  },
                ),
                if (actionType.value == 'إجازة')
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: returnDate.value != null
                          ? _formatDate(returnDate.value!)
                          : '',
                    ),
                    decoration:
                        const InputDecoration(labelText: "🗓️ تاريخ العودة"),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: returnDate.value ?? date.value,
                        firstDate: date.value,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        returnDate.value = picked;
                        setState(() {});
                      }
                    },
                  ),
                if (actionType.value == 'إذن' ||
                    actionType.value == 'تأمين صحي') ...[
                  _buildTimeField("⏰ وقت الخروج", startTime, context, setState),
                  _buildTimeField("🔙 وقت الرجوع", endTime, context, setState),
                ],
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: "📝 ملاحظات"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("❌ إلغاء"),
            ),
            ElevatedButton(
              onPressed: () async {
                final actionBox = Hive.box<WorkerAction>('worker_actions');
                final newAction = WorkerAction(
                  type: actionType.value,
                  days: days.value,
                  date: date.value,
                  returnDate: returnDate.value,
                  notes: notesController.text,
                  startTimeHour: startTime.value?.hour,
                  startTimeMinute: startTime.value?.minute,
                  endTimeHour: endTime.value?.hour,
                  endTimeMinute: endTime.value?.minute,
                );
                final key = await actionBox.add(newAction);
                final savedAction = actionBox.get(key);
                if (savedAction != null) {
                  widget.worker.actions.removeAt(index);
                  widget.worker.actions.insert(index, savedAction);
                  await widget.worker.save();
                }
                Navigator.pop(context);
                _refresh();
              },
              child: const Text("✅ حفظ التعديلات"),
            ),
          ],
        ),
      ),
    );
    _refresh();
  }
}
