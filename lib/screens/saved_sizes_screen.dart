// lib/src/screens/saved/saved_sizes_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/screens/ink_report_screen.dart';
import 'package:smart_sheet/screens/add_sheet_size_screen.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/saved_size_card.dart';
import 'package:smart_sheet/widgets/saved_size_search_bar.dart';

class SavedSizesScreen extends StatefulWidget {
  const SavedSizesScreen({super.key});

  @override
  State<SavedSizesScreen> createState() => _SavedSizesScreenState();
}

class _SavedSizesScreenState extends State<SavedSizesScreen> {
  final Box savedSheetSizesBox = Hive.box('savedSheetSizes');
  String searchQuery = "";
  bool isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: isSearching
            ? SavedSizeSearchBar(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
              )
            : const Text("📄 المقاسات المحفوظة"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (isSearching) searchQuery = "";
                isSearching = !isSearching;
              });
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: savedSheetSizesBox.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("🚫 لا توجد مقاسات محفوظة."));
          }

          final entries = box.toMap().entries.where((entry) {
            final record = entry.value as Map<dynamic, dynamic>;

            final productCode =
                (record['productCode']?.toString() ?? '').toLowerCase();
            final clientName =
                (record['clientName']?.toString() ?? '').toLowerCase();
            final productName =
                (record['productName']?.toString() ?? '').toLowerCase();
            final processType = record['processType']?.toString() ?? 'تفصيل';
            final query = searchQuery.toLowerCase();

            if (searchQuery.isEmpty) return true;

            if (int.tryParse(searchQuery) != null) {
              return productCode.contains(query);
            }

            return clientName.contains(query) ||
                productName.contains(query) ||
                processType.contains(query) ||
                productCode.contains(query);
          }).map((entry) {
            final originalMap = entry.value as Map<dynamic, dynamic>;
            final safeMap = <String, dynamic>{};
            originalMap.forEach((key, value) {
              safeMap[key.toString()] = value;
            });

            safeMap['clientName'] = safeMap['clientName'] ?? '';
            safeMap['productName'] = safeMap['productName'] ?? '';
            safeMap['productCode'] = safeMap['productCode']?.toString() ?? '';
            safeMap['processType'] = safeMap['processType'] ?? 'تفصيل';

            return MapEntry(entry.key, safeMap);
          }).toList()
            ..sort((a, b) {
              final dateA =
                  DateTime.tryParse(a.value['date'] ?? '') ?? DateTime(1970);
              final dateB =
                  DateTime.tryParse(b.value['date'] ?? '') ?? DateTime(1970);
              return dateB.compareTo(dateA);
            });

          if (entries.isEmpty) {
            return const Center(child: Text("🚫 لا توجد نتائج للبحث"));
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final record = entry.value;
              final key = entry.key;

              return SavedSizeCard(
                record: record,
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddSheetSizeScreen(
                        existingData: record,
                        existingDataKey: key,
                      ),
                    ),
                  );
                },
                onDelete: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("تأكيد الحذف"),
                      content: const Text("هل أنت متأكد من حذف هذا المقاس؟"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("إلغاء"),
                        ),
                        TextButton(
                          onPressed: () {
                            savedSheetSizesBox.delete(key);
                            Navigator.pop(ctx);
                          },
                          child: const Text("حذف",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                onPrint: () {
                  _openInkReportWithSheetData(context, record);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSheetSizeScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openInkReportWithSheetData(
      BuildContext context, Map<String, dynamic> record) {
    final clientName = record['clientName']?.toString() ?? '';
    final productName = record['productName']?.toString() ?? '';
    final productCode = record['productCode']?.toString() ?? '';
    final processType = record['processType']?.toString() ?? 'تفصيل';

    final displayClientName = clientName.isEmpty && processType == 'تكسير'
        ? 'مقاس تكسير'
        : clientName;
    final displayProductName =
        productName.isEmpty && processType == 'تكسير' ? 'تكسير' : productName;
    final displayProductCode = productCode.isEmpty && processType == 'تكسير'
        ? 'تك-${DateTime.now().millisecondsSinceEpoch % 10000}'
        : productCode;

    // ✅ تصفية الصور الموجودة فقط
    final imagePaths = (record['imagePaths'] is List)
        ? (record['imagePaths'] as List)
            .map((e) => e.toString())
            .where((path) => File(path).existsSync())
            .toList()
        : <String>[];

    final initialData = {
      'date': DateTime.now().toIso8601String(),
      'clientName': displayClientName,
      'product': displayProductName,
      'productCode': displayProductCode,
      'dimensions': {
        'length': record['length']?.toString() ?? '',
        'width': record['width']?.toString() ?? '',
        'height': record['height']?.toString() ?? '',
      },
      'imagePaths': imagePaths, // ← ✅ المسارات المصفاة
      'colors': [],
      'quantity': '',
      'notes': '',
      'processType': processType,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InkReportScreen(initialData: initialData),
      ),
    );
  }
}
