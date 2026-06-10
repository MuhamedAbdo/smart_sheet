// lib/src/widgets/full_screen_image_page.dart

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:smart_sheet/utils/cache_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class FullScreenImagePage extends StatefulWidget {
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
  // خريطة لحفظ الـ Futures الخاصة بكل صورة لتفادي إعادة الإنشاء عند الـ Rebuild
  final Map<int, Future<File?>> _imageFutures = {};

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

  /// ─── إنشاء ImageProvider للملف المحفوظ محلياً مع ResizeImage ───
  ///
  /// ResizeImage يُجبر Flutter على استخدام JPEG DCT Native Scaling:
  /// بدلاً من فك ترميز صورة 20MP كاملة (20-40 ثانية على أندرويد)،
  /// تُفك بدقة targetWidth فقط (أقل من ثانية).
  ///
  /// targetWidth = عرض الشاشة × DPR × 2.5 (لدعم أقصى zoom في PhotoView)
  /// الحد الأقصى: 3072 بكسل (يكفي أي هاتف بأي zoom معقول)
  /// الحد الأدنى: 1080 بكسل (لضمان الجودة على الشاشات الصغيرة)
  ImageProvider _makeResizedFileImage(BuildContext context, File file) {
    final mq = MediaQuery.of(context);
    final screenPhysicalWidth = (mq.size.width * mq.devicePixelRatio).round();
    // 2.5x لدعم maxScale في PhotoView
    final targetWidth = (screenPhysicalWidth * 2.5).round().clamp(1080, 3072);

    return ResizeImage(
      FileImage(file),
      width: targetWidth,
      allowUpscaling: false,
      policy: ResizeImagePolicy.fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'عرض الصورة (${_currentIndex + 1} من ${widget.imagesPaths.length})',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadCurrentImage(context),
            tooltip: 'تحميل الصورة',
          ),
        ],
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

          if (!isNetwork) {
            // مسار محلي على الجهاز
            if (!File(path).existsSync()) {
              return _buildErrorWidget('الصورة غير متوفرة على الجهاز');
            }
            return _buildPhotoView(_makeResizedFileImage(context, File(path)));
          } else {
            if (kIsWeb) {
              // الويب لا يدعم FileImage
              return _buildPhotoView(NetworkImage(path));
            } else {
              // ─── فحص متزامن فوري (0 ثانية) ───
              // إذا كانت الصورة موجودة في الكاش، نعرضها فوراً بدون أي FutureBuilder
              final File? cachedFile = CacheHelper.getLocalCachedImageSync(path);
              if (cachedFile != null) {
                debugPrint('🎯 [CacheHelper] تم العثور على الصورة محلياً في القرص، جاري الفتح الفوري بدون إنترنت');
                return _buildPhotoView(_makeResizedFileImage(context, cachedFile));
              }

              // ─── تحميل أول مرة عبر FutureBuilder ───
              // نحفظ الـ Future في خريطة لمنع إعادة التحميل عند كل Rebuild
              final Future<File?> future = _imageFutures.putIfAbsent(
                index,
                () => CacheHelper.getLocalCachedImage(path),
              );

              return FutureBuilder<File?>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.image, color: Colors.white10, size: 100),
                          CircularProgressIndicator(color: Colors.white),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasData && snapshot.data != null) {
                    debugPrint('🎯 [CacheHelper] تم العثور على الصورة محلياً في القرص، جاري الفتح الفوري بدون إنترنت');
                    return _buildPhotoView(
                      _makeResizedFileImage(context, snapshot.data!),
                    );
                  } else {
                    return _buildErrorWidget('فشل تحميل الصورة');
                  }
                },
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildPhotoView(ImageProvider imageProvider) {
    return PhotoView(
      imageProvider: imageProvider,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 2.5,
      loadingBuilder: (context, event) => Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.image, size: 80, color: Colors.white10),
          CircularProgressIndicator(
            color: Colors.white,
            value: event == null
                ? null
                : event.expectedTotalBytes != null
                    ? event.cumulativeBytesLoaded / event.expectedTotalBytes!
                    : null,
          ),
        ],
      ),
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorWidget('فشل تحميل الصورة');
      },
    );
  }

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

  // ─── تحميل وحفظ الصورة محلياً بجودة كاملة ────────────────────────
  Future<void> _downloadCurrentImage(BuildContext context) async {
    final currentImagePath = widget.imagesPaths[_currentIndex];

    // إظهار مؤشر تحميل بسيط
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري بدء تحميل الصورة وحفظها...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      if (currentImagePath.startsWith('http')) {
        // فحص ما إذا كان الملف منزلاً في الكاش مسبقاً
        final cachedFile = CacheHelper.getLocalCachedImageSync(currentImagePath);
        if (cachedFile != null && cachedFile.existsSync()) {
          await _copyLocalFile(context, cachedFile.path);
        } else {
          await _downloadFromUrl(context, currentImagePath);
        }
      } else {
        await _copyLocalFile(context, currentImagePath);
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تحميل الصورة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadFromUrl(BuildContext context, String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
      final bytes = response.bodyBytes;

      String extension = '.jpg';
      final cleanUrl = url.split('?').first;
      if (cleanUrl.contains('.png')) {
        extension = '.png';
      } else if (cleanUrl.contains('.jpeg')) {
        extension = '.jpeg';
      } else if (cleanUrl.contains('.webp')) {
        extension = '.webp';
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'sample_$timestamp$extension';

      if (kIsWeb) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('التحميل غير مدعوم على الويب'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final file = File('${externalDir.path}/$filename');
            await file.writeAsBytes(bytes);
          } else {
            throw Exception('External storage directory not available');
          }
        } else {
          final file = File('${downloadsDir.path}/$filename');
          await file.writeAsBytes(bytes);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ الصورة في المعرض/التحميلات'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ الصورة',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حفظ الصورة بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        final file = File('${appDir.path}/$filename');
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ الصورة في: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _downloadFromUrl: $e');
      rethrow;
    }
  }

  Future<void> _copyLocalFile(BuildContext context, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist');
      }

      final bytes = await sourceFile.readAsBytes();
      final extension = sourcePath.split('.').last.toLowerCase();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'sample_$timestamp.$extension';

      if (kIsWeb) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('التحميل غير مدعوم على الويب'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final file = File('${externalDir.path}/$filename');
            await file.writeAsBytes(bytes);
          } else {
            throw Exception('External storage directory not available');
          }
        } else {
          final file = File('${downloadsDir.path}/$filename');
          await file.writeAsBytes(bytes);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ الصورة في المعرض/التحميلات'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ الصورة',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حفظ الصورة بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        final file = File('${appDir.path}/$filename');
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ الصورة في: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _copyLocalFile: $e');
      rethrow;
    }
  }
}
