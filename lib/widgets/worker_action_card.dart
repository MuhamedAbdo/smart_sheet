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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

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
                Icon(_getIcon(), color: colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action.type,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // التعديل المطلوب: الأجازة والغياب فقط
            if (action.type == 'إجازة' || action.type == 'غياب') ...[
              _buildSectionTitle('🗓️ البيانات', color: colorScheme.primary),
              _buildInfoRow(
                'تاريخ البدء:',
                _f(action.date),
                labelColor: textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                valueColor: textTheme.bodyMedium?.color,
              ),
              _buildInfoRow(
                'عدد الأيام:',
                action.days.toStringAsFixed(1), // رقم عشري واحد
                labelColor: textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                valueColor: textTheme.bodyMedium?.color,
              ),
            ]
            // باقي الإجراءات كما كانت في ملفك الأصلي تماماً
            else if (action.type == 'مكافئة' || action.type == 'جزاء') ...[
              _buildSectionTitle('💰 القيمة', color: colorScheme.primary),
              if (action.amount != null)
                _buildInfoRow(
                  'المكافأة:',
                  '${action.amount!.toStringAsFixed(2)} جنيه',
                  labelColor:
                      textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  valueColor: textTheme.bodyMedium?.color,
                ),
              if (action.bonusDays != null)
                _buildInfoRow(
                  'أيام مكافئة:',
                  _formatBonusDays(action.bonusDays!),
                  labelColor:
                      textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  valueColor: textTheme.bodyMedium?.color,
                ),
            ] else if (action.type == 'إذن' || action.type == 'تأمين صحي') ...[
              _buildSectionTitle('⏰ التوقيت', color: colorScheme.primary),
              _buildInfoRow(
                'التاريخ:',
                _f(action.date),
                labelColor: textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                valueColor: textTheme.bodyMedium?.color,
              ),
              if (action.startTime != null)
                _buildInfoRow(
                  'وقت الخروج:',
                  action.startTime!.format(context),
                  labelColor:
                      textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  valueColor: textTheme.bodyMedium?.color,
                ),
              if (action.endTime != null)
                _buildInfoRow(
                  'وقت العودة:',
                  action.endTime!.format(context),
                  labelColor:
                      textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  valueColor: textTheme.bodyMedium?.color,
                ),
              if (action.duration != null)
                _buildInfoRow(
                  'المدة:',
                  action.duration!,
                  labelColor:
                      textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  valueColor: textTheme.bodyMedium?.color,
                ),
            ],

            const SizedBox(height: 10),
            if (action.notes != null && action.notes!.isNotEmpty) ...[
              _buildSectionTitle('📝 الملاحظات', color: colorScheme.primary),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[700]!
                          : Colors.grey[300]!),
                ),
                child: Text(
                  action.notes!,
                  style: TextStyle(
                      fontSize: 14, color: textTheme.bodyMedium?.color),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon:
                        Icon(Icons.edit, size: 18, color: colorScheme.primary),
                    label: Text('تعديل',
                        style: TextStyle(color: colorScheme.primary)),
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

  // الدوال المساعدة كما هي
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

  Widget _buildSectionTitle(String title, {required Color color}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      );

  Widget _buildInfoRow(String label, String value,
      {Color? labelColor, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor)),
          ),
        ],
      ),
    );
  }

  String _f(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatBonusDays(double d) {
    if (d == 0.25) return '¼ يوم';
    if (d == 0.5) return '½ يوم';
    return '${d.toInt()} يوم';
  }
}
