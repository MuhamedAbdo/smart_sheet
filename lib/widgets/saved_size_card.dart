import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:smart_sheet/models/worker_model.dart';

class SavedSizeCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  // التغيير هنا: مسمى الزر أصبح بدء إنتاج بدلاً من طباعة
  final Function(Map<String, dynamic>) onStartProduction;

  const SavedSizeCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.onStartProduction,
  });

  // دالة مساعدة لجلب مسار مجلد الصور
  Future<String> _getImagesDirPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/images';
  }

  @override
  Widget build(BuildContext context) {
    final processType = record['processType'] ?? 'تفصيل';
    final clientName = record['clientName']?.toString() ?? '';
    final productName = record['productName']?.toString() ?? '';
    final productCode = record['productCode']?.toString() ?? '';

    final images = (record['imagePaths'] is List)
        ? (record['imagePaths'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- السطر الأول: العنوان والأزرار ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (clientName.isNotEmpty) ...[
                        Text(
                          clientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (productName.isNotEmpty || productCode.isNotEmpty) ...[
                        if (productName.isNotEmpty)
                          Text("الصنف: $productName",
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                        if (productCode.isNotEmpty)
                          Text("الكود: $productCode",
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 6),
                      ],
                      Chip(
                        label: Text(processType,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                        backgroundColor: (processType == 'تكسير')
                            ? Colors.orange
                            : Colors.blue,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                // ―― زر المعاينة دائماً ظاهر ――
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.teal),
                  onPressed: () => processType == 'تكسير'
                      ? _showCutterDetails(
                          context, clientName, productName, productCode)
                      : _showFullDetails(context, record),
                ),
                // ―― أزرار التعديل والحذف بناءً على الصلاحيات ――
                if (Hive.isBoxOpen('workers'))
                  ValueListenableBuilder<Box<Worker>>(
                    valueListenable: Hive.box<Worker>('workers').listenable(),
                    builder: (context, _, __) {
                      final canEdit = PermissionHelper.canManageClientsEdit;
                      final canDelete = PermissionHelper.canManageClientsDelete;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canEdit)
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: onEdit,
                            ),
                          if (canDelete)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: onDelete,
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),

            const Divider(),

            // --- الأبعاد الأساسية ---
            _buildInfoRow("📏 الطول", "${record['length'] ?? '—'} سم"),
            _buildInfoRow("📐 العرض", "${record['width'] ?? '—'} سم"),
            if (record['isSheet'] != true)
              _buildInfoRow("📏 الارتفاع", "${record['height'] ?? '—'} سم"),

            const SizedBox(height: 10),

            // --- بيانات الشيت حسب النوع ---
            if (processType == 'تكسير') ...[
              _buildInfoRow(
                  "📦 طول الشيت", "${record['sheetLengthManual'] ?? '—'} سم",
                  isBold: true),
              _buildInfoRow(
                  "📐 عرض الشيت", "${record['sheetWidthManual'] ?? '—'} سم",
                  isBold: true),
              _buildInfoRow("🔧 النوع", record['cuttingType'] ?? '—'),
            ] else ...[
              if ((record['sheetLengthResult']?.isNotEmpty ?? false) ||
                  (record['sheetWidthResult']?.isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "${record['sheetLengthResult'] ?? ''}\n${record['sheetWidthResult'] ?? ''}",
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w500),
                  ),
                ),
            ],

            // --- عرض الصور المعالج ---
            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text("📸 الصور:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _buildImagesList(images),
            ],

            const SizedBox(height: 12),

            // ―― أزرار الإنتاج بناءً على صلاحية canAdd ――
            if (Hive.isBoxOpen('workers'))
              ValueListenableBuilder<Box<Worker>>(
                valueListenable: Hive.box<Worker>('workers').listenable(),
                builder: (context, _, __) {
                  if (!PermissionHelper.canAdd) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => onStartProduction(record),
                          icon: const Icon(Icons.precision_manufacturing, size: 18),
                          label: const Text("بدء إنتاج (فلكسو)"),
                          style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontSize: 14)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildImagesList(List<String> images) {
    // إذا كل الصور هي URLs (الحالة بعد المزامنة) — نعرضها مباشرة
    final bool allUrls = images.every((p) => p.startsWith('http'));

    if (allUrls) {
      return SizedBox(
        height: 60,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          itemBuilder: (context, i) {
            return Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, images, i, ''),
                child: Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: images[i],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Tooltip(
                          message: 'تعذّر التحميل:\n$url\n\n$error',
                          child: const Icon(Icons.broken_image,
                              size: 20, color: Colors.red),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              _downloadThumbnailImage(context, images[i]),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.download,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // مسارات محلية (Desktop فقط) — تحتاج لحساب المسار الكامل
    return FutureBuilder<String>(
      future: _getImagesDirPath(),
      builder: (context, snapshot) {
        final baseDirPath = snapshot.data ?? "";
        return SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, i) {
              String path = images[i];
              if (!path.startsWith('http') &&
                  !path.contains(Platform.pathSeparator)) {
                path = "$baseDirPath/$path";
              }

              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: GestureDetector(
                  onTap: () =>
                      _showFullScreenImage(context, images, i, baseDirPath),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: path.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: path,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Tooltip(
                                    message: 'تعذّر التحميل:\n$url\n\n$error',
                                    child: const Icon(Icons.broken_image,
                                        size: 20, color: Colors.red),
                                  ),
                                )
                              : Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, size: 20),
                                ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  _downloadThumbnailImage(context, path),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.download,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showCutterDetails(
      BuildContext context, String client, String product, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تفاصيل التكسير"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (client.isNotEmpty) Text("👤 العميل: $client"),
            if (product.isNotEmpty) Text("🏷️ الصنف: $product"),
            if (code.isNotEmpty) Text("🔢 الكود: $code"),
            const Divider(),
            Text("📏 طول الشيت: ${record['sheetLengthManual'] ?? '—'} سم"),
            Text("📐 عرض الشيت: ${record['sheetWidthManual'] ?? '—'} سم"),
            Text("🔧 النوع: ${record['cuttingType'] ?? '—'}"),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إغلاق"))
        ],
      ),
    );
  }

  void _showFullDetails(BuildContext context, Map<String, dynamic> record) {
    double length = double.tryParse(record['length']?.toString() ?? '0') ?? 0.0;
    double width = double.tryParse(record['width']?.toString() ?? '0') ?? 0.0;
    double height = double.tryParse(record['height']?.toString() ?? '0') ?? 0.0;

    // استخراج الإعدادات المحفوظة للحسابات
    bool isOverFlap = record['isOverFlap'] ?? false;
    bool isFlap = record['isFlap'] ?? true;
    bool isOneFlap = record['isOneFlap'] ?? false;
    bool isTwoFlap = record['isTwoFlap'] ?? true;
    bool addTwoMm = record['addTwoMm'] ?? false;

    String productionWidth1 = "";
    String productionHeight = height.toStringAsFixed(2);
    String productionWidth2 = "";

    // تنفيذ نفس منطق دالة _calculateSheet الموجودة في شاشة الإدخال لضمان التطابق
    if (isOverFlap && isTwoFlap) {
      productionWidth1 = addTwoMm
          ? (width + 0.2).toStringAsFixed(2)
          : width.toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isOverFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 = addTwoMm
          ? (width + 0.2).toStringAsFixed(2)
          : width.toStringAsFixed(2);
    } else if (isFlap && isTwoFlap) {
      productionWidth1 = addTwoMm
          ? ((width / 2) + 0.2).toStringAsFixed(2)
          : (width / 2).toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 = addTwoMm
          ? ((width / 2) + 0.2).toStringAsFixed(2)
          : (width / 2).toStringAsFixed(2);
    } else {
      productionWidth1 = productionWidth2 = ".....";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تفاصيل المقاس"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("📏 الأبعاد: $length × $width × $height سم"),
            const SizedBox(height: 10),
            const Text("🔧 توزيع مقاسات خط الإنتاج",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Table(
              border: TableBorder.all(color: Colors.grey),
              children: [
                TableRow(children: [
                  _buildTableCell(productionWidth1),
                  _buildTableCell(productionHeight),
                  _buildTableCell(productionWidth2),
                ])
              ],
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إغلاق"))
        ],
      ),
    );
  }

  Widget _buildTableCell(String value) => Padding(
      padding: const EdgeInsets.all(8), child: Center(child: Text(value)));

  void _showFullScreenImage(
      BuildContext context, List<String> images, int index, String baseDir) {
    final fullPaths = images.map((path) {
      if (path.startsWith('http') || path.contains(Platform.pathSeparator)) {
        return path;
      }
      return "$baseDir/$path";
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _FullScreenImageGallery(images: fullPaths, initialIndex: index),
      ),
    );
  }

  static void _downloadThumbnailImage(BuildContext context, String imagePath) {
    _downloadImage(context, imagePath);
  }

  static Future<void> _downloadImage(
      BuildContext context, String imagePath) async {
    try {
      if (imagePath.startsWith('http')) {
        await _downloadFromUrlStatic(context, imagePath);
      } else {
        await _copyLocalFileStatic(context, imagePath);
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

  static Future<void> _downloadFromUrlStatic(
      BuildContext context, String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
      final bytes = response.bodyBytes;

      String extension = '.jpg';
      if (url.contains('.png')) {
        extension = '.png';
      } else if (url.contains('.jpeg')) {
        extension = '.jpeg';
      } else if (url.contains('.webp')) {
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
      debugPrint('Error in _downloadFromUrlStatic: $e');
      rethrow;
    }
  }

  static Future<void> _copyLocalFileStatic(
      BuildContext context, String sourcePath) async {
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
      debugPrint('Error in _copyLocalFileStatic: $e');
      rethrow;
    }
  }
}

// كلاس داخلي لعرض الصور بكامل الشاشة
class _FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullScreenImageGallery(
      {required this.images, required this.initialIndex});

  @override
  State<_FullScreenImageGallery> createState() =>
      _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<_FullScreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("صورة ${_currentIndex + 1} من ${widget.images.length}"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadCurrentImage(context),
            tooltip: 'تحميل الصورة',
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final path = widget.images[index];
          // تمييز URL من مسار محلي — استخدام المزود المناسب لكل حالة
          if (path.startsWith('http')) {
            return PhotoView(
              imageProvider: CachedNetworkImageProvider(path),
              minScale: PhotoViewComputedScale.contained,
              errorBuilder: (c, e, s) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image,
                        color: Colors.white, size: 50),
                    const SizedBox(height: 8),
                    Text(
                      'تعذّر تحميل الصورة\n$path',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          } else {
            return PhotoView(
              imageProvider: FileImage(File(path)),
              minScale: PhotoViewComputedScale.contained,
              errorBuilder: (c, e, s) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image,
                        color: Colors.white, size: 50),
                    const SizedBox(height: 8),
                    Text(
                      'فشل تحميل الملف:\n$path',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _downloadCurrentImage(BuildContext context) async {
    final currentImagePath = widget.images[_currentIndex];

    try {
      if (currentImagePath.startsWith('http')) {
        // Download from URL
        await _downloadFromUrl(context, currentImagePath);
      } else {
        // Copy local file
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
      // Download image bytes
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
      final bytes = response.bodyBytes;

      // Determine file extension from URL
      String extension = '.jpg';
      if (url.contains('.png')) {
        extension = '.png';
      } else if (url.contains('.jpeg')) {
        extension = '.jpeg';
      } else if (url.contains('.webp')) {
        extension = '.webp';
      }

      // Generate timestamped filename
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'sample_$timestamp$extension';

      if (kIsWeb) {
        // Web: Not supported in this implementation
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
        // Android: Save to Downloads directory
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          // Fallback to external storage directory
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
        // Desktop: Use file picker to let user choose save location
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
        // Fallback for other platforms
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
