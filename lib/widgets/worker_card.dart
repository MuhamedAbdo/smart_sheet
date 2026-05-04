import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/worker_model.dart';
import '../../utils/ui_utils.dart';

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
  bool _isPhoneCopied = false;

  // دالة إجراء المكالمة
  Future<void> _makePhoneCall(String phoneNumber) async {
    // تعطيل الاتصال على ويندوز
    if (!kIsWeb && Platform.isWindows) {
      _copyPhoneToClipboard();
      return;
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch $launchUri';
      }
    } catch (e) {
      UIUtils.showInfoSnackBar(
        message: "تعذر فتح تطبيق الاتصال",
        backgroundColor: Colors.red,
        icon: Icons.phone_disabled_outlined,
      );
    }
  }

  // دالة نسخ الرقم
  Future<void> _copyPhoneToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.worker.phone));

    if (!mounted) return;

    setState(() {
      _isPhoneCopied = true;
    });

    UIUtils.showInfoSnackBar(
      message: "تم نسخ الرقم بنجاح",
      backgroundColor: Colors.green,
      icon: Icons.content_copy_outlined,
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isPhoneCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final isWindows = !kIsWeb && Platform.isWindows;

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
              ],
            ),
            const SizedBox(height: 14),

            // عنوان قسم التواصل
            _buildSectionTitle(
              isWindows ? '📞 بيانات التواصل' : '📞 التواصل (اضغط للاتصال)',
              color: colorScheme.primary,
              underline: !isWindows,
              onTap: isWindows ? null : () => _makePhoneCall(widget.worker.phone),
            ),

            // صف الرقم
            GestureDetector(
              onTap: isWindows ? _copyPhoneToClipboard : null,
              onLongPress: !isWindows ? _copyPhoneToClipboard : null,
              child: _buildInfoRow(
                'الهاتف:',
                widget.worker.phone,
                labelColor: textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                valueColor: _isPhoneCopied ? Colors.green : null,
                textColor: textTheme.bodyMedium?.color,
                showCopyHint: isWindows,
                textDirection: TextDirection.ltr,
              ),
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

  Widget _buildSectionTitle(String title,
      {required Color color, bool underline = true, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
            decoration: underline ? TextDecoration.underline : null,
          ),
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
}
