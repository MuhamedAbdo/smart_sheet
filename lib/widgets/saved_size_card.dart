import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class SavedSizeCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(Map<String, dynamic>) onPrint; // تم تعديل النوع هنا

  const SavedSizeCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final processType = record['processType'] ?? 'تفصيل';
    final clientName = record['clientName']?.toString() ?? '';
    final productName = record['productName']?.toString() ?? '';
    final productCode = record['productCode']?.toString() ?? '';

    final images = (record['imagePaths'] is List)
        ? (record['imagePaths'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName.isNotEmpty ? clientName : "عميل غير مسمى",
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      if (productName.isNotEmpty)
                        Text(
                          "الصنف: $productName",
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (productCode.isNotEmpty)
                        Text(
                          "كود الصنف: $productCode",
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.visibility,
                      color: Colors.teal, size: 22),
                  onPressed: () => processType == 'تكسير'
                      ? _showCutterDetails(context)
                      : _showFullDetails(context),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 22),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete,
                      color: Colors.redAccent, size: 22),
                  onPressed: onDelete,
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.straighten, size: 16, color: colorScheme.outline),
                const SizedBox(width: 8),
                Text(
                  "المقاس: ${record['length'] ?? '0'} / ${record['width'] ?? '0'} / ${record['height'] ?? '0'} سم",
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildThumbnails(context, images),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => onPrint(record), // تمرير البيانات عند الضغط
                icon: const Icon(Icons.print, size: 16),
                label: const Text("طباعة وتعبئة تقرير",
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // الدوال المساعدة (تظل كما هي)
  void _showCutterDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تفاصيل التكسير", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rowInfo(
                context, "📏 طول الشيت", "${record['sheetLengthManual']} سم"),
            _rowInfo(
                context, "📐 عرض الشيت", "${record['sheetWidthManual']} سم"),
            _rowInfo(context, "🔧 النوع", record['cuttingType']),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("تم"))
        ],
      ),
    );
  }

  void _showFullDetails(BuildContext context) {
    final double length =
        double.tryParse(record['length']?.toString() ?? '0') ?? 0;
    final double width =
        double.tryParse(record['width']?.toString() ?? '0') ?? 0;
    final double height =
        double.tryParse(record['height']?.toString() ?? '0') ?? 0;
    final bool isOverFlap = record['isOverFlap'] ?? false;
    final bool isTwoFlap = record['isTwoFlap'] ?? true;
    final bool addTwoMm = record['addTwoMm'] ?? false;
    final bool isFullSize = record['isFullSize'] ?? true;
    final bool isQuarterSize = record['isQuarterSize'] ?? false;
    final bool isQuarterWidth = record['isQuarterWidth'] ?? true;

    double sheetLength = isFullSize
        ? ((length + width) * 2) + 4
        : (isQuarterSize
            ? (isQuarterWidth ? width : length) + 4
            : length + width + 4);

    double sheetWidth = isOverFlap
        ? height + (isTwoFlap ? width * 2 : width)
        : height + (isTwoFlap ? width : width / 2);
    if (addTwoMm) sheetWidth += 0.4;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("مقاسات خط الإنتاج",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sheetInfo("طول الشيت", sheetLength),
                _sheetInfo("عرض الشيت", sheetWidth),
              ],
            ),
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

  Widget _rowInfo(BuildContext context, String label, dynamic value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label),
          Text("${value ?? '—'}",
              style: const TextStyle(fontWeight: FontWeight.bold))
        ]),
      );

  static Widget _sheetInfo(String label, double value) => Column(children: [
        Text(value.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))
      ]);

  Widget _buildThumbnails(BuildContext context, List<String> images) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, i) {
          final path = images[i];
          final bool isNetwork = path.startsWith('http');
          return GestureDetector(
            onTap: () => _showFullScreenImage(context, images, i),
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              width: 50,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300)),
              clipBehavior: Clip.antiAlias,
              child: isNetwork
                  ? Image.network(path, fit: BoxFit.cover)
                  : Image.file(File(path), fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  void _showFullScreenImage(
      BuildContext context, List<String> images, int index) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                _FullScreenImageGallery(images: images, initialIndex: index)));
  }
}

// (كلاسات الصور تظل كما هي...)
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
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text("${_currentIndex + 1} / ${widget.images.length}",
              style: const TextStyle(color: Colors.white))),
      body: PhotoViewGallery.builder(
        itemCount: widget.images.length,
        builder: (context, index) {
          final path = widget.images[index];
          return PhotoViewGalleryPageOptions(
              imageProvider: path.startsWith('http')
                  ? NetworkImage(path)
                  : FileImage(File(path)) as ImageProvider,
              initialScale: PhotoViewComputedScale.contained);
        },
        pageController: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
