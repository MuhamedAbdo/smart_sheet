import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/maintenance_record_model.dart';
import '../../widgets/full_screen_image_page.dart';

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
    final colorScheme = theme.colorScheme;
    final imagePaths = record.imagePaths;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- الرأس: اسم الماكينة وحالة الإصلاح ---
            Row(
              children: [
                Icon(Icons.settings_suggest,
                    color: colorScheme.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    record.machine,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary),
                  ),
                ),
                _buildStatusBadge(record.isFixed),
              ],
            ),
            const Divider(height: 24),

            // --- قسم التواريخ (كاملة) ---
            _buildSectionHeader(
                Icons.calendar_month, "التواريخ", colorScheme.primary),
            _buildInfoRow(Icons.event_note, "تاريخ العطل", record.issueDate),
            _buildInfoRow(Icons.notification_important, "تاريخ التبليغ",
                record.reportDate),
            _buildInfoRow(Icons.task_alt, "تاريخ التنفيذ", record.actionDate),

            const SizedBox(height: 12),

            // --- قسم التفاصيل الفنية (كاملة) ---
            _buildSectionHeader(
                Icons.build, "التفاصيل الفنية", colorScheme.primary),
            _buildInfoRow(
                Icons.report_problem, "وصف العطل", record.issueDescription),
            _buildInfoRow(Icons.handyman, "الإجراء المتخذ", record.actionTaken),
            _buildInfoRow(
                Icons.location_on, "مكان الإصلاح", record.repairLocation),
            _buildInfoRow(Icons.person, "بواسطة", record.repairedBy),

            // --- قسم الملاحظات (يظهر فقط إذا وجدت) ---
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSectionHeader(
                  Icons.notes, "الملاحظات", colorScheme.primary),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white10
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Text(record.notes!, style: const TextStyle(fontSize: 13)),
              ),
            ],

            // --- قسم الصور (تصميم ListView) ---
            if (imagePaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(
                  Icons.photo_library, "الصور المرفقة", colorScheme.primary),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imagePaths.length,
                  itemBuilder: (context, index) {
                    final path = imagePaths[index];
                    final isNetwork = path.startsWith('http');
                    return _buildImageThumbnail(
                        context, path, isNetwork, index, imagePaths);
                  },
                ),
              ),
            ],

            const SizedBox(height: 20),

            // --- أزرار التحكم ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text("تعديل"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon:
                        const Icon(Icons.delete, size: 18, color: Colors.white),
                    label: const Text("حذف",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- دوال مساعدة للبناء (Helpers) ---

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: ",
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey)),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isFixed) {
    final color = isFixed ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isFixed ? Icons.check_circle : Icons.pending,
              size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            isFixed ? "تم الإصلاح" : "تحت الصيانة",
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(BuildContext context, String path, bool isNetwork,
      int index, List<String> allPaths) {
    // فحص إضافي للتأكد إذا كان المسار يبدأ بـ http أو https
    final bool startsWithHttp = path.startsWith('http');

    return GestureDetector(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenImagePage(
                    imagesPaths: allPaths, initialIndex: index),
              ));
        },
        child: Container(
          margin: const EdgeInsets.only(left: 10),
          width: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: startsWithHttp
                ? Image.network(
                    path,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress ==
                            null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: Colors.red),
                  )
                : Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey),
                  ),
          ),
        ));
  }
}
