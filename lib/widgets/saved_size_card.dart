import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

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
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.teal),
                  onPressed: () => processType == 'تكسير'
                      ? _showCutterDetails(
                          context, clientName, productName, productCode)
                      : _showFullDetails(context, record),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
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

            // --- أزرار الإنتاج (مصممة بمرونة للأقسام القادمة) ---
            Align(
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
                  // هنا يمكن إضافة أزرار أخرى لاحقاً (تكسير، دبوس...) دون تداخل
                ],
              ),
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
              final file = File(path);

              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: GestureDetector(
                  onTap: () =>
                      _showFullScreenImage(context, images, i, baseDirPath),
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 20),
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
      productionWidth1 =
          addTwoMm ? (width + 0.2).toStringAsFixed(2) : width.toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isOverFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 =
          addTwoMm ? (width + 0.2).toStringAsFixed(2) : width.toStringAsFixed(2);
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  Future<void> _downloadImage() async {
    setState(() => _isSaving = true);
    try {
      final String imagePath = widget.images[_currentIndex];
      final File imageFile = File(imagePath);

      if (!await imageFile.exists()) {
        throw Exception("الملف غير موجود");
      }

      if (Platform.isAndroid) {
        // طلب الصلاحيات للأندرويد
        if (await Permission.storage.request().isGranted ||
            await Permission.photos.request().isGranted ||
            await Gal.requestAccess()) {
          await Gal.putImage(imagePath);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حفظ الصورة في معرض الصور بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception("لم يتم منح صلاحية التخزين");
        }
      } else if (Platform.isWindows) {
        String fileName = p.basename(imagePath);
        if (!fileName.toLowerCase().endsWith('.jpg') &&
            !fileName.toLowerCase().endsWith('.png')) {
          fileName += '.jpg';
        }

        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'اختر مكان حفظ الصورة',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['jpg', 'png'],
        );

        if (outputFile != null) {
          // التأكد من وجود الملحق إذا نسيه المستخدم
          if (!outputFile.toLowerCase().endsWith('.jpg') &&
              !outputFile.toLowerCase().endsWith('.png')) {
            outputFile += '.jpg';
          }
          await imageFile.copy(outputFile);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حفظ الصورة بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحفظ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadImage,
              tooltip: 'تحميل الصورة',
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          return PhotoView(
            imageProvider: FileImage(File(widget.images[index])),
            minScale: PhotoViewComputedScale.contained,
            errorBuilder: (c, e, s) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 50)),
          );
        },
      ),
    );
  }
}
