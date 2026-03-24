import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_sheet/screens/ink_report_screen.dart';
import 'package:smart_sheet/screens/add_sheet_size_screen.dart';
import 'package:smart_sheet/widgets/saved_size_card.dart';

/// شاشة تعرض جميع الأصناف والمقاسات المرتبطة بعميل معين
class ClientItemsScreen extends StatefulWidget {
  final String clientName;

  const ClientItemsScreen({super.key, required this.clientName});

  @override
  State<ClientItemsScreen> createState() => _ClientItemsScreenState();
}

class _ClientItemsScreenState extends State<ClientItemsScreen> {
  Box? _savedSheetSizesBox;
  bool _isLoading = true;

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
      appBar: AppBar(
        title: Text(widget.clientName),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: _savedSheetSizesBox!.listenable(),
        builder: (context, Box box, _) {
          // فلترة الأصناف بحسب اسم العميل
          final entries = box
              .toMap()
              .entries
              .where((e) =>
                  e.value is Map &&
                  (e.value['clientName']?.toString().trim() ?? '') ==
                      widget.clientName.trim())
              .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value)))
              .toList();

          // ترتيب أبجدي بحسب اسم الصنف
          entries.sort((a, b) => (a.value['productName'] ?? '')
              .toString()
              .compareTo((b.value['productName'] ?? '').toString()));

          if (entries.isEmpty) {
            return Center(
              child: Text(
                'لا توجد أصناف لـ "${widget.clientName}" بعد.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return Column(
            children: [
              // شريط معلومات عدد الأصناف
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.indigo.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${entries.length} صنف مسجل',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // قائمة الأصناف
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return SavedSizeCard(
                      key: ValueKey(entry.key),
                      record: entry.value,
                      onEdit: () => _navigateToEdit(entry.key, entry.value),
                      onDelete: () => _confirmDelete(entry.key),
                      onPrint: (data) =>
                          _openInkReportWithSheetData(context, data),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
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
        content: const Text("هل أنت متأكد من حذف هذا الصنف؟"),
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

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => InkReportScreen(initialData: initialData)),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Error preparing report: $e");
    }
  }
}
