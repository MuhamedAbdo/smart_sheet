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
  // 1. جعل الصندوق nullable والتحكم في حالة التحميل لمنع الخطأ
  Box? _savedSheetSizesBox;
  bool _isLoading = true;
  String searchQuery = "";
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _openBoxSafe();
  }

  // 2. ضمان فتح الصندوق قبل محاولة الوصول إليه
  Future<void> _openBoxSafe() async {
    try {
      if (!Hive.isBoxOpen('savedSheetSizes')) {
        await Hive.openBox('savedSheetSizes');
      }
      if (mounted) {
        setState(() {
          _savedSheetSizesBox = Hive.box('savedSheetSizes');
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error opening box: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3. منع الشاشة من العمل قبل تحميل الصندوق
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_savedSheetSizesBox == null) {
      return const Scaffold(
        body: Center(child: Text("❌ خطأ في تحميل البيانات")),
      );
    }

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
        valueListenable: _savedSheetSizesBox!.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("🚫 لا توجد مقاسات محفوظة."));
          }

          // تحويل البيانات ومعالجتها بشكل آمن (Handling Nulls and Types)
          final entries = box.toMap().entries.where((entry) {
            final record = entry.value is Map ? entry.value as Map : {};

            final productCode =
                (record['productCode']?.toString() ?? '').toLowerCase();
            final clientName =
                (record['clientName']?.toString() ?? '').toLowerCase();
            final productName =
                (record['productName']?.toString() ?? '').toLowerCase();
            final processType = record['processType']?.toString() ?? 'تفصيل';
            final query = searchQuery.toLowerCase();

            if (searchQuery.isEmpty) return true;

            return clientName.contains(query) ||
                productName.contains(query) ||
                processType.contains(query) ||
                productCode.contains(query);
          }).map((entry) {
            final originalMap = entry.value is Map ? entry.value as Map : {};
            final safeMap = <String, dynamic>{};
            originalMap.forEach((key, value) {
              safeMap[key.toString()] = value;
            });
            return MapEntry(entry.key, safeMap);
          }).toList()
            ..sort((a, b) {
              final dateA =
                  DateTime.tryParse(a.value['date']?.toString() ?? '') ??
                      DateTime(1970);
              final dateB =
                  DateTime.tryParse(b.value['date']?.toString() ?? '') ??
                      DateTime(1970);
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
                onDelete: () => _confirmDelete(key),
                onPrint: () => _openInkReportWithSheetData(context, record),
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

  void _confirmDelete(dynamic key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف هذا المقاس؟"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              _savedSheetSizesBox!.delete(key);
              Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openInkReportWithSheetData(
      BuildContext context, Map<String, dynamic> record) {
    // تصفية الصور الموجودة فقط لمنع كراش الشاشة التالية
    final rawImages = record['imagePaths'];
    final List<String> imagePaths = [];
    if (rawImages is List) {
      for (var path in rawImages) {
        if (File(path.toString()).existsSync()) {
          imagePaths.add(path.toString());
        }
      }
    }

    final initialData = {
      'date': DateTime.now().toIso8601String(),
      'clientName': record['clientName'] ?? '',
      'product': record['productName'] ?? '',
      'productCode': record['productCode'] ?? '',
      'dimensions': {
        'length': record['length']?.toString() ?? '',
        'width': record['width']?.toString() ?? '',
        'height': record['height']?.toString() ?? '',
      },
      'imagePaths': imagePaths,
      'colors': [],
      'quantity': '',
      'notes': '',
      'processType': record['processType'] ?? 'تفصيل',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InkReportScreen(initialData: initialData),
      ),
    );
  }
}
