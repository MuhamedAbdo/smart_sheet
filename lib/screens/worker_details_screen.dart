// lib/src/screens/workers/worker_details_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/worker_action_model.dart';
import '../../models/worker_model.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/worker_action_card.dart';
import '../../widgets/active_absence_card.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'dart:async';

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
  StreamSubscription? _supabaseSubscription;

  @override
  void initState() {
    super.initState();
    _setupSupabaseStream();
  }

  Future<void> _setupSupabaseStream() async {
    final stream = await SupabaseManager.streamData('worker_actions', primaryKey: ['id']);
    if (stream != null) {
      _supabaseSubscription = stream.listen((data) async {
        if (!Hive.isBoxOpen('worker_actions')) return;
        final actionBox = Hive.box<WorkerAction>('worker_actions');
        bool updated = false;
        
        for (var record in data) {
           if (record['worker_name'] != widget.worker.name) continue;
           
           final action = WorkerAction.fromJson(record);
           if (action.id == null) continue;
           
           final localIndex = widget.worker.actions.indexWhere((a) => a.id == action.id);
           if (localIndex == -1) {
             final key = await actionBox.add(action);
             final saved = actionBox.get(key);
             if (saved != null) {
               widget.worker.actions.add(saved);
               updated = true;
             }
           } else {
             final localAction = widget.worker.actions[localIndex];
             final keys = actionBox.keys.toList();
             final values = actionBox.values.toList();
             final indexInBox = values.indexOf(localAction);
             if (indexInBox != -1) {
               final key = keys[indexInBox];
               await actionBox.put(key, action);
               widget.worker.actions[localIndex] = action;
               updated = true;
             }
           }
        }
        if (updated) {
          await widget.worker.save();
          if (mounted) _refresh();
        }
      });
    }
  }

  @override
  void dispose() {
    _supabaseSubscription?.cancel();
    super.dispose();
  }

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
            _buildActiveAbsenceSection(),
            Expanded(
              child: widget.worker.actions.isEmpty
                  ? const Center(child: Text("لا توجد إجراءات لهذا العامل بعد"))
                  : ListView.builder(
                      itemCount: widget.worker.actions.length,
                      itemBuilder: (context, index) {
                        final action = widget.worker.actions[index];
                        return WorkerActionCard(
                          action: action,
                          onRefresh: _refresh,
                          onEdit: () async {
                            await _showEditActionDialog(context, action, index);
                            _refresh();
                          },
                          onDelete: () {
                            final actionToRemove = widget.worker.actions[index];
                            UIUtils.showDeleteConfirmation(
                              context: context,
                              title: "حذف الإجراء",
                              content: "هل أنت متأكد من حذف هذا الإجراء؟",
                              onConfirm: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                widget.worker.actions.removeAt(index);
                                await widget.worker.save();
                                if (!context.mounted) return;

                                messenger.clearSnackBars();
                                UIUtils.showUndoSnackBar(
                                  context: context,
                                  message: "تم حذف الإجراء",
                                  onUndo: () async {
                                    messenger.clearSnackBars();
                                    widget.worker.actions.insert(index, actionToRemove);
                                    await widget.worker.save();
                                    _refresh();
                                  },
                                );

                                _refresh();
                              },
                            );
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

  Widget _buildActiveAbsenceSection() {
    try {
      final activeAction = widget.worker.actions.firstWhere(
        (a) => (a.type == 'غياب' && a.returnDate == null &&
               DateTime.now().difference(a.date).inDays <= 30) ||
               ((a.type == 'إذن' || a.type == 'تأمين صحي') && a.returnDate == null),
      );
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          height: 190,
          child: ActiveAbsenceCard(
            worker: widget.worker,
            action: activeAction,
            onRefresh: _refresh,
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  void _showAddActionDialog(BuildContext context) {
    final actionType = ValueNotifier<String>('إجازة');
    final date = ValueNotifier<DateTime>(DateTime.now());
    final daysController = TextEditingController(text: "1.0");
    final startTime = ValueNotifier<TimeOfDay?>(null);
    final endTime = ValueNotifier<TimeOfDay?>(null);
    final rewardType = ValueNotifier<String>('amount');
    final amountController = TextEditingController();
    final bonusDays = ValueNotifier<double?>(null);
    final notesController = TextEditingController();

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
                    DropdownMenuItem(value: 'أجازة عارضة', child: Text('أجازة عارضة')),
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
                    if (p != null) setState(() => date.value = p);
                  },
                ),
                if (actionType.value == 'إجازة' ||
                    actionType.value == 'غياب') ...[
                  TextField(
                    controller: daysController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: "🔢 عدد الأيام", hintText: "مثال: 1.5"),
                  ),
                ]
                else if (actionType.value == 'مكافئة' ||
                    actionType.value == 'جزاء') ...[
                  const SizedBox(height: 8),
                  ToggleButtons(
                    borderRadius: BorderRadius.circular(8),
                    isSelected: [
                      rewardType.value == 'amount',
                      rewardType.value == 'days'
                    ],
                    onPressed: (int index) => setState(() =>
                        rewardType.value = index == 0 ? 'amount' : 'days'),
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text("جنيه")),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text("أيام")),
                    ],
                  ),
                  if (rewardType.value == 'amount')
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "💰 المبلغ"),
                    )
                  else
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
                      decoration: const InputDecoration(labelText: "📅 الأيام"),
                    ),
                ] else if (actionType.value == 'إذن' ||
                    actionType.value == 'تأمين صحي') ...[
                  _buildTimeField("⏰ خروج", startTime, context, setState),
                  _buildTimeField("🔙 رجوع", endTime, context, setState),
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
                  } else {
                    bonusDaysToSave = bonusDays.value;
                  }
                }

                final newAction = WorkerAction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  type: actionType.value,
                  days: (actionType.value == 'إجازة' ||
                          actionType.value == 'أجازة عارضة' ||
                          actionType.value == 'غياب')
                      ? double.tryParse(daysController.text)
                      : 0,
                  date: date.value,
                  notes: notesController.text,
                  startTimeHour: startTime.value?.hour,
                  startTimeMinute: startTime.value?.minute,
                  endTimeHour: endTime.value?.hour,
                  endTimeMinute: endTime.value?.minute,
                  amount: amountToSave,
                  bonusDays: bonusDaysToSave,
                  factoryId: widget.worker.factoryId,
                  workerName: widget.worker.name,
                );

                final key = await actionBox.add(newAction);
                final saved = actionBox.get(key);
                if (saved != null) {
                  widget.worker.actions.add(saved);
                  await widget.worker.save();
                  SupabaseManager.pushData('worker_actions', saved.toJson());
                }
                if (context.mounted) Navigator.pop(context);
                _refresh();
              },
              child: const Text("✅ حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditActionDialog(
      BuildContext context, WorkerAction action, int index) async {
    final actionType = ValueNotifier<String>(action.type);
    final date = ValueNotifier<DateTime>(action.date);
    final daysController = TextEditingController(text: action.days?.toString() ?? '');
    final startTime = ValueNotifier<TimeOfDay?>(action.startTime);
    final endTime = ValueNotifier<TimeOfDay?>(action.endTime);
    final rewardType =
        ValueNotifier<String>(action.amount != null ? 'amount' : 'days');
    final amountController =
        TextEditingController(text: action.amount?.toString() ?? '');
    final bonusDays = ValueNotifier<double?>(action.bonusDays);
    final notesController = TextEditingController(text: action.notes ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("🔄 تعديل"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: actionType.value,
                  items: const [
                    DropdownMenuItem(value: 'إجازة', child: Text('إجازة')),
                    DropdownMenuItem(value: 'أجازة عارضة', child: Text('أجازة عارضة')),
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
                    if (p != null) setState(() => date.value = p);
                  },
                ),
                if (actionType.value == 'إجازة' ||
                    actionType.value == 'غياب') ...[
                  TextField(
                    controller: daysController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: "🔢 عدد الأيام"),
                  ),
                ] else if (actionType.value == 'مكافئة' ||
                    actionType.value == 'جزاء') ...[
                  const SizedBox(height: 8),
                  ToggleButtons(
                    borderRadius: BorderRadius.circular(8),
                    isSelected: [
                      rewardType.value == 'amount',
                      rewardType.value == 'days'
                    ],
                    onPressed: (int index) => setState(() =>
                        rewardType.value = index == 0 ? 'amount' : 'days'),
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text("جنيه")),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text("أيام")),
                    ],
                  ),
                  if (rewardType.value == 'amount')
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "💰 المبلغ"),
                    )
                  else
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
                      decoration: const InputDecoration(labelText: "📅 الأيام"),
                    ),
                ] else if (actionType.value == 'إذن' ||
                    actionType.value == 'تأمين صحي') ...[
                  _buildTimeField("⏰ خروج", startTime, context, setState),
                  _buildTimeField("🔙 رجوع", endTime, context, setState),
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
                  } else {
                    bonusDaysToSave = bonusDays.value;
                  }
                }

                final updatedAction = WorkerAction(
                  id: action.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  type: actionType.value,
                  days: (actionType.value == 'إجازة' ||
                          actionType.value == 'أجازة عارضة' ||
                          actionType.value == 'غياب')
                      ? double.tryParse(daysController.text)
                      : 0,
                  date: date.value,
                  notes: notesController.text,
                  startTimeHour: startTime.value?.hour,
                  startTimeMinute: startTime.value?.minute,
                  endTimeHour: endTime.value?.hour,
                  endTimeMinute: endTime.value?.minute,
                  amount: amountToSave,
                  bonusDays: bonusDaysToSave,
                  factoryId: widget.worker.factoryId,
                  workerName: widget.worker.name,
                );

                final key = await actionBox.add(updatedAction);
                final saved = actionBox.get(key);
                if (saved != null) {
                  widget.worker.actions.removeAt(index);
                  widget.worker.actions.insert(index, saved);
                  await widget.worker.save();
                  SupabaseManager.pushData('worker_actions', saved.toJson());
                }
                if (context.mounted) Navigator.pop(context);
                _refresh();
              },
              child: const Text("✅ حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(String label, ValueNotifier<TimeOfDay?> timeNotifier,
      BuildContext context, StateSetter setState) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(
          onPressed: () async {
            final picked = await showTimePicker(
                context: context,
                initialTime: timeNotifier.value ?? TimeOfDay.now());
            if (picked != null) setState(() => timeNotifier.value = picked);
          },
          child: Text(timeNotifier.value?.format(context) ?? "اختر الوقت"),
        ),
      ],
    );
  }
}
