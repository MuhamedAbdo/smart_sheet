import 'package:flutter/material.dart';

import '../../models/worker_model.dart';

class WorkerCard extends StatefulWidget {
  final Worker worker;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const WorkerCard({
    super.key,
    required this.worker,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<WorkerCard> createState() => _WorkerCardState();
}

class _WorkerCardState extends State<WorkerCard> {



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
                Icon(
                  Icons.person,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "👤 ${widget.worker.name}",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                _buildStatusDot(),
              ],
            ),
            
            _buildInfoRow(
              'الوظيفة:',
              widget.worker.job,
              labelColor: textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              textColor: textTheme.bodyMedium?.color,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onTap,
                    icon: Icon(Icons.list_alt,
                        size: 18, color: colorScheme.primary),
                    label: Text('التفاصيل',
                        style: TextStyle(color: colorScheme.primary)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onEdit,
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
                    onPressed: widget.onDelete,
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


  Widget _buildInfoRow(
    String label,
    String value, {
    Color? labelColor,
    Color? valueColor,
    Color? textColor,
    bool showCopyHint = false,
    TextDirection? textDirection,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textDirection: textDirection,
              textAlign: textDirection == TextDirection.ltr ? TextAlign.right : null,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? textColor,
              ),
            ),
          ),
          if (showCopyHint)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.copy, size: 14, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusDot() {
    final isOut = widget.worker.isOut;
    return Tooltip(
      message: isOut ? 'خارج العمل' : 'متواجد',
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: isOut ? Colors.orange : Colors.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isOut ? Colors.orange : Colors.green).withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
