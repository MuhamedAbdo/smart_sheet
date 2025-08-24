// lib/src/widgets/flexo/ink_report_list.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:smart_sheet/models/ink_report.dart';

class InkReportList extends StatelessWidget {
  final Box<InkReport> box;
  final void Function(dynamic, Map<String, dynamic>) onEdit;
  final void Function(dynamic) onDelete;

  const InkReportList({
    super.key,
    required this.box,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: box.length,
      itemBuilder: (context, index) {
        final key = box.keyAt(index);
        final inkReport = box.getAt(index)!;

        final sizeText =
            '${inkReport.dimensions.length}/${inkReport.dimensions.width}/${inkReport.dimensions.height}';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "📅 ${inkReport.date}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),

                // ✅ اسم العميل
                Text("👤 ${inkReport.clientName}"),
                const SizedBox(height: 2),

                // ✅ الصنف
                Text("📦 ${inkReport.product}"),
                const SizedBox(height: 2),

                // ✅ كود الصنف
                Text("🔢 كود: ${inkReport.productCode}"),
                const SizedBox(height: 2),

                // ✅ المقاس
                Text("📏 $sizeText"),
                const SizedBox(height: 2),

                // ✅ الألوان
                if (inkReport.colors.isNotEmpty)
                  ...inkReport.colors
                      .map((c) => Text("🎨 ${c.color} - ${c.quantity} لتر"))
                      .toList(),

                // ✅ عدد الشيتات
                Text("🔢 عدد الشيتات: ${inkReport.quantity}"),

                // ✅ الملاحظات
                if (inkReport.notes?.isNotEmpty == true)
                  Text(
                    "📝 ${inkReport.notes!}",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),

                // ✅ الصور من الجهاز المحلي
                if (inkReport.imagePaths.isNotEmpty)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: inkReport.imagePaths.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: GestureDetector(
                          onTap: () => _showFullScreenImage(
                              context, inkReport.imagePaths, i),
                          child: Image.file(
                            File(inkReport.imagePaths[i]),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ✅ أزرار التعديل والحذف
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => onEdit(key, inkReport.toJson()),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => onDelete(key),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullScreenImage(
      BuildContext context, List<String> imagePaths, int initialIndex) {
    final PageController controller = PageController(initialPage: initialIndex);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Stack(
        alignment: Alignment.topRight,
        children: [
          PageView.builder(
            controller: controller,
            itemCount: imagePaths.length,
            itemBuilder: (context, i) => Center(
              child: PhotoView(
                imageProvider: FileImage(File(imagePaths[i])),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained * 1,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              controller.dispose();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
