import 'package:flutter/material.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/utils/ui_utils.dart';

class ActiveAbsenceCard extends StatelessWidget {
  final Worker worker;
  final WorkerAction action;
  final VoidCallback onRefresh;

  const ActiveAbsenceCard({
    super.key,
    required this.worker,
    required this.action,
    required this.onRefresh,
  });

  int get elapsedDays {
    final now = DateTime.now();
    final start = action.date;
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(start.year, start.month, start.day);
    return today.difference(startDate).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isTimeBased = action.type == 'إذن' || action.type == 'تأمين صحي';
    
    final Color primaryColor = action.type == 'غياب' 
        ? Colors.red 
        : (action.type == 'إذن' ? Colors.blue : Colors.teal);

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? [primaryColor.withValues(alpha: 0.3), primaryColor.withValues(alpha: 0.1)]
                : [primaryColor.withValues(alpha: 0.05), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.2),
                  radius: 18,
                  child: Icon(_getIcon(), color: primaryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        action.type,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(
                  isTimeBased ? "وقت الخروج" : "بدأ في", 
                  isTimeBased ? (action.startTime?.format(context) ?? "--") : _formatDate(action.date)
                ),
                _buildInfoColumn(
                  "المدة", 
                  isTimeBased ? "قيد التنفيذ" : "$elapsedDays يوم"
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => isTimeBased ? _showTimeReturnDialog(context) : _showReturnDialog(context),
                icon: Icon(isTimeBased ? Icons.timer_outlined : Icons.login, size: 18),
                label: Text(isTimeBased ? "تسجيل عودة" : "إنهاء الغياب", style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (action.type) {
      case 'إذن': return Icons.access_time;
      case 'تأمين صحي': return Icons.medical_services_outlined;
      default: return Icons.person_off;
    }
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _showTimeReturnDialog(BuildContext context) async {
    final DateTime now = DateTime.now();
    
    action.returnDate = now;
    action.endTimeHour = now.hour;
    action.endTimeMinute = now.minute;
    await action.save();
    await worker.save();
    
    onRefresh();
    
    if (context.mounted) {
      UIUtils.showInfoSnackBar(
        message: "تم تسجيل عودة ${worker.name} بنجاح",
        backgroundColor: Colors.blue,
        icon: Icons.check_circle,
      );
    }
  }

  Future<void> _showReturnDialog(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime start = action.date;
    final DateTime initialReturnDate = DateTime(now.year, now.month, now.day);
    
    final returnDateNotifier = ValueNotifier<DateTime>(initialReturnDate);
    final daysController = TextEditingController();

    int calcDays() {
      final startDate = DateTime(start.year, start.month, start.day);
      final rDate = DateTime(returnDateNotifier.value.year, returnDateNotifier.value.month, returnDateNotifier.value.day);
      return rDate.difference(startDate).inDays;
    }

    daysController.text = calcDays().toString();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Colors.green),
              SizedBox(width: 10),
              Text("تسجيل عودة"),
            ],
          ),
          content: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("تاريخ العودة", style: TextStyle(fontSize: 14)),
                    subtitle: Text(_formatDate(returnDateNotifier.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_month, color: Colors.blue),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: returnDateNotifier.value,
                        firstDate: action.date,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          returnDateNotifier.value = picked;
                          daysController.text = calcDays().toString();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: daysController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "عدد الأيام النهائي",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.calculate_outlined),
                      suffixText: "يوم",
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () async {
                final finalDays = double.tryParse(daysController.text) ?? calcDays().toDouble();
                
                action.returnDate = returnDateNotifier.value;
                action.days = finalDays;
                await action.save();
                await worker.save();
                
                if (context.mounted) Navigator.pop(context);
                onRefresh();
                
                if (context.mounted) {
                  UIUtils.showInfoSnackBar(
                    message: "تم إغلاق غياب ${worker.name} بنجاح",
                    backgroundColor: Colors.green,
                    icon: Icons.check_circle,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text("تأكيد وحفظ"),
            ),
          ],
        ),
      ),
    );
  }
}
