// lib/src/widgets/sheet_size/sheet_size_camera.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class SheetSizeCamera extends StatelessWidget {
  final CameraController? cameraController;
  final bool isCameraReady;
  final bool isProcessing;
  final List<File> capturedImages;
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
        // ✅ فقط إذا الكاميرا موجودة واتهيأت
        if (isCameraReady && cameraController != null)
          SizedBox(
            height: 200,
            child: CameraPreview(cameraController!),
          )
        else if (cameraController == null)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("جاري تهيئة الكاميرا..."),
          ),

        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: isProcessing || !isCameraReady ? null : onCaptureImage,
          icon: const Icon(Icons.camera),
          label: const Text("التقط صورة"),
        ),
        const SizedBox(height: 10),
        if (capturedImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: capturedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.file(
                        capturedImages[index],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.red),
                        onPressed: () => onRemoveImage(index),
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
}
