// lib/src/screens/sheet_size/new_sheet_size_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/new_sheet_size_form.dart';

class NewSheetSizeScreen extends StatelessWidget {
  final String? existingDataKey;
  final Map<String, dynamic>? existingData;

  const NewSheetSizeScreen({
    super.key,
    this.existingDataKey,
    this.existingData,
  });

  void _onCalculate(BuildContext context, Map<String, dynamic> sizeData) {
    debugPrint("البيانات المستلمة للحساب: $sizeData");

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ تمت العملية الحسابية بنجاح"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          existingDataKey == null ? "📏 حساب مقاس الشيت" : "✏️ تعديل المقاس",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ملاحظة بسيطة للمستخدم
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                // أزلنا const من هنا
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "سيتم حساب المقاس حالاً دون حفظه في سجلات البيانات.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900, // تم تصحيح اللون هنا
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            NewSheetSizeForm(
              existingData: existingData,
              onSave: (data) => _onCalculate(context, data),
            ),
          ],
        ),
      ),
    );
  }
}
