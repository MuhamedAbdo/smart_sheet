// lib/src/widgets/camera/image_capture_section.dart

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ImageCaptureSection extends StatelessWidget {
  final CameraController? cameraController;
  final bool isCameraReady;
  final bool isProcessing;
  final List<File> capturedImages;
  final VoidCallback onCaptureImage;
  final Function(int) onRemoveImage;
  final Function(String) onShowFullScreenImage;

  const ImageCaptureSection({
    super.key,
    required this.cameraController,
    required this.isCameraReady,
    required this.isProcessing,
    required this.capturedImages,
    required this.onCaptureImage,
    required this.onRemoveImage,
    required this.onShowFullScreenImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isCameraReady && cameraController != null)
          SizedBox(
            height: 200,
            child: CameraPreview(cameraController!),
          ),
        const SizedBox(height: 12),
        if (cameraController != null)
          ElevatedButton.icon(
            onPressed: isProcessing ? null : onCaptureImage,
            icon: const Icon(Icons.camera),
            label: const Text("التقط صورة"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        if (capturedImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: capturedImages.length,
              itemBuilder: (context, imgIndex) {
                final imagePath = capturedImages[imgIndex];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      GestureDetector(
                        onTap: () => onShowFullScreenImage(imagePath.path),
                        child: Image.file(
                          imagePath,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.red),
                        onPressed: () => onRemoveImage(imgIndex),
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
