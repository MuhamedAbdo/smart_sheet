// lib/src/widgets/full_screen_image_page.dart

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';

class FullScreenImagePage extends StatefulWidget {
  // تم التغيير إلى String لدعم الروابط والمسارات معاً
  final List<String> imagesPaths;
  final int initialIndex;

  const FullScreenImagePage({
    super.key,
    required this.imagesPaths,
    required this.initialIndex,
  });

  @override
  State<FullScreenImagePage> createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  late PageController _pageController;
  late int _currentIndex;

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
      backgroundColor: Colors.black, // خلفية سوداء لعرض الصور بشكل أفضل
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'عرض الصورة (${_currentIndex + 1} من ${widget.imagesPaths.length})',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagesPaths.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final String path = widget.imagesPaths[index];
          final bool isNetwork = path.startsWith('http');

          // تحضير الـ Provider المناسب بناءً على نوع المسار
          ImageProvider imageProvider;
          if (isNetwork) {
            imageProvider = NetworkImage(path);
          } else {
            imageProvider = FileImage(File(path));
          }

          // التحقق من وجود الملف في حالة كان محلياً فقط
          if (!isNetwork && !File(path).existsSync()) {
            return _buildErrorWidget('الصورة غير متوفرة على الجهاز');
          }

          return PhotoView(
            imageProvider: imageProvider,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.5,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget('فشل تحميل الصورة');
            },
          );
        },
      ),
    );
  }

  // واجهة موحدة للأخطاء
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('العودة', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
