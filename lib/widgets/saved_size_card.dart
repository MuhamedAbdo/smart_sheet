// lib/src/widgets/saved_size_card.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class SavedSizeCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPrint;

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

    final processType = record['processType'] ?? 'تفصيل';
    final clientName = record['clientName']?.toString() ?? '';
    final productName = record['productName']?.toString() ?? '';
    final productCode = record['productCode']?.toString() ?? '';

    // --- تحميل وتصفية الصور (سحابية أو موجودة محلياً) ---
    final allImages = (record['imagePaths'] is List)
        ? (record['imagePaths'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final validImages = allImages.where((path) {
      if (path.startsWith('http')) return true;
      return File(path).existsSync();
    }).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
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
                              style: const TextStyle(fontSize: 14)),
                        if (productCode.isNotEmpty)
                          Text("الكود: $productCode",
                              style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 6),
                      ],
                      Chip(
                        label: Text(
                          processType,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: (processType == 'تكسير')
                            ? Colors.orange
                            : Colors.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    if (processType == 'تكسير') {
                      _showCutterDetails(context);
                    } else {
                      _showFullDetails(context, record);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: colorScheme.primary,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "📏 الطول: "),
                  TextSpan(
                      text: "${record['length'] ?? '—'} سم",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: "\n📐 العرض: "),
                  TextSpan(
                      text: "${record['width'] ?? '—'} سم",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: "\n📏 الارتفاع: "),
                  TextSpan(
                      text: "${record['height'] ?? '—'} سم",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),

            // --- عرض تفاصيل الشيت ---
            if (processType == 'تكسير') ...[
              _buildCutterRow(),
              const SizedBox(height: 10),
            ] else if (processType == 'تفصيل') ...[
              if ((record['sheetLengthResult']?.isNotEmpty ?? false) ||
                  (record['sheetWidthResult']?.isNotEmpty ?? false))
                Text(
                  "${record['sheetLengthResult']}\n${record['sheetWidthResult']}",
                  style: const TextStyle(fontSize: 14),
                ),
              const SizedBox(height: 10),
            ],

            // --- عرض الصور (دعم السحاب والمحلي) ---
            if (validImages.isNotEmpty) ...[
              const Text("📸 الصور:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: validImages.length,
                  itemBuilder: (context, i) {
                    final path = validImages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: GestureDetector(
                        onTap: () =>
                            _showFullScreenImage(context, validImages, i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: path.startsWith('http')
                              ? Image.network(
                                  path,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, e, s) =>
                                      const Icon(Icons.broken_image),
                                )
                              : Image.file(
                                  File(path),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print),
                  label: const Text("طباعة"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لعرض بيانات التكسير في الكارت
  Widget _buildCutterRow() {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: "📏 طول الشيت: "),
          TextSpan(
              text: "${record['sheetLengthManual'] ?? '—'} سم",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: "\n📐 عرض الشيت: "),
          TextSpan(
              text: "${record['sheetWidthManual'] ?? '—'} سم",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: "\n🔧 النوع: "),
          TextSpan(
              text: record['cuttingType'] ?? '—',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  void _showCutterDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تفاصيل التكسير"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record['clientName'] != null)
              Text("👤 العميل: ${record['clientName']}"),
            Text("📏 طول الشيت: ${record['sheetLengthManual']} سم"),
            Text("📐 عرض الشيت: ${record['sheetWidthManual']} سم"),
            Text("🔧 النوع: ${record['cuttingType']}"),
          ],
        ),
        actions: [
          TextButton(
              onPressed: Navigator.of(context).pop, child: const Text("حسنًا")),
        ],
      ),
    );
  }

  void _showFullDetails(BuildContext context, Map<String, dynamic> record) {
    // ... نفس منطق الحسابات الرياضية الخاص بك ...
    // (تم اختصاره هنا للحفاظ على مساحة الرد، يرجى الاحتفاظ بالمعادلات كما هي في ملفك الأصلي)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تفاصيل المقاس"),
        content: const Text(
            "تفاصيل الإنتاج المحسوبة..."), // استبدلها بالجدول الخاص بك
        actions: [
          TextButton(
              onPressed: Navigator.of(context).pop, child: const Text("حسنًا")),
        ],
      ),
    );
  }

  void _showFullScreenImage(
      BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _FullScreenImageGallery(images: images, initialIndex: initialIndex),
      ),
    );
  }
}

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
        title: Text("صورة ${_currentIndex + 1} من ${widget.images.length}",
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final path = widget.images[index];
          // ✅ دعم PhotoView للصور السحابية والمحلية
          final ImageProvider provider = path.startsWith('http')
              ? NetworkImage(path)
              : FileImage(File(path)) as ImageProvider;

          return PhotoView(
            imageProvider: provider,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            loadingBuilder: (context, event) =>
                const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
