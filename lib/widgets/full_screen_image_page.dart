// lib/src/widgets/full_screen_image_page.dart

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';

class FullScreenImagePage extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const FullScreenImagePage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImagePage> createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'عرض الصورة (${_currentIndex + 1} من ${widget.images.length})'),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final file = widget.images[index];

          // ✅ التحقق من وجود الملف
          if (!file.existsSync()) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'الصورة غير متوفرة',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('العودة'),
                  ),
                ],
              ),
            );
          }

          return PhotoView(
            imageProvider: FileImage(file),
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2.5,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 80, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'فشل تحميل الصورة',
                      style: TextStyle(fontSize: 18),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('العودة'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
