// lib/src/widgets/store/store_entry_card.dart

import 'package:flutter/material.dart';
import '../../models/store_entry_model.dart';

class StoreEntryCard extends StatelessWidget {
  final StoreEntry record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StoreEntryCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Row(
              children: [
                Icon(
                  Icons.inventory,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "📦 ${record.product}",
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

            // التفاصيل
            _buildSectionTitle('📦 التفاصيل', color: colorScheme.primary),
            _buildInfoRow(
              'التاريخ:',
              record.date,
              labelColor: _withOpacity(textTheme.bodyMedium?.color, 0.8),
              valueColor: textTheme.bodyMedium?.color,
            ),
            _buildInfoRow(
              'الوحدة:',
              record.unit,
              labelColor: _withOpacity(textTheme.bodyMedium?.color, 0.8),
              valueColor: textTheme.bodyMedium?.color,
            ),
            _buildInfoRow(
              'الكمية:',
              record.quantity.toString(),
              labelColor: _withOpacity(textTheme.bodyMedium?.color, 0.8),
              valueColor: textTheme.bodyMedium?.color,
            ),
            const SizedBox(height: 10),

            // الملاحظات (إن وُجدت)
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              _buildSectionTitle('📝 الملاحظات', color: colorScheme.primary),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  record.notes!,
                  style: TextStyle(
                    fontSize: 14,
                    color: textTheme.bodyMedium?.color,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // أزرار التحكم
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    label: Text(
                      'تعديل',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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

  // دالة مساعدة لضبط الشفافية بدون استخدام withOpacity (deprecated)
  Color? _withOpacity(Color? color, double opacity) {
    if (color == null) return null;
    final alpha = (opacity * 255).clamp(0, 255).toInt();
    return color.withAlpha(alpha);
  }

  Widget _buildSectionTitle(String title, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? labelColor, Color? valueColor}) {
    if (value.isEmpty) return const SizedBox.shrink();
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
