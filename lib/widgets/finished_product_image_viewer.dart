// lib/src/widgets/finished_product_image_viewer.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:smart_sheet/widgets/full_screen_image_page.dart'; // استيراد صفحة العرض الكامل

class FinishedProductImageViewer extends StatelessWidget {
  final List<String> imagePaths; // تلقي مسارات الصور كـ String

  const FinishedProductImageViewer({
    super.key,
    required this.imagePaths,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return const SizedBox.shrink(); // لا شيء لعرضه
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imagePaths.length,
        itemBuilder: (context, imgIndex) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: GestureDetector(
            onTap: () => _showFullScreenImage(
              context,
              imagePaths
                  .map((path) => File(path))
                  .toList(), // تحويل المسارات إلى ملفات
              imgIndex,
            ),
            child: FutureBuilder<bool>(
              future:
                  File(imagePaths[imgIndex]).exists(), // التحقق من وجود الملف
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasData && snapshot.data!) {
                    // الملف موجود، عرض الصورة
                    return Image.file(
                      File(imagePaths[imgIndex]),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    );
                  } else {
                    // الملف غير موجود، عرض رمز خطأ
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.red,
                      ),
                    );
                  }
                } else {
                  // أثناء التحقق، عرض مؤشر تقدم
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(
      BuildContext context, List<File> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}
