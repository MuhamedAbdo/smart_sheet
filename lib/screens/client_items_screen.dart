import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_sheet/screens/ink_report_screen.dart';
import 'package:smart_sheet/screens/add_sheet_size_screen.dart';
import 'package:smart_sheet/widgets/saved_size_card.dart';
import 'package:smart_sheet/widgets/saved_size_search_bar.dart';
import 'package:smart_sheet/utils/ui_utils.dart';

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
  String searchQuery = "";
  bool isSearching = false;

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

    return ValueListenableBuilder(
      valueListenable: _savedSheetSizesBox!.listenable(),
      builder: (context, Box box, _) {
        final query = _normalizeString(searchQuery);

        // جلب كافة السجلات المرتبطة بهذا العميل
        final allClientRecords = box.toMap().entries.where((e) {
          if (e.value is! Map) return false;
          return (e.value['clientName']?.toString().trim() ?? '') ==
              widget.clientName.trim();
        }).toList();

        // السجلات التي تمثل "أصناف" فقط (ليست سجل العميل الأساسي)
        final itemEntries = allClientRecords.where((e) {
          return e.value['isClientRecord'] != true;
        }).toList();

        final filteredEntries = itemEntries
            .where((e) {
              if (query.isEmpty) return true;
              final String pName =
                  _normalizeString((e.value['productName'] ?? '').toString());
              final String pCode =
                  _normalizeString((e.value['productCode'] ?? '').toString());
              return pName.contains(query) || pCode == query;
            })
            .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value)))
            .toList();

        // ترتيب أبجدي بحسب اسم الصنف
        filteredEntries.sort((a, b) => (a.value['productName'] ?? '')
            .toString()
            .compareTo((b.value['productName'] ?? '').toString()));

        // جلب كود العميل حصرياً من سجل العميل الأساسي (isClientRecord)
        String clientCode = "غير مسجل";
        for (var entry in allClientRecords) {
          if (entry.value['isClientRecord'] == true) {
            final code = entry.value['productCode']?.toString().trim() ?? '';
            if (code.isNotEmpty) {
              clientCode = code;
            }
            break;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: isSearching
                ? SavedSizeSearchBar(
                    onChanged: (v) => setState(() => searchQuery = v))
                : Text(widget.clientName),
            centerTitle: !isSearching,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                tooltip: "تعديل بيانات العميل",
                onPressed: () => _navigateToEditClient(allClientRecords),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: "حذف العميل نهائياً",
                onPressed: () => _confirmDeleteClient(),
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddSheetSizeScreen(
                    clientName: widget.clientName,
                  ),
                ),
              );
            },
            backgroundColor: Colors.green.shade700,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'إضافة صنف',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: _buildBody(allClientRecords, itemEntries.length, filteredEntries, clientCode),
        );
      },
    );
  }

  Widget _buildBody(List<MapEntry<dynamic, dynamic>> allClientRecords,
      int totalItemsCount, List<MapEntry<dynamic, Map<String, dynamic>>> filteredEntries, String clientCode) {
    
    // إذا لم يكن هناك أي سجل (حتى السجل الأساسي) - هذا لا يحدث إلا إذا تم الحذف
    if (allClientRecords.isEmpty && searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              "لم يتم إضافة أي صنف لهذا العميل حتى الآن",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // إذا كان هناك سجل أساسي ولكن لا توجد أصناف حقيقية
    if (totalItemsCount == 0 && searchQuery.isEmpty) {
      return Column(
        children: [
          _buildInfoBar(totalItemsCount, clientCode),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    "لم يتم إضافة أي صنف لهذا العميل حتى الآن",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (filteredEntries.isEmpty && searchQuery.isNotEmpty) {
      return Center(
        child: Text(
          'لا توجد نتائج لبحثك عن "$searchQuery"',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        _buildInfoBar(totalItemsCount, clientCode),

        // قائمة الأصناف
        Expanded(
          child: ListView.builder(
            itemCount: filteredEntries.length,
            itemBuilder: (context, index) {
              final entry = filteredEntries[index];
              return SavedSizeCard(
                key: ValueKey(entry.key),
                record: entry.value,
                onEdit: () => _navigateToEdit(entry.key, entry.value),
                onDelete: () => _confirmDelete(entry.key),
                onPrint: (data) => _openInkReportWithSheetData(context, data),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBar(int totalItemsCount, String clientCode) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.indigo.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$totalItemsCount صنف مسجل',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
              height: 24,
              width: 1,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.qr_code, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'كود العميل: $clientCode',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditClient(List<MapEntry<dynamic, dynamic>> allEntries) {
    if (allEntries.isEmpty) return;

    // نبحث عن سجل العميل الأساسي
    final clientRecordIndex = allEntries.indexWhere((e) => e.value['isClientRecord'] == true);
    
    if (clientRecordIndex != -1) {
      final clientRecord = allEntries[clientRecordIndex];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddSheetSizeScreen(
            existingData: Map<String, dynamic>.from(clientRecord.value),
            existingDataKey: clientRecord.key,
            isClientOnlyMode: true,
          ),
        ),
      );
    } else {
      // إذا لم يكن هناك سجل عميل أساسي، نفتح نموذج جديد بالاسم فقط لإنشاء "سجل عميل"
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddSheetSizeScreen(
            clientName: widget.clientName,
            isClientOnlyMode: true,
          ),
        ),
      );
    }
  }

  void _confirmDeleteClient() {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "حذف العميل نهائياً",
      content: "هل أنت متأكد من حذف العميل \"${widget.clientName}\" وجميع الأصناف المرتبطة به؟\nسيتم حذف كافة البيانات المتعلقة بهذا العميل.",
      onConfirm: _deleteClientWithUndo,
    );
  }

  void _deleteClientWithUndo() async {
    final box = _savedSheetSizesBox!;
    final List<MapEntry<dynamic, dynamic>> backup = [];
    final keysToRemove = [];

    for (var i = 0; i < box.length; i++) {
      final key = box.keyAt(i);
      final record = box.getAt(i);
      if (record is Map &&
          (record['clientName']?.toString().trim() ?? '') ==
              widget.clientName.trim()) {
        backup.add(MapEntry(key, record));
        keysToRemove.add(key);
      }
    }

    if (keysToRemove.isEmpty) return;

    // الحذف الفعلي
    await box.deleteAll(keysToRemove);

    if (mounted) {
      UIUtils.showUndoSnackBar(
        message: 'تم حذف العميل "${widget.clientName}"',
        onUndo: () async {
          for (var entry in backup) {
            await box.put(entry.key, entry.value);
          }
        },
        onDismissed: () {
          if (mounted) Navigator.of(context).pop();
        },
      );
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
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "تأكيد الحذف",
      content: "هل أنت متأكد من حذف هذا الصنف؟",
      onConfirm: () => _deleteItemWithUndo(key),
    );
  }

  void _deleteItemWithUndo(dynamic key) async {
    final box = _savedSheetSizesBox!;
    final backupRecord = box.get(key);
    if (backupRecord == null) return;

    await box.delete(key);

    if (mounted) {
      UIUtils.showUndoSnackBar(
        message: 'تم حذف الصنف بنجاح',
        onUndo: () async => await box.put(key, backupRecord),
      );
    }
  }

  String _normalizeString(String input) {
    if (input.isEmpty) return "";
    String normalized = input.trim().toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll('ى', 'ي');
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < arabicNumbers.length; i++) {
      normalized = normalized.replaceAll(arabicNumbers[i], i.toString());
    }
    return normalized;
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
