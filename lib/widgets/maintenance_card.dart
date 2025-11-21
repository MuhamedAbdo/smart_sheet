// lib/src/widgets/maintenance/maintenance_card.dart

import 'package:flutter/material.dart';
import 'dart:io';

class MaintenanceCard extends StatelessWidget {
  final Map<String, dynamic> record;
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
    // ✅ استخراج مسارات الصور
    final imagePaths = (record['imagePaths'] as List?)?.cast<String>() ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ العنوان الرئيسي والمعلومات الأساسية
            Row(
              children: [
                Icon(Icons.build, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record['machine']?.toString() ?? 'ماكينة غير محددة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                // ✅ حالة الإصلاح
                Chip(
                  label: Text(
                    record['isFixed'] == true ? 'تم الإصلاح' : 'قيد الإصلاح',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor:
                      record['isFixed'] == true ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ✅ قسم التواريخ
            _buildSectionTitle('📅 التواريخ'),
            _buildInfoRow('تاريخ ظهور العطل:',
                record['issueDate']?.toString() ?? 'غير محدد'),
            _buildInfoRow('تاريخ التبليغ:',
                record['reportDate']?.toString() ?? 'غير محدد'),
            _buildInfoRow('تاريخ التنفيذ:',
                record['actionDate']?.toString() ?? 'غير محدد'),

            const SizedBox(height: 8),

            // ✅ قسم المعلومات الفنية
            _buildSectionTitle('🔧 المعلومات الفنية'),
            _buildInfoRow('وصف العطل:',
                record['issueDescription']?.toString() ?? 'لا يوجد وصف'),
            _buildInfoRow('الإجراء المتخذ:',
                record['actionTaken']?.toString() ?? 'لا يوجد إجراء'),
            _buildInfoRow('مكان الإصلاح:',
                record['repairLocation']?.toString() ?? 'غير محدد'),
            _buildInfoRow('تم الإصلاح بواسطة:',
                record['repairedBy']?.toString() ?? 'غير محدد'),
            _buildInfoRow('تم التبليغ إلى:',
                record['reportedToTechnician']?.toString() ?? 'غير محدد'),

            const SizedBox(height: 8),

            // ✅ قسم الملاحظات
            if (record['notes'] != null &&
                record['notes'].toString().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('📝 الملاحظات'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.grey.shade300), // ✅ إصلاح هنا
                    ),
                    child: Text(
                      record['notes']?.toString() ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),

            // ✅ قسم الصور
            if (imagePaths.isNotEmpty) ...[
              _buildSectionTitle('📸 الصور المرفقة'),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imagePaths.length,
                  itemBuilder: (context, index) {
                    final imagePath = imagePaths[index];
                    final file = File(imagePath);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _showFullScreenImage(context, file);
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.grey.shade400), // ✅ إصلاح هنا
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error,
                                            color: Colors.red, size: 24),
                                        SizedBox(height: 4),
                                        Text(
                                          'خطأ',
                                          style: TextStyle(
                                              fontSize: 10, color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'عدد الصور: ${imagePaths.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ✅ أزرار التحكم
            Container(
              decoration: BoxDecoration(
                border: Border(
                    top:
                        BorderSide(color: Colors.grey.shade300)), // ✅ إصلاح هنا
                color: Colors.grey[50],
              ),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit,
                          size: 18, color: Theme.of(context).primaryColor),
                      label: Text(
                        'تعديل',
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete,
                          size: 18, color: Colors.white),
                      label: const Text('حذف',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, File imageFile) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  imageFile,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
