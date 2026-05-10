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
    final daysController =
        TextEditingController(text: existingAction?.days?.toString() ?? '1.0');
    final startTime = ValueNotifier<TimeOfDay?>(existingAction?.startTime);
    final endTime = ValueNotifier<TimeOfDay?>(existingAction?.endTime);
    final rewardType = ValueNotifier<String>(
        existingAction?.amount != null ? 'amount' : 'days');
    final amountController =
        TextEditingController(text: existingAction?.amount?.toString() ?? '');
    final bonusDays = ValueNotifier<double?>(existingAction?.bonusDays);
    final notesController =
        TextEditingController(text: existingAction?.notes ?? '');

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
                        onChanged: (v) =>
                            setState(() => actionType.value = v ?? 'إجازة'),
                        decoration:
                            const InputDecoration(labelText: "نوع الإجراء"),
                      ),
                      const SizedBox(height: 12),
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
                          actionType.value == 'غياب' ||
                          actionType.value == 'أجازة عارضة') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: daysController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: "🔢 عدد الأيام"),
                        ),
                      ] else if (actionType.value == 'مكافئة' ||
                          actionType.value == 'جزاء') ...[
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
                      ] else if (actionType.value == 'إذن' ||
                          actionType.value == 'تأمين صحي') ...[
                        const SizedBox(height: 12),
                        _buildTimeField("⏰ خروج", startTime, context, setState),
                        _buildTimeField("🔙 رجوع", endTime, context, setState),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: "📝 ملاحظات"),
                      ),
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

                                final updatedAction = WorkerAction(
                                  id: existingAction?.id ??
                                      DateTime.now()
                                          .millisecondsSinceEpoch
                                          .toString(),
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

                                if (existingAction == null) {
                                  final key = await actionBox.add(updatedAction);
                                  final saved = actionBox.get(key);
                                  if (saved != null) {
                                    widget.worker.actions.insert(0, saved);
                                    await widget.worker.save();
                                    SupabaseManager.pushData(
                                        'worker_actions', saved.toJson());
                                  }
                                } else if (index != null) {
                                  final key = (Hive.box<WorkerAction>(
                                              'worker_actions')
                                          .keys
                                          .toList())[Hive.box<WorkerAction>(
                                              'worker_actions')
                                          .values
                                          .toList()
                                          .indexOf(existingAction)];
                                  await actionBox.put(key, updatedAction);
                                  widget.worker.actions[index] = updatedAction;
                                  await widget.worker.save();
                                  SupabaseManager.pushData(
                                      'worker_actions', updatedAction.toJson());
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
      // Clean phone number - remove all non-digit characters
      String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      
      // Add country code if not present (assuming Egypt +20 as default)
      if (!cleanPhone.startsWith('20') && cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
        cleanPhone = '20${cleanPhone.substring(1)}';
      } else if (!cleanPhone.startsWith('+') && !cleanPhone.startsWith('20') && cleanPhone.length == 10) {
        cleanPhone = '20$cleanPhone';
      }
      
      // Default message in Arabic
      const defaultMessage = 'السلام عليكم';
      final encodedMessage = Uri.encodeComponent(defaultMessage);
      final url = "https://wa.me/$cleanPhone?text=$encodedMessage";
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح تطبيق الواتساب'),
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
}
