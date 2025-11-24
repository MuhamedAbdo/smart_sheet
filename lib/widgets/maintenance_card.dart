// lib/src/widgets/maintenance/maintenance_card.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/maintenance_record_model.dart';
import '../../widgets/full_screen_image_page.dart'; // تأكد من المسار الصحيح

class MaintenanceCard extends StatelessWidget {
  final MaintenanceRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MaintenanceCard({
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

    final imagePaths = record.imagePaths;

    Widget buildStatusBadge() {
      if (record.isFixed) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade100.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade400),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 16, color: Colors.green),
              SizedBox(width: 4),
              Text(
                'تم الإصلاح',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade100.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade400),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, size: 16, color: Colors.orange),
              SizedBox(width: 4),
              Text(
                'قيد الصيانة',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }
    }

    // دالة مساعدة لضبط الشفافية (بدون withOpacity deprecated)
    Color? withOpacity(Color? color, double opacity) {
      if (color == null) return null;
      final alpha = (opacity * 255).clamp(0, 255).toInt();
      return color.withAlpha(alpha);
    }

    final dimmedTextColor = withOpacity(textTheme.bodyMedium?.color, 0.8);

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
                  Icons.build,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    record.machine,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                buildStatusBadge(),
              ],
            ),
            const SizedBox(height: 14),
            _buildSectionTitle('📅 التواريخ', color: colorScheme.primary),
            _buildInfoRow('تاريخ العطل:', record.issueDate,
                labelColor: dimmedTextColor,
                valueColor: textTheme.bodyMedium?.color),
            _buildInfoRow('تاريخ التبليغ:', record.reportDate,
                labelColor: dimmedTextColor,
                valueColor: textTheme.bodyMedium?.color),
            _buildInfoRow('تاريخ التنفيذ:', record.actionDate,
                labelColor: dimmedTextColor,
                valueColor: textTheme.bodyMedium?.color),
            const SizedBox(height: 10),
            _buildSectionTitle('🔧 المعلومات الفنية',
                color: colorScheme.primary),
            _buildInfoRow('وصف العطل:', record.issueDescription,
                labelColor: dimmedTextColor,
                valueColor: textTheme.bodyMedium?.color),
            _buildInfoRow('الإجراء المتخذ:', record.actionTaken,
                labelColor: dimmedTextColor,
                valueColor: textTheme.bodyMedium?.color),
            _buildInfoRow('مكان الإصلاح:', record.repairLocation,
                labelColor: dimmedTextColor,
                valueColor: textTheme.bodyMedium?.color),
            _buildInfoRow('تم الإصلاح بواسطة:', record.repairedBy,
                labelColor: dimmedTextColor,
                valueColor: textTheme.bodyMedium?.color),
            _buildInfoRow('تم التبليغ إلى:', record.reportedToTechnician,
                labelColor: dimmedTextColor,
                valueColor: textTheme.bodyMedium?.color),
            const SizedBox(height: 10),
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
            if (imagePaths.isNotEmpty) ...[
              _buildSectionTitle('📸 الصور المرفقة',
                  color: colorScheme.primary),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imagePaths.length,
                  itemBuilder: (context, index) {
                    final file = File(imagePaths[index]);
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () {
                          // جلب الصور الموجودة فقط
                          final validImages = imagePaths
                              .map((path) => File(path))
                              .where((f) => f.existsSync())
                              .toList();

                          if (validImages.isEmpty) return;

                          final currentIndex = validImages
                              .indexWhere((f) => f.path == file.path);
                          if (currentIndex == -1) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImagePage(
                                images: validImages,
                                initialIndex: currentIndex,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : Container(
                                    color: brightness == Brightness.dark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
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
            width: 120,
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
