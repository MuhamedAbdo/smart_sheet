import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/worker_action_model.dart';
import '../../models/worker_model.dart';
import '../../widgets/worker_action_card.dart';
import '../../widgets/active_absence_card.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/services/supabase_manager.dart';

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
  // FIX: أزلنا _setupSupabaseStream بالكامل — كانت تُسبّب تكرار الإجراءات
  // SyncService يتولى المزامنة اللحظية عبر worker_actions channel
  // الشاشة تستمع لتغييرات Hive مباشرةً عبر ValueListenableBuilder
  bool _isPhoneCopied = false;

  void _refresh() => setState(() {});

  String _f(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _copyPhoneToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.worker.phone));
    if (!mounted) return;
    setState(() => _isPhoneCopied = true);
    UIUtils.showInfoSnackBar(
      message: "تم نسخ الرقم بنجاح",
      backgroundColor: Colors.green,
      icon: Icons.content_copy_outlined,
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isPhoneCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = !kIsWeb && Platform.isWindows;

    // ValueListenableBuilder يُعيد البناء تلقائياً عند تغيير بيانات العامل
    // سواء من SyncService (مزامنة لحظية) أو من الإضافة/الحذف اليدوي
    return ValueListenableBuilder<Box<Worker>>(
      valueListenable: widget.box.listenable(keys: [widget.worker.key]),
      builder: (context, box, _) {
        final worker = box.get(widget.worker.key) ?? widget.worker;

        return Scaffold(
          appBar: AppBar(
            title: Text("👤 ${worker.name}"),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: isWindows ? _copyPhoneToClipboard : null,
                  child: Row(
                    children: [
                      Text(
                        "📞 ${worker.phone}",
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: _isPhoneCopied ? Colors.green : null,
                          fontWeight: _isPhoneCopied ? FontWeight.bold : null,
                        ),
                      ),
                      if (isWindows)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.copy, size: 14, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Text("🛠 ${worker.job}"),
                const SizedBox(height: 16),
                const Text("📜 الإجراءات",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                _buildActiveAbsenceSection(worker),
                Expanded(
                  child: worker.actions.isEmpty
                      ? const Center(
                          child: Text("لا توجد إجراءات لهذا العامل بعد"))
                      : ListView.builder(
                          itemCount: worker.actions.length,
                          itemBuilder: (context, index) {
                            // FIX: تحقق من الـ index لمنع RangeError عند التحديث المتزامن
                            if (index >= worker.actions.length) {
                              return const SizedBox.shrink();
                            }
                            final action = worker.actions[index];
                            return WorkerActionCard(
                              action: action,
                              onRefresh: _refresh,
                              onEdit: () async {
                                await _showEditActionDialog(
                                    context, worker, action, index);
                              },
                              onDelete: () {
                                if (index >= worker.actions.length) return;
                                final actionToRemove = worker.actions[index];
                                UIUtils.showDeleteConfirmation(
                                  context: context,
                                  title: "حذف الإجراء",
                                  content: "هل أنت متأكد من حذف هذا الإجراء؟",
                                  onConfirm: () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    if (index >= worker.actions.length) return;
                                    worker.actions.removeAt(index);
                                    await worker.save();
                                    if (!context.mounted) return;
                                    messenger.clearSnackBars();
                                    UIUtils.showUndoSnackBar(
                                      context: context,
                                      message: "تم حذف الإجراء",
                                      onUndo: () async {
                                        messenger.clearSnackBars();
                                        worker.actions
                                            .insert(index, actionToRemove);
                                        await worker.save();
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  onPressed: () => _showAddActionDialog(context, worker),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveAbsenceSection(Worker worker) {
    try {
      final activeAction = worker.actions.firstWhere(
        (a) =>
            (a.type == 'غياب' &&
                a.returnDate == null &&
                DateTime.now().difference(a.date).inDays <= 30) ||
            ((a.type == 'إذن' || a.type == 'تأمين صحي') &&
                a.returnDate == null),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          height: 190,
          child: ActiveAbsenceCard(
            worker: worker,
            action: activeAction,
            onRefresh: _refresh,
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  void _showAddActionDialog(BuildContext context, Worker worker) {
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
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: actionType.value,
                    items: const [
                      DropdownMenuItem(value: 'إجازة', child: Text('إجازة')),
                      DropdownMenuItem(
                          value: 'أجازة عارضة', child: Text('أجازة عارضة')),
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
                        decoration:
                            const InputDecoration(labelText: "💰 المبلغ"),
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
                        decoration:
                            const InputDecoration(labelText: "📅 الأيام"),
                      ),
                  ] else if (actionType.value == 'إذن' ||
                      actionType.value == 'تأمين صحي') ...[
                    _buildTimeField("⏰ خروج", startTime, context, setState),
                    _buildTimeField("🔙 رجوع", endTime, context, setState),
                  ],
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: "📝 ملاحظات"),
                  ),
                ],
              ),
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
                  factoryId: worker.factoryId,
                  workerName: worker.name,
                );
                final key = await actionBox.add(newAction);
                final saved = actionBox.get(key);
                if (saved != null) {
                  worker.actions.add(saved);
                  await worker.save();
                  SupabaseManager.pushData('worker_actions', saved.toJson());
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("✅ حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditActionDialog(BuildContext context, Worker worker,
      WorkerAction action, int index) async {
    final actionType = ValueNotifier<String>(action.type);
    final date = ValueNotifier<DateTime>(action.date);
    final daysController =
        TextEditingController(text: action.days?.toString() ?? '');
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
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: actionType.value,
                    items: const [
                      DropdownMenuItem(value: 'إجازة', child: Text('إجازة')),
                      DropdownMenuItem(
                          value: 'أجازة عارضة', child: Text('أجازة عارضة')),
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
                        decoration:
                            const InputDecoration(labelText: "💰 المبلغ"),
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
                        decoration:
                            const InputDecoration(labelText: "📅 الأيام"),
                      ),
                  ] else if (actionType.value == 'إذن' ||
                      actionType.value == 'تأمين صحي') ...[
                    _buildTimeField("⏰ خروج", startTime, context, setState),
                    _buildTimeField("🔙 رجوع", endTime, context, setState),
                  ],
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: "📝 ملاحظات"),
                  ),
                ],
              ),
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
                  id: action.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
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
                  factoryId: worker.factoryId,
                  workerName: worker.name,
                );
                final key = await actionBox.add(updatedAction);
                final saved = actionBox.get(key);
                // FIX: تحقق من index قبل التعديل
                if (saved != null && index < worker.actions.length) {
                  worker.actions.removeAt(index);
                  worker.actions.insert(index, saved);
                  await worker.save();
                  SupabaseManager.pushData('worker_actions', saved.toJson());
                }
                if (context.mounted) Navigator.pop(context);
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
