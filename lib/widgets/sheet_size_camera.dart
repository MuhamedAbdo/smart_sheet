// lib/src/widgets/sheet_size/sheet_size_camera.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class SheetSizeCamera extends StatelessWidget {
  final CameraController? cameraController;
  final bool isCameraReady;
  final bool isProcessing;
  final List<dynamic>
      capturedImages; // تم تغيير النوع لـ dynamic لدعم File و String (URL)
  final VoidCallback onCaptureImage;
  final Function(int) onRemoveImage;

  const SheetSizeCamera({
    super.key,
    required this.cameraController,
    required this.isCameraReady,
    required this.isProcessing,
    required this.capturedImages,
    required this.onCaptureImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- معاينة الكاميرا ---
        if (isCameraReady && cameraController != null)
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: CameraPreview(cameraController!),
          )
        else if (cameraController == null)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),

        const SizedBox(height: 12),

        // --- زر الالتقاط ---
        ElevatedButton.icon(
          onPressed: isProcessing || !isCameraReady ? null : onCaptureImage,
          icon: isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.camera_alt),
          label: const Text("التقط صورة للأوردر"),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 45),
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
