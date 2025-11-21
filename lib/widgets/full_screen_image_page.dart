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
          return PhotoView(
            imageProvider: FileImage(widget.images[index]),
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2.5,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}
