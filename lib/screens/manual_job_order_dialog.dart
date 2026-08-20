import 'package:flutter/material.dart';

class ManualJobOrderDialog extends StatelessWidget {
  const ManualJobOrderDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('أمر تشغيل يدوي', textDirection: TextDirection.rtl),
      content: const Text(
        'قريباً: شاشة أمر التشغيل اليدوي',
        textDirection: TextDirection.rtl,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
