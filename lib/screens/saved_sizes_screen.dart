// (Imports كما هي...)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
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
  Box? _savedSheetSizesBox;
  bool _isLoading = true;
  String searchQuery = "";
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _openBoxSafe();
  }

  Future<void> _openBoxSafe() async {
    if (!Hive.isBoxOpen('savedSheetSizes'))
      await Hive.openBox('savedSheetSizes');
    setState(() {
      _savedSheetSizesBox = Hive.box('savedSheetSizes');
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: isSearching
            ? SavedSizeSearchBar(
                onChanged: (v) => setState(() => searchQuery = v))
            : const Text("📄 المقاسات المحفوظة"),
        actions: [
          IconButton(
              icon: Icon(isSearching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                    isSearching = !isSearching;
                    if (!isSearching) searchQuery = "";
                  }))
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _savedSheetSizesBox!.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty)
            return const Center(child: Text("🚫 لا توجد مقاسات محفوظة."));
          final entries = _getFilteredEntries(box);
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return SavedSizeCard(
                record: entry.value,
                onEdit: () => _navigateToEdit(entry.key, entry.value),
                onDelete: () => _confirmDelete(entry.key),
                onPrint: (data) =>
                    _openInkReportWithSheetData(context, data), // هنا تم الحل
              );
            },
          );
        },
      ),
    );
  }

  // (باقي الدوال _getFilteredEntries, _navigateToEdit, _confirmDelete تظل كما هي في كودك)

  void _openInkReportWithSheetData(
      BuildContext context, Map<String, dynamic> dataFromCard) async {
    final List<String> finalImages = [];
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/images');

    if (dataFromCard['imagePaths'] is List) {
      for (var pathObj in dataFromCard['imagePaths']) {
        String path = pathObj.toString();
        if (path.startsWith('http')) {
          finalImages.add(path);
          continue;
        }
        String fileName = path.contains('/') ? path.split('/').last : path;
        String localPath = '${imageDir.path}/$fileName';
        if (File(localPath).existsSync()) finalImages.add(localPath);
      }
    }

    final initialData = {
      'date': DateTime.now().toString().split(' ')[0],
      'clientName': dataFromCard['clientName'] ?? '',
      'product': dataFromCard['productName'] ?? '',
      'productCode': dataFromCard['productCode'] ?? '',
      'dimensions': {
        'length': dataFromCard['length']?.toString() ?? '',
        'width': dataFromCard['width']?.toString() ?? '',
        'height': dataFromCard['height']?.toString() ?? '',
      },
      'imagePaths': finalImages,
      'notes': 'مستورد من قسم المقاسات',
    };

    if (mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => InkReportScreen(initialData: initialData)));
    }
  }

  List<MapEntry<dynamic, Map<String, dynamic>>> _getFilteredEntries(Box box) {
    return box
        .toMap()
        .entries
        .where((entry) {
          final record = entry.value as Map;
          final q = searchQuery.toLowerCase().trim();
          if (q.isEmpty) return true;
          return (record['clientName']?.toString() ?? '')
                  .toLowerCase()
                  .contains(q) ||
              (record['productName']?.toString() ?? '')
                  .toLowerCase()
                  .contains(q) ||
              (record['productCode']?.toString() ?? '').toLowerCase() == q;
        })
        .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value)))
        .toList();
  }

  void _navigateToEdit(dynamic key, Map<String, dynamic> data) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                AddSheetSizeScreen(existingData: data, existingDataKey: key)));
  }

  void _confirmDelete(dynamic key) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text("تأكيد"),
                content: const Text("حذف؟"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("لا")),
                  TextButton(
                      onPressed: () {
                        _savedSheetSizesBox!.delete(key);
                        Navigator.pop(ctx);
                      },
                      child: const Text("نعم"))
                ]));
  }
}
