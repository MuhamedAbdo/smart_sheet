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

          final List<MapEntry<dynamic, Map>> entries = box
              .toMap()
              .entries
              .where((entry) {
                final record = entry.value;
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
              })
              .map((entry) => MapEntry(
                    entry.key,
                    Map<String, dynamic>.from(entry.value),
                  ))
              .toList()
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
                  savedSheetSizesBox.delete(key);
                },
                onViewDetails: () {
                  _showSizeDetails(context, record);
                },
                onPrint: () {
                  // ✅ فتح نموذج تقرير الأحبار مع تعبئة تلقائية
                  _openInkReportWithSheetData(context, record);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openInkReportWithSheetData(BuildContext context, Map record) {
    // ✅ تحويل بيانات المقاس إلى صيغة "تقرير الأحبار"
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

    // ✅ الانتقال إلى InkReportScreen مع البيانات الأولية
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InkReportScreen(initialData: initialData),
      ),
    );
  }

  void _showSizeDetails(BuildContext context, Map record) {
    double length = double.tryParse(record['length']?.toString() ?? '0') ?? 0.0;
    double width = double.tryParse(record['width']?.toString() ?? '0') ?? 0.0;
    double height = double.tryParse(record['height']?.toString() ?? '0') ?? 0.0;
    bool isFullSize = record['isFullSize'] ?? true;
    bool isQuarterSize = record['isQuarterSize'] ?? false;
    bool isOverFlap = record['isOverFlap'] ?? false;
    bool isTwoFlap = record['isTwoFlap'] ?? true;
    bool addTwoMm = record['addTwoMm'] ?? false;

    double sheetLength = 0.0;
    double sheetWidth = 0.0;
    String productionWidth1 = '';
    String productionWidth2 = '';
    String productionHeight = '';

    if (isFullSize) {
      sheetLength = ((length + width) * 2) + 4;
    } else if (isQuarterSize) {
      sheetLength = width + 4;
    } else {
      sheetLength = length + width + 4;
    }

    if (isOverFlap && isTwoFlap) {
      sheetWidth = addTwoMm ? height + (width * 2) + 0.4 : height + (width * 2);
    } else if (record['isOneFlap'] == true && isOverFlap) {
      sheetWidth = addTwoMm ? height + width + 0.2 : height + width;
    } else if (record['isTwoFlap'] == true) {
      sheetWidth = addTwoMm ? height + width + 0.4 : height + width;
    } else if (record['isOneFlap'] == true) {
      sheetWidth = addTwoMm ? height + (width / 2) + 0.2 : height + (width / 2);
    }

    productionHeight = height.toStringAsFixed(2);

    if (isOverFlap && isTwoFlap) {
      productionWidth1 = addTwoMm
          ? (width + 0.2).toStringAsFixed(2)
          : width.toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isOverFlap && record['isOneFlap'] == true) {
      productionWidth1 = ".....";
      productionWidth2 = addTwoMm
          ? (width + 0.2).toStringAsFixed(2)
          : width.toStringAsFixed(2);
    } else if (record['isTwoFlap'] == true) {
      productionWidth1 = addTwoMm
          ? ((width / 2) + 0.2).toStringAsFixed(2)
          : (width / 2).toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (record['isOneFlap'] == true) {
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📏 طول الشيت: ${sheetLength.toStringAsFixed(2)} سم"),
              Text("📐 عرض الشيت: ${sheetWidth.toStringAsFixed(2)} سم"),
              const SizedBox(height: 16),
              const Text("🔧 مقاسات خط الإنتاج",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Table(
                border: TableBorder.all(),
                children: [
                  TableRow(
                    children: [
                      _buildTableCell(productionWidth1),
                      _buildTableCell(productionHeight),
                      _buildTableCell(productionWidth2),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text("حسنًا"),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String value) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(child: Text(value)),
    );
  }
}
