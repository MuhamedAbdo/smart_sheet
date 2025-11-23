// lib/src/screens/workers/worker_details_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/worker_action_card.dart';

class WorkerDetailsScreen extends StatefulWidget {
  final Worker worker;
  final Box<Worker> box;

  const WorkerDetailsScreen({
    super.key,
    required this.worker,
    required this.box,
  });

  @override
  State<WorkerDetailsScreen> createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen> {
  void _refresh() => setState(() {});

  String _f(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
                  ? const Center(child: Text("لا توجد إجراءات لهذا العامل بعد"))
                  : ListView.builder(
                      itemCount: widget.worker.actions.length,
                      itemBuilder: (context, index) {
                        final action = widget.worker.actions[index];
                        return WorkerActionCard(
                          action: action,
                          onEdit: () async {
                            await _showEditActionDialog(context, action, index);
                            _refresh();
                          },
                          onDelete: () {
                            widget.worker.actions.removeAt(index);
                            widget.worker.save();
                            _refresh();
                          },
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

  void _showAddActionDialog(BuildContext context) {
    final actionType = ValueNotifier<String>('إجازة');
    final days = ValueNotifier<double>(1.0);
    final date = ValueNotifier<DateTime>(DateTime.now());
    final returnDate = ValueNotifier<DateTime?>(null);
    final startTime = ValueNotifier<TimeOfDay?>(null);
    final endTime = ValueNotifier<TimeOfDay?>(null);
    final rewardType = ValueNotifier<String>('amount');
    final amountController = TextEditingController();
    final bonusDays = ValueNotifier<double?>(null);
    final notesController = TextEditingController();

    void calculateDays() {
      if (returnDate.value != null) {
        final diff = returnDate.value!.difference(date.value).inDays;
        days.value = diff > 0 ? diff.toDouble() : 1.0;
      } else {
        days.value = 1.0;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("➕ ${actionType.value}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: actionType.value,
                  items: const [
                    DropdownMenuItem(value: 'إجازة', child: Text('إجازة')),
                    DropdownMenuItem(value: 'غياب', child: Text('غياب')),
                    DropdownMenuItem(value: 'مكافئة', child: Text('مكافئة')),
                    DropdownMenuItem(value: 'جزاء', child: Text('جزاء')),
                    DropdownMenuItem(value: 'إذن', child: Text('إذن')),
                    DropdownMenuItem(
                        value: 'تأمين صحي', child: Text('تأمين صحي')),
                  ],
                  onChanged: (v) =>
                      setState(() => actionType.value = v ?? 'إجازة'),
                ),
                TextField(
                  readOnly: true,
                  controller: TextEditingController(text: _f(date.value)),
                  decoration: const InputDecoration(labelText: "📅 التاريخ"),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: date.value,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) {
                      date.value = p;
                      calculateDays();
                      setState(() {});
                    }
                  },
                ),
                if (actionType.value == 'إجازة' ||
                    actionType.value == 'غياب') ...[
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(
                      text:
                          returnDate.value != null ? _f(returnDate.value!) : '',
                    ),
                    decoration:
                        const InputDecoration(labelText: "🗓️ تاريخ العودة"),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: returnDate.value ?? date.value,
                        firstDate: date.value,
                        lastDate: DateTime(2100),
                      );
                      if (p != null) {
                        returnDate.value = p;
                        calculateDays();
                        setState(() {});
                      }
                    },
                  ),
                ],
                if (actionType.value == 'مكافئة' ||
                    actionType.value == 'جزاء') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ToggleButtons(
                          borderRadius: BorderRadius.circular(8),
                          isSelected: [
                            rewardType.value == 'amount',
                            rewardType.value == 'days'
                          ],
                          onPressed: (int index) {
                            setState(() {
                              rewardType.value = index == 0 ? 'amount' : 'days';
                            });
                          },
                          children: const [
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text("جنيه")),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text("أيام")),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (rewardType.value == 'amount') ...[
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: "💰 أدخل المبلغ (جنيه)"),
                    ),
                  ],
                  if (rewardType.value == 'days') ...[
                    DropdownButtonFormField<double>(
                      initialValue: bonusDays.value,
                      items: [
                        const DropdownMenuItem(
                            value: 0.25, child: Text('¼ يوم')),
                        const DropdownMenuItem(
                            value: 0.5, child: Text('½ يوم')),
                        for (var i = 1; i <= 5; i++)
                          DropdownMenuItem(
                              value: i.toDouble(), child: Text('$i يوم')),
                      ],
                      onChanged: (v) => setState(() => bonusDays.value = v),
                      decoration: const InputDecoration(
                          labelText: "📅 اختر عدد الأيام"),
                    ),
                  ],
                ],
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
                onPressed: Navigator.of(context).pop,
                child: const Text("❌ إلغاء")),
            ElevatedButton(
              onPressed: () async {
                final actionBox = Hive.box<WorkerAction>('worker_actions');

                double? amountToSave;
                double? bonusDaysToSave;

                if (actionType.value == 'مكافئة' ||
                    actionType.value == 'جزاء') {
                  if (rewardType.value == 'amount') {
                    amountToSave = double.tryParse(amountController.text);
                    bonusDaysToSave = null;
                  } else {
                    amountToSave = null;
                    bonusDaysToSave = bonusDays.value;
                  }
                }

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
                  amount: amountToSave,
                  bonusDays: bonusDaysToSave,
                );

                final key = await actionBox.add(newAction);
                final saved = actionBox.get(key);
                if (saved != null) {
                  widget.worker.actions.add(saved);
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
            final picked = await showTimePicker(
                context: context,
                initialTime: timeNotifier.value ?? TimeOfDay.now());
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
    final days = ValueNotifier<double>(
      (action.returnDate != null)
          ? action.returnDate!.difference(action.date).inDays.toDouble()
          : action.days,
    );
    final date = ValueNotifier<DateTime>(action.date);
    final returnDate = ValueNotifier<DateTime?>(action.returnDate);
    final startTime = ValueNotifier<TimeOfDay?>(action.startTime);
    final endTime = ValueNotifier<TimeOfDay?>(action.endTime);
    final rewardType =
        ValueNotifier<String>(action.amount != null ? 'amount' : 'days');
    final amountController =
        TextEditingController(text: action.amount?.toString() ?? '');
    final bonusDays = ValueNotifier<double?>(action.bonusDays);
    final notesController = TextEditingController(text: action.notes ?? '');

    void calculateDays() {
      if (returnDate.value != null) {
        final diff = returnDate.value!.difference(date.value).inDays;
        days.value = diff > 0 ? diff.toDouble() : 1.0;
      } else {
        days.value = 1.0;
      }
    }

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
                  initialValue: actionType.value,
                  items: const [
                    DropdownMenuItem(value: 'إجازة', child: Text('إجازة')),
                    DropdownMenuItem(value: 'غياب', child: Text('غياب')),
                    DropdownMenuItem(value: 'مكافئة', child: Text('مكافئة')),
                    DropdownMenuItem(value: 'جزاء', child: Text('جزاء')),
                    DropdownMenuItem(value: 'إذن', child: Text('إذن')),
                    DropdownMenuItem(
                        value: 'تأمين صحي', child: Text('تأمين صحي')),
                  ],
                  onChanged: (v) =>
                      setState(() => actionType.value = v ?? 'إجازة'),
                ),
                TextField(
                  readOnly: true,
                  controller: TextEditingController(text: _f(date.value)),
                  decoration:
                      const InputDecoration(labelText: "📅 تاريخ الإجراء"),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: date.value,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) {
                      date.value = p;
                      calculateDays();
                      setState(() {});
                    }
                  },
                ),
                if (actionType.value == 'إجازة' ||
                    actionType.value == 'غياب') ...[
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(
                      text:
                          returnDate.value != null ? _f(returnDate.value!) : '',
                    ),
                    decoration:
                        const InputDecoration(labelText: "🗓️ تاريخ العودة"),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: returnDate.value ?? date.value,
                        firstDate: date.value,
                        lastDate: DateTime(2100),
                      );
                      if (p != null) {
                        returnDate.value = p;
                        calculateDays();
                        setState(() {});
                      }
                    },
                  ),
                ],
                if (actionType.value == 'مكافئة' ||
                    actionType.value == 'جزاء') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ToggleButtons(
                          borderRadius: BorderRadius.circular(8),
                          isSelected: [
                            rewardType.value == 'amount',
                            rewardType.value == 'days'
                          ],
                          onPressed: (int index) {
                            setState(() {
                              rewardType.value = index == 0 ? 'amount' : 'days';
                            });
                          },
                          children: const [
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text("جنيه")),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text("أيام")),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (rewardType.value == 'amount') ...[
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: "💰 أدخل المبلغ (جنيه)"),
                    ),
                  ],
                  if (rewardType.value == 'days') ...[
                    DropdownButtonFormField<double>(
                      initialValue: bonusDays.value,
                      items: [
                        const DropdownMenuItem(
                            value: 0.25, child: Text('¼ يوم')),
                        const DropdownMenuItem(
                            value: 0.5, child: Text('½ يوم')),
                        for (var i = 1; i <= 5; i++)
                          DropdownMenuItem(
                              value: i.toDouble(), child: Text('$i يوم')),
                      ],
                      onChanged: (v) => setState(() => bonusDays.value = v),
                      decoration: const InputDecoration(
                          labelText: "📅 اختر عدد الأيام"),
                    ),
                  ],
                ],
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
                onPressed: Navigator.of(context).pop,
                child: const Text("❌ إلغاء")),
            ElevatedButton(
              onPressed: () async {
                final actionBox = Hive.box<WorkerAction>('worker_actions');

                double? amountToSave;
                double? bonusDaysToSave;

                if (actionType.value == 'مكافئة' ||
                    actionType.value == 'جزاء') {
                  if (rewardType.value == 'amount') {
                    amountToSave = double.tryParse(amountController.text);
                    bonusDaysToSave = null;
                  } else {
                    amountToSave = null;
                    bonusDaysToSave = bonusDays.value;
                  }
                }

                final updatedAction = WorkerAction(
                  type: actionType.value,
                  days: days.value,
                  date: date.value,
                  returnDate: returnDate.value,
                  notes: notesController.text,
                  startTimeHour: startTime.value?.hour,
                  startTimeMinute: startTime.value?.minute,
                  endTimeHour: endTime.value?.hour,
                  endTimeMinute: endTime.value?.minute,
                  amount: amountToSave,
                  bonusDays: bonusDaysToSave,
                );

                final key = await actionBox.add(updatedAction);
                final saved = actionBox.get(key);
                if (saved != null) {
                  widget.worker.actions.removeAt(index);
                  widget.worker.actions.insert(index, saved);
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
