// lib/src/widgets/finished_product_image_viewer.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:smart_sheet/widgets/full_screen_image_page.dart';

class FinishedProductImageViewer extends StatelessWidget {
  final List<String> imagePaths;

  const FinishedProductImageViewer({
    super.key,
    required this.imagePaths,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imagePaths.length,
        itemBuilder: (context, imgIndex) {
          final path = imagePaths[imgIndex];
          final bool isNetwork = path.startsWith('http');

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () => _showFullScreenImage(
                context,
                imagePaths, // نرسل النصوص مباشرة الآن
                imgIndex,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isNetwork
                    ? Image.network(
                        path,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildLoadingPlaceholder();
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            _buildErrorPlaceholder(),
                      )
                    : Image.file(
                        File(path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildErrorPlaceholder(),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ويدجت التحميل
  Widget _buildLoadingPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  // ويدجت الخطأ
  Widget _buildErrorPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[300],
      child: const Icon(Icons.broken_image, color: Colors.red),
    );
  }

  void _showFullScreenImage(
      BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(
          imagesPaths: images, // تم تغيير المسمى ليتوافق مع التعديل الأخير
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}
