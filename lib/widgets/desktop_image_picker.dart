import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DesktopImagePicker extends StatelessWidget {
  final bool isProcessing;
  final List<dynamic> capturedImages;
  final VoidCallback? onPickDesktop;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickGallery;
  final Function(int) onRemoveImage;

  const DesktopImagePicker({
    super.key,
    required this.isProcessing,
    required this.capturedImages,
    this.onPickDesktop,
    this.onPickCamera,
    this.onPickGallery,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "الصور والمرفقات",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isProcessing ? null : onPickGallery,
                          icon: isProcessing 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                              : const Icon(Icons.photo_library),
                          label: const Text("الاستوديو"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isProcessing ? null : onPickCamera,
                          icon: isProcessing 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                              : const Icon(Icons.camera_alt),
                          label: const Text("الكاميرا"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "الصور والمرفقات",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: isProcessing ? null : onPickDesktop,
                    icon: isProcessing 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.upload_file),
                    label: const Text("رفع صور من الجهاز"),
                  ),
                ],
              ),
            if (capturedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: capturedImages.length,
                  itemBuilder: (context, index) {
                    final image = capturedImages[index];
                    return Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          margin: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImage(image),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 16,
                          child: InkWell(
                            onTap: () => onRemoveImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImage(dynamic image) {
    if (image is File) {
      return Image.file(image, fit: BoxFit.cover);
    } else if (image is String && image.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: image,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Tooltip(
          message: 'تعذّر التحميل:\n$url\n$error',
          child: const Center(child: Icon(Icons.broken_image, color: Colors.red)),
        ),
      );
    } else {
      return const Center(child: Icon(Icons.broken_image));
    }
  }
}
