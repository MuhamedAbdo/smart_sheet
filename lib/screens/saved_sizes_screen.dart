// lib/src/screens/saved/saved_sizes_screen.dart

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
            final query = searchQuery.toLowerCase();

            if (searchQuery.isEmpty) return true;
            if (int.tryParse(searchQuery) != null) {
              return productCode.contains(query);
            }
            return clientName.contains(query) ||
                productName.contains(query) ||
                productCode.contains(query);
          }).map((entry) {
            // تحويل المفتاح إلى String يدويًا لضمان السلامة
            final originalMap = entry.value as Map<dynamic, dynamic>;
            final safeMap = <String, dynamic>{};
            originalMap.forEach((key, value) {
              safeMap[key.toString()] = value;
            });
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
              final record = entry.value; // الآن من نوع Map<String, dynamic>
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
                  savedSheetSizesBox.delete(key);
                },
                // ✅ تم إزالة onViewDetails لأن الكارت لا يدعمه
                onPrint: () {
                  _openInkReportWithSheetData(context, record);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openInkReportWithSheetData(
      BuildContext context, Map<String, dynamic> record) {
    final initialData = {
      'date': DateTime.now().toIso8601String(),
      'clientName': record['clientName'] ?? '',
      'product': record['productName'] ?? '',
      'productCode': record['productCode']?.toString() ?? '',
      'dimensions': {
        'length': record['length']?.toString() ?? '',
        'width': record['width']?.toString() ?? '',
        'height': record['height']?.toString() ?? '',
      },
      'imagePaths': (record['imagePaths'] is List)
          ? List<String>.from(record['imagePaths'])
          : [],
      'colors': [],
      'quantity': '',
      'notes': '',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InkReportScreen(initialData: initialData),
      ),
    );
  }
}
