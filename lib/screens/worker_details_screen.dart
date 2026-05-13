import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/worker_action_model.dart';
import '../../models/worker_model.dart';
import '../../widgets/worker_action_card.dart';
import '../../widgets/active_absence_card.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';

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
    final stream =
        await SupabaseManager.streamData('worker_actions', primaryKey: ['id']);
    if (stream != null) {
      _supabaseSubscription = stream.listen((data) async {
        if (!Hive.isBoxOpen('worker_actions')) return;
        final actionBox = Hive.box<WorkerAction>('worker_actions');
        bool updated = false;

        for (var record in data) {
          if (record['worker_name'] != widget.worker.name) continue;

          final action = WorkerAction.fromJson(record);
          if (action.id == null) continue;

          final localIndex =
              widget.worker.actions.indexWhere((a) => a.id == action.id);
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

  Future<void> _copyPhoneToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.worker.phone));

    UIUtils.showInfoSnackBar(
      message: "تم نسخ الرقم بنجاح",
      backgroundColor: Colors.green,
      icon: Icons.content_copy_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = !kIsWeb && Platform.isWindows;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text("👤 ${widget.worker.name}"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Worker Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 25,
                          child: Icon(Icons.person, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.worker.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "🛠 ${widget.worker.job}",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildWorkerStatusChip(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeaderAction(
                          icon: Icons.phone,
                          label: "اتصال",
                          color: Colors.green,
                          onTap: () => _launchURL("tel:${widget.worker.phone}"),
                        ),
                        _buildHeaderAction(
                          icon: Icons.message,
                          label: "واتساب",
                          color: const Color(0xFF25D366),
                          onTap: () => _launchWhatsApp(widget.worker.phone),
                        ),
                        if (isWindows)
                          _buildHeaderAction(
                            icon: Icons.copy,
                            label: "نسخ الرقم",
                            color: Colors.blue,
                            onTap: _copyPhoneToClipboard,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.history, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "📜 السجل الإجرائي",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  "${widget.worker.actions.length} إجراء",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const Divider(),
            _buildActiveAbsenceSection(),
            Expanded(
              child: widget.worker.actions.isEmpty
                  ? const Center(child: Text("لا توجد إجراءات لهذا العامل بعد"))
                  : ListView.builder(
                      itemCount: widget.worker.actions.length,
                      itemBuilder: (context, index) {
                        // Sort actions by date descending
                        final sortedActions = widget.worker.actions.toList()
                          ..sort((a, b) => b.date.compareTo(a.date));
                        final action = sortedActions[index];
                        final originalIndex =
                            widget.worker.actions.indexOf(action);

                        return WorkerActionCard(
                          action: action,
                          onRefresh: _refresh,
                          onEdit: () async {
                            _editAction(action, originalIndex);
                            _refresh();
                          },
                          onDelete: () {
                            UIUtils.showDeleteConfirmation(
                              context: context,
                              title: "حذف الإجراء",
                              content: "هل أنت متأكد من حذف هذا الإجراء؟",
                              onConfirm: () async {
                                final messenger = ScaffoldMessenger.of(context);

                                // Deleting from HiveList, HiveBox, and Syncing to Supabase
                                final actionToDelete =
                                    widget.worker.actions[originalIndex];
                                final actionJson = actionToDelete.toJson();

                                widget.worker.actions.removeAt(originalIndex);
                                await widget.worker.save();

                                // Delete from box
                                if (actionToDelete.isInBox) {
                                  await actionToDelete.delete();
                                }

                                // Sync deletion to Supabase
                                SyncService.instance.pushToQueue(
                                    'worker_actions', actionJson,
                                    operation: 'delete');

                                if (!context.mounted) return;

                                messenger.clearSnackBars();
                                UIUtils.showUndoSnackBar(
                                  context: context,
                                  message: "تم حذف الإجراء",
                                  onUndo: () async {
                                    final actionBox = Hive.box<WorkerAction>(
                                        'worker_actions');
                                    final restoredAction =
                                        WorkerAction.fromJson(actionJson);
                                    final key =
                                        await actionBox.add(restoredAction);
                                    final saved = actionBox.get(key);

                                    if (saved != null) {
                                      widget.worker.actions
                                          .insert(originalIndex, saved);
                                      await widget.worker.save();
                                      // Sync back to Supabase
                                      SyncService.instance.pushToQueue(
                                          'worker_actions', saved.toJson());
                                      _refresh();
                                    }
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "worker_details_fab",
        onPressed: () => _showAddActionDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildActiveAbsenceSection() {
    final activeAction = widget.worker.activeAction;
    // Skip old actions (more than 30 days ago) to keep the view clean
    if (activeAction == null || DateTime.now().difference(activeAction.date).inDays > 30) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: 190,
        child: ActiveAbsenceCard(
          worker: widget.worker,
          action: activeAction,
          onRefresh: _refresh,
          onEdit: () {
            // Find index of this action to allow editing
            final idx = widget.worker.actions.indexOf(activeAction);
            _editAction(activeAction, idx);
          },
        ),
      ),
    );
  }

  void _showAddActionDialog(BuildContext context) => _showActionBottomSheet();

  void _editAction(WorkerAction action, int index) =>
      _showActionBottomSheet(existingAction: action, index: index);

  void _showActionBottomSheet({WorkerAction? existingAction, int? index}) {
    final actionType = ValueNotifier<String>(existingAction?.type ?? 'إجازة');
    final date = ValueNotifier<DateTime>(existingAction?.date ?? DateTime.now());
    final calculatedDays = ValueNotifier<double>(existingAction?.days ?? 1.0);
    final startTime = ValueNotifier<TimeOfDay?>(existingAction?.startTime);
    final endTime = ValueNotifier<TimeOfDay?>(existingAction?.endTime);
    final rewardType = ValueNotifier<String>(
        existingAction?.amount != null ? 'amount' : 'days');
    final amountController =
        TextEditingController(text: existingAction?.amount?.toString() ?? '');
    final bonusDays = ValueNotifier<double?>(existingAction?.bonusDays);
    final notesController =
        TextEditingController(text: existingAction?.notes ?? '');
    final returnDate = ValueNotifier<DateTime?>(existingAction?.returnDate);

    void updateCalculatedDays() {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final shiftStart = themeProvider.shiftStart;
      final shiftEnd = themeProvider.shiftEnd;

      // Calculate shift duration in hours
      double shiftHours = shiftEnd.hour + shiftEnd.minute / 60.0 - (shiftStart.hour + shiftStart.minute / 60.0);
      if (shiftHours <= 0) shiftHours += 24;

      if (returnDate.value != null) {
        final start = DateTime(date.value.year, date.value.month, date.value.day, 
            startTime.value?.hour ?? shiftStart.hour, startTime.value?.minute ?? shiftStart.minute);
        final end = DateTime(returnDate.value!.year, returnDate.value!.month, returnDate.value!.day, 
            endTime.value?.hour ?? shiftEnd.hour, endTime.value?.minute ?? shiftEnd.minute);
        
        final diffMinutes = end.difference(start).inMinutes;
        if (diffMinutes <= 0) {
          calculatedDays.value = 0.0;
          return;
        }

        final totalHours = diffMinutes / 60.0;
        final fullDays = (totalHours / 24).floor();
        final remainingHours = totalHours % 24;

        double partialDay = 0.0;
        if (remainingHours >= shiftHours - 1) {
          partialDay = 1.0;
        } else if (remainingHours >= (shiftHours / 2) - 1 && remainingHours <= (shiftHours / 2) + 1.5) {
          // توسيع النطاق قليلاً ليشمل 3 و 4 و 5 ساعات إذا كانت الوردية 8 ساعات
          partialDay = 0.5;
        } else if (remainingHours > (shiftHours / 2) + 1.5) {
          // إذا كانت أكثر من نصف الوردية بوضوح ولكن لم تصل للوردية الكاملة
          partialDay = 0.5; 
        }

        calculatedDays.value = fullDays + partialDay;
      } else if (startTime.value != null && endTime.value != null) {
        // Same day partial absence (Permission/إذن)
        double duration = endTime.value!.hour + endTime.value!.minute / 60.0 - (startTime.value!.hour + startTime.value!.minute / 60.0);
        if (duration < 0) duration += 24;

        if (duration >= shiftHours - 1) {
          calculatedDays.value = 1.0;
        } else if (duration >= (shiftHours / 2) - 1 && duration <= (shiftHours / 2) + 1.5) {
          calculatedDays.value = 0.5;
        } else if (duration > (shiftHours / 2) + 1.5) {
          calculatedDays.value = 0.5;
        } else {
          calculatedDays.value = 0.0;
        }
      }
    }

    // Initial check if we are editing an existing action
    if (existingAction != null && (existingAction.days == 0 || existingAction.days == null) && existingAction.returnDate != null) {
       final start = DateTime(existingAction.date.year, existingAction.date.month, existingAction.date.day);
       final end = DateTime(existingAction.returnDate!.year, existingAction.returnDate!.month, existingAction.returnDate!.day);
       final diff = end.difference(start).inDays;
       calculatedDays.value = diff.toDouble();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    children: [
                      Text(
                        existingAction == null
                            ? "➕ إضافة ${actionType.value}"
                            : "🔄 تعديل الإجراء",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
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
                        onChanged: (v) {
                          setState(() => actionType.value = v ?? 'إجازة');
                          updateCalculatedDays();
                        },
                        decoration:
                            const InputDecoration(labelText: "نوع الإجراء"),
                      ),
                      if (actionType.value == 'إجازة' ||
                          actionType.value == 'غياب' ||
                          actionType.value == 'أجازة عارضة' ||
                          actionType.value == 'إذن' ||
                          actionType.value == 'تأمين صحي') ...[
                        const SizedBox(height: 12),
                        // Row 1: Start Date & Time
                        Row(
                          children: [
                            Expanded(child: _buildDateField("📅 تاريخ القيام", date as ValueNotifier<DateTime?>, context, setState, updateCalculatedDays: updateCalculatedDays)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTimeField("⏰ وقت القيام", startTime, context, setState, updateCalculatedDays: updateCalculatedDays)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Row 2: Return Date & Time
                        Row(
                          children: [
                            Expanded(child: _buildDateField("🔙 تاريخ العودة", returnDate, context, setState, isOptional: true, updateCalculatedDays: updateCalculatedDays)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTimeField("🕒 وقت العودة", endTime, context, setState, updateCalculatedDays: updateCalculatedDays)),
                          ],
                        ),
                        if (actionType.value == 'إجازة' ||
                            actionType.value == 'غياب' ||
                            actionType.value == 'أجازة عارضة') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.calculate_outlined, color: Colors.grey, size: 20),
                                    SizedBox(width: 8),
                                    Text("عدد الأيام المحسوب:", style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                ValueListenableBuilder<double>(
                                  valueListenable: calculatedDays,
                                  builder: (context, val, _) => Text(
                                    "$val يوم",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else if (actionType.value == 'مكافئة' ||
                          actionType.value == 'جزاء') ...[
                        const SizedBox(height: 12),
                        _buildDateField("📅 التاريخ", date as ValueNotifier<DateTime?>, context, setState),
                        const SizedBox(height: 12),
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
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text("جنيه")),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text("أيام")),
                          ],
                        ),
                        if (rewardType.value == 'amount') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: "💰 المبلغ"),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
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
                        ],
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: "📝 ملاحظات"),
                      ),
                      const SizedBox(height: 12),
                                            const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("❌ إلغاء"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                final actionBox =
                                    Hive.box<WorkerAction>('worker_actions');
                                double? amountToSave;
                                double? bonusDaysToSave;

                                if (actionType.value == 'مكافئة' ||
                                    actionType.value == 'جزاء') {
                                  if (rewardType.value == 'amount') {
                                    amountToSave =
                                        double.tryParse(amountController.text);
                                  } else {
                                    bonusDaysToSave = bonusDays.value;
                                  }
                                }

                                if (existingAction == null) {
                                  final updatedAction = WorkerAction(
                                    type: actionType.value,
                                    days: (actionType.value == 'إجازة' ||
                                            actionType.value == 'أجازة عارضة' ||
                                            actionType.value == 'غياب')
                                        ? calculatedDays.value
                                        : 0,
                                    date: date.value,
                                    returnDate: returnDate.value,
                                    notes: notesController.text,
                                    startTimeHour: startTime.value?.hour,
                                    startTimeMinute: startTime.value?.minute,
                                    endTimeHour: endTime.value?.hour,
                                    endTimeMinute: endTime.value?.minute,
                                    amount: amountToSave,
                                    bonusDays: bonusDaysToSave,
                                    factoryId: widget.worker.factoryId,
                                    workerName: widget.worker.name,
                                    workerId: widget.worker.id,
                                  );
                                  final key = await actionBox.add(updatedAction);
                                  final saved = actionBox.get(key);
                                  if (saved != null) {
                                    widget.worker.actions.insert(0, saved);
                                    await widget.worker.save();
                                    SupabaseManager.pushData(
                                        'worker_actions', saved.toJson());
                                  }
                                } else {
                                  // Edit existing action via mutation
                                  existingAction.type = actionType.value;
                                  existingAction.days = (actionType.value == 'إجازة' ||
                                          actionType.value == 'أجازة عارضة' ||
                                          actionType.value == 'غياب')
                                      ? calculatedDays.value
                                      : 0;
                                  existingAction.date = date.value;
                                  existingAction.returnDate = returnDate.value;
                                  existingAction.notes = notesController.text;
                                  existingAction.startTimeHour = startTime.value?.hour;
                                  existingAction.startTimeMinute = startTime.value?.minute;
                                  existingAction.endTimeHour = endTime.value?.hour;
                                  existingAction.endTimeMinute = endTime.value?.minute;
                                  existingAction.amount = amountToSave;
                                  existingAction.bonusDays = bonusDaysToSave;
                                  
                                  await existingAction.save();
                                  await widget.worker.save();
                                  SupabaseManager.pushData(
                                      'worker_actions', existingAction.toJson());
                                }

                                if (context.mounted) Navigator.pop(context);
                                _refresh();
                              },
                              child: Text(existingAction == null
                                  ? "✅ إضافة"
                                  : "✅ حفظ التعديلات"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, ValueNotifier<DateTime?> dateNotifier,
      BuildContext context, StateSetter setState, {bool isOptional = false, VoidCallback? updateCalculatedDays}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dateNotifier.value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => dateNotifier.value = picked);
              if (updateCalculatedDays != null) updateCalculatedDays();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateNotifier.value != null ? _f(dateNotifier.value!) : "لم يحدد",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (isOptional && dateNotifier.value != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() => dateNotifier.value = null);
                      if (updateCalculatedDays != null) updateCalculatedDays();
                    },
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  )
                else
                  const Icon(Icons.calendar_month, size: 16, color: Colors.blue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(String label, ValueNotifier<TimeOfDay?> timeNotifier,
      BuildContext context, StateSetter setState, {VoidCallback? updateCalculatedDays}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
                context: context,
                initialTime: timeNotifier.value ?? TimeOfDay.now());
            if (picked != null) {
              setState(() => timeNotifier.value = picked);
              if (updateCalculatedDays != null) updateCalculatedDays();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeNotifier.value?.format(context) ?? "لم يحدد",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (timeNotifier.value != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => setState(() => timeNotifier.value = null),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  )
                else
                  const Icon(Icons.access_time, size: 16, color: Colors.blue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  
  Widget _buildWorkerStatusChip() {
    final activeAction = widget.worker.activeAction;
    final isPresent = activeAction == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPresent ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPresent ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPresent ? Icons.check_circle : Icons.timer,
            size: 14,
            color: isPresent ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isPresent
                ? "متواجد"
                : (activeAction.isTimeBased
                    ? "خارج العمل (${activeAction.type})"
                    : "في ${activeAction.type}"),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPresent ? Colors.green.shade700 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح تطبيق الهاتف'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    try {
      // Clean phone number - remove all non-digit characters and spaces
      String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      
      // Remove leading zeros and add country code if needed
      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }
      
      // Add Egypt country code if not present
      if (!cleanPhone.startsWith('20') && !cleanPhone.startsWith('+20')) {
        cleanPhone = '20$cleanPhone';
      }
      
      // Remove + if present to ensure clean format for wa.me
      if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      }
      
      debugPrint('Cleaned phone for WhatsApp: $cleanPhone');
      
      // Default message in Arabic
      const defaultMessage = 'السلام عليكم';
      final encodedMessage = Uri.encodeComponent(defaultMessage);
      final url = "https://wa.me/$cleanPhone?text=$encodedMessage";
      
      debugPrint('WhatsApp URL: $url');
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح تطبيق الواتساب. يرجى التأكد من تثبيت التطبيق'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ عند فتح الواتساب: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
