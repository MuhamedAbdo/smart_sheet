import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';

class SavedSizeCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  // التغيير هنا: بدلاً من VoidCallback، جعلناها Function تستقبل الـ record
  final Function(Map<String, dynamic>) onPrint;

  const SavedSizeCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
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

            // --- زر الطباعة ---
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                // هنا نقوم بتمرير الـ record للدالة الممررة
                onPressed: () => onPrint(record),
                icon: const Icon(Icons.print, size: 18),
                label: const Text("طباعة التقرير"),
                style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact),
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
                  fontWeight: isBold ? FontWeight.bold : FontWeight.bold)),
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
    // منطق الحسابات كما هو موجود في الكود الخاص بك
    double length = double.tryParse(record['length']?.toString() ?? '0') ?? 0.0;
    double width = double.tryParse(record['width']?.toString() ?? '0') ?? 0.0;
    double height = double.tryParse(record['height']?.toString() ?? '0') ?? 0.0;

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
                  _buildTableCell((width / 2).toStringAsFixed(1)),
                  _buildTableCell(height.toStringAsFixed(1)),
                  _buildTableCell((width / 2).toStringAsFixed(1)),
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
