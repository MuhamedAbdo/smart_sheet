// lib/src/widgets/saved/saved_size_card.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class SavedSizeCard extends StatelessWidget {
  final Map record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;
  final VoidCallback onPrint;

  const SavedSizeCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDetails,
    required this.onPrint,
  });

  String _extractDateOnly(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return '';
    try {
      final date = DateTime.tryParse(dateTimeString);
      if (date != null) {
        return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      }
      return dateTimeString.split(' ').first;
    } catch (e) {
      return dateTimeString;
    }
  }

  void _showFullScreenImage(BuildContext context, List<String> imagePaths) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            PageView.builder(
              itemCount: imagePaths.length,
              itemBuilder: (context, index) {
                return Center(
                  child: PhotoView(
                    imageProvider: FileImage(File(imagePaths[index])),
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 2.5,
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: Navigator.of(context).pop,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> imagePaths = (record['imagePaths'] is List)
        ? List<String>.from(record['imagePaths'])
        : [];

    final String displayDate = _extractDateOnly(record['date']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📅 التاريخ: $displayDate",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text("👤 اسم العميل: ${record['clientName']}",
                style: Theme.of(context).textTheme.bodyMedium),
            Text("📦 الصنف: ${record['productName']}",
                style: Theme.of(context).textTheme.bodyMedium),
            Text("🔢 كود الصنف: ${record['productCode'] ?? ''}",
                style: Theme.of(context).textTheme.bodyMedium),
            Text(
              "📏 المقاس: طول ${record['length']} × عرض ${record['width']} × ارتفاع ${record['height']}",
            ),
            if (record['isQuarterSize'] == true)
              Text(
                "(${record['isQuarterWidth'] == true ? 'عرض' : 'طول'})",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            if (imagePaths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imagePaths.length,
                    itemBuilder: (context, imgIndex) {
                      final imagePath = imagePaths[imgIndex];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: FutureBuilder<bool>(
                          future: File(imagePath).exists(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox.square(
                                  dimension: 50,
                                  child: Center(
                                      child: CircularProgressIndicator()));
                            }
                            if (snapshot.hasData && snapshot.data == true) {
                              return GestureDetector(
                                onTap: () =>
                                    _showFullScreenImage(context, imagePaths),
                                child: Image.file(
                                  File(imagePath),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              );
                            } else {
                              return const Icon(Icons.broken_image,
                                  size: 30, color: Colors.red);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    icon:
                        const Icon(Icons.remove_red_eye, color: Colors.orange),
                    onPressed: onViewDetails),
                IconButton(
                    icon: const Icon(Icons.print, color: Colors.purple),
                    onPressed: onPrint),
                IconButton(
                    icon: const Icon(Icons.edit, color: Colors.green),
                    onPressed: onEdit),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
