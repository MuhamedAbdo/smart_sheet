// lib/src/widgets/workers/worker_action_card.dart

import 'package:flutter/material.dart';
import '../../models/worker_action_model.dart';

class WorkerActionCard extends StatelessWidget {
  final WorkerAction action;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const WorkerActionCard({
    super.key,
    required this.action,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIcon(),
                    color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action.type,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (action.type == 'إجازة' || action.type == 'غياب') ...[
              _buildSectionTitle('🗓️ التواريخ'),
              _buildInfoRow('تاريخ البدء:', _f(action.date)),
              if (action.returnDate != null)
                _buildInfoRow('تاريخ العودة:', _f(action.returnDate!)),
              _buildInfoRow('عدد الأيام:', action.days.toStringAsFixed(0)),
            ] else if (action.type == 'مكافئة' || action.type == 'جزاء') ...[
              _buildSectionTitle('💰 القيمة'),
              if (action.amount != null)
                _buildInfoRow(
                    'المكافأة:', '${action.amount!.toStringAsFixed(2)} جنيه'),
              if (action.bonusDays != null)
                _buildInfoRow(
                    'أيام مكافئة:', _formatBonusDays(action.bonusDays!)),
            ] else if (action.type == 'إذن' || action.type == 'تأمين صحي') ...[
              _buildSectionTitle('⏰ التوقيت'),
              _buildInfoRow('التاريخ:', _f(action.date)),
              if (action.startTime != null)
                _buildInfoRow('وقت الخروج:', action.startTime!.format(context)),
              if (action.endTime != null)
                _buildInfoRow('وقت العودة:', action.endTime!.format(context)),
              if (action.duration != null)
                _buildInfoRow('المدة:', action.duration!),
            ],
            const SizedBox(height: 10),
            if (action.notes != null && action.notes!.isNotEmpty) ...[
              _buildSectionTitle('📝 الملاحظات'),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child:
                    Text(action.notes!, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit,
                        size: 18, color: Theme.of(context).primaryColor),
                    label: Text('تعديل',
                        style:
                            TextStyle(color: Theme.of(context).primaryColor)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon:
                        const Icon(Icons.delete, size: 18, color: Colors.white),
                    label: const Text('حذف',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (action.type) {
      case 'إجازة':
        return Icons.beach_access;
      case 'غياب':
        return Icons.block;
      case 'مكافئة':
        return Icons.attach_money;
      case 'جزاء':
        return Icons.gavel;
      case 'إذن':
        return Icons.access_time;
      case 'تأمين صحي':
        return Icons.medical_services;
      default:
        return Icons.list_alt;
    }
  }

  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
      );

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 120,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey))),
            const SizedBox(width: 8),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  String _f(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatBonusDays(double d) {
    if (d == 0.25) return '¼ يوم';
    if (d == 0.5) return '½ يوم';
    return '${d.toInt()} يوم';
  }
}
