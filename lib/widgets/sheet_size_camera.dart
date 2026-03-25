// lib/src/widgets/sheet_size/sheet_size_camera.dart

import 'dart:io';
import 'package:flutter/material.dart';

class SheetSizeCamera extends StatelessWidget {
  final bool isCameraReady;
  final bool isProcessing;
  final List<dynamic> capturedImages;
  final VoidCallback onCaptureImage;
  final Function(int) onRemoveImage;

  const SheetSizeCamera({
    super.key,
    // cameraController تم حذفه لأنه لم يعد مستخدما
    required this.isCameraReady,
    required this.isProcessing,
    required this.capturedImages,
    required this.onCaptureImage,
    required this.onRemoveImage,
    dynamic cameraController, // متوافقية رجعية لتجنب كسر الكود لو وجد
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- زر الالتقاط ---
        ElevatedButton.icon(
          onPressed: isProcessing ? null : onCaptureImage,
          icon: isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_a_photo, size: 24),
          label: const Text(
            "التقط صورة للأوردر",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // --- قائمة الصور الملتقطة (الأرشيف الصغير) ---
        if (capturedImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: capturedImages.length,
              itemBuilder: (context, index) {
                final item = capturedImages[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      _buildImagePreview(item),
                      // زر الحذف
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => onRemoveImage(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cancel,
                                color: Colors.red, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // دالة ذكية لعرض الصورة سواء كانت ملف محلي أو رابط إنترنت
  Widget _buildImagePreview(dynamic item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 90,
        height: 90,
        child: _getImageWidget(item),
      ),
    );
  }

  Widget _getImageWidget(dynamic item) {
    if (item is String && item.startsWith('http')) {
      // إذا كانت صورة من السحاب
      return Image.network(
        item,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
      );
    } else {
      // إذا كانت ملف محلي (File أو Path)
      final file = item is File ? item : File(item.toString());
      if (!file.existsSync()) {
        return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported));
      }
      return Image.file(file, fit: BoxFit.cover);
    }
  }
}
