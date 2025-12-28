import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_sheet/screens/ink_report_screen.dart';
import 'package:smart_sheet/screens/add_sheet_size_screen.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/saved_size_card.dart';
import 'package:smart_sheet/widgets/saved_size_search_bar.dart';

// تعريف أنواع الترتيب
enum SortType {
  alphabeticalAsc, // أ - ي / A - Z
  alphabeticalDesc, // ي - أ / Z - A
  newestFirst, // الأحدث أولاً
  oldestFirst // الأقدم أولاً
}

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

  // الحالة الافتراضية للترتيب: أبجدي (أ-ي)
  SortType _currentSortType = SortType.alphabeticalAsc;

  @override
  void initState() {
    super.initState();
    _initBox();
  }

  void _initBox() {
    if (Hive.isBoxOpen('savedSheetSizes')) {
      setState(() {
        _savedSheetSizesBox = Hive.box('savedSheetSizes');
        _isLoading = false;
      });
    } else {
      Hive.openBox('savedSheetSizes').then((box) {
        if (mounted) {
          setState(() {
            _savedSheetSizesBox = box;
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: isSearching
            ? SavedSizeSearchBar(
                onChanged: (v) => setState(() => searchQuery = v))
            : const Text("📄 المقاسات المحفوظة"),
        actions: [
          // زر الترتيب
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort_by_alpha),
            tooltip: "ترتيب البطاقات",
            onSelected: (SortType result) {
              setState(() {
                _currentSortType = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortType>>[
              const PopupMenuItem<SortType>(
                value: SortType.alphabeticalAsc,
                child: Text('أبجدي (أ - ي)'),
              ),
              const PopupMenuItem<SortType>(
                value: SortType.alphabeticalDesc,
                child: Text('أبجدي (ي - أ)'),
              ),
              const PopupMenuItem<SortType>(
                value: SortType.newestFirst,
                child: Text('التاريخ (الأحدث أولاً)'),
              ),
              const PopupMenuItem<SortType>(
                value: SortType.oldestFirst,
                child: Text('التاريخ (الأقدم أولاً)'),
              ),
            ],
          ),
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              isSearching = !isSearching;
              if (!isSearching) searchQuery = "";
            }),
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _savedSheetSizesBox!.listenable(),
        builder: (context, Box box, _) {
          final entries = _getSortedAndFilteredEntries(box);
          if (entries.isEmpty) {
            return const Center(
                child: Text("🚫 لا توجد نتائج للبحث أو الصندوق فارغ."));
          }
          return ListView.builder(
            itemCount: entries.length,
            cacheExtent: 1000,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return SavedSizeCard(
                key: ValueKey(
                    entry.key), // أضفنا مفتاح لتحسين الأداء عند إعادة الترتيب
                record: entry.value,
                onEdit: () => _navigateToEdit(entry.key, entry.value),
                onDelete: () => _confirmDelete(entry.key),
                onPrint: (data) => _openInkReportWithSheetData(context, data),
              );
            },
          );
        },
      ),
    );
  }

  List<MapEntry<dynamic, Map<String, dynamic>>> _getSortedAndFilteredEntries(
      Box box) {
    final query = searchQuery.toLowerCase().trim();

    // 1. تحويل الصندوق إلى قائمة من المداخل
    List<MapEntry<dynamic, Map<String, dynamic>>> entries = box
        .toMap()
        .entries
        .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value)))
        .toList();

    // 2. الفلترة حسب البحث
    if (query.isNotEmpty) {
      entries = entries.where((entry) {
        final record = entry.value;
        final name = (record['clientName']?.toString() ?? '').toLowerCase();
        final product = (record['productName']?.toString() ?? '').toLowerCase();
        final code = (record['productCode']?.toString() ?? '').toLowerCase();
        return name.contains(query) ||
            product.contains(query) ||
            code.contains(query);
      }).toList();
    }

    // 3. الترتيب حسب النوع المختار
    switch (_currentSortType) {
      case SortType.alphabeticalAsc:
        entries.sort((a, b) => (a.value['clientName'] ?? '')
            .toString()
            .compareTo((b.value['clientName'] ?? '').toString()));
        break;
      case SortType.alphabeticalDesc:
        entries.sort((a, b) => (b.value['clientName'] ?? '')
            .toString()
            .compareTo((a.value['clientName'] ?? '').toString()));
        break;
      case SortType.newestFirst:
        // في Hive، المفاتيح التلقائية (Auto-increment) تزيد مع كل إضافة، لذا الأكبر هو الأحدث
        entries.sort((a, b) => b.key.compareTo(a.key));
        break;
      case SortType.oldestFirst:
        entries.sort((a, b) => a.key.compareTo(b.key));
        break;
    }

    return entries;
  }

  // --- بقية الدوال كما هي دون تغيير ---

  void _openInkReportWithSheetData(
      BuildContext context, Map<String, dynamic> dataFromCard) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final List<String> finalImages = [];
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${appDir.path}/images');

      if (dataFromCard['imagePaths'] is List) {
        for (var pathObj in dataFromCard['imagePaths']) {
          String path = pathObj.toString();
          if (path.startsWith('http')) {
            finalImages.add(path);
          } else {
            String fileName = path.split(Platform.pathSeparator).last;
            String localPath = '${imageDir.path}/$fileName';
            if (await File(localPath).exists()) {
              finalImages.add(localPath);
            }
          }
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
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => InkReportScreen(initialData: initialData)),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error preparing report: $e");
    }
  }

  void _navigateToEdit(dynamic key, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              AddSheetSizeScreen(existingData: data, existingDataKey: key)),
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
          )
        ],
      ),
    );
  }
}
