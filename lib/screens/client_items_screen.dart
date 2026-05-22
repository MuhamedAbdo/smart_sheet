import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_sheet/screens/job_order_dialog.dart';
import 'package:smart_sheet/screens/production_report_screen.dart';
import 'package:smart_sheet/screens/add_sheet_size_screen.dart';
import 'package:smart_sheet/widgets/start_session_dialog.dart';
import 'package:smart_sheet/widgets/saved_size_card.dart';
import 'package:smart_sheet/widgets/saved_size_search_bar.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/services/sync_service.dart';

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
            // ── زر إصدار أمر التشغيل — حصري لسطح المكتب ──────────────────
            if (!kIsWeb && Platform.isWindows)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 8),
                child: ElevatedButton.icon(
                  onPressed: () => _openJobOrderDialog(
                    context,
                    allClientRecords,
                    clientCode,
                  ),
                  icon: const Icon(Icons.print_outlined, size: 17),
                  label: const Text(
                    'إصدار أمر تشغيل',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a3a6e),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            // ── زر البحث ──────────────────────────────────────────────────
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
            padding: const EdgeInsets.only(bottom: 80, left: 8, right: 8, top: 4),
            itemBuilder: (context, index) {
              final entry = filteredEntries[index];
              return SavedSizeCard(
                key: ValueKey(entry.key),
                record: entry.value,
                onEdit: () => _navigateToEdit(entry.key, entry.value),
                onDelete: () => _confirmDelete(entry.key),
                onStartProduction: (data) => _openProductionReportWithSheetData(context, data),
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

    // استخراج sync_id قبل الحذف لاستخدامه في المزامنة السحابية
    final syncId = backupRecord['sync_id']?.toString() ?? key.toString();
    final messenger = ScaffoldMessenger.of(context);
    await box.delete(key);

    // ✅ إرسال أمر الحذف إلى Supabase عبر Queue
    SyncService.instance.pushToQueue(
      'customers',
      {'sync_id': syncId, 'id': syncId},
      operation: 'delete',
    );
    debugPrint('🗑️ [ClientItems] تم إرسال طلب حذف الصنف [sync_id=$syncId] إلى Queue');

    if (mounted) {
      messenger.clearSnackBars();
      UIUtils.showUndoSnackBar(
        context: context,
        message: 'تم حذف الصنف بنجاح',
        onUndo: () async {
          messenger.clearSnackBars();
          // إعادة السجل محلياً
          await box.put(key, backupRecord);
          // إعادة السجل سحابياً (upsert)
          SyncService.instance.pushToQueue(
            'customers',
            Map<String, dynamic>.from(backupRecord),
          );
          debugPrint('↩️ [ClientItems] إلغاء الحذف — تم إعادة sync_id=$syncId');
        },
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

  void _openProductionReportWithSheetData(
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
        'isSheet': dataFromCard['isSheet'] ?? false,
        'notes': 'مستورد من قسم المقاسات',
      };

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        // Open StartSessionDialog instead of direct report screen
        final started = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => StartSessionDialog(initialData: initialData),
        );

        if (started == true && context.mounted) {
          // Navigate to ProductionReportScreen where the active card will be visible
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductionReportScreen(),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Error preparing report: $e");
    }
  }

  /// يفتح dialog إصدار أمر التشغيل (حصري لسطح المكتب)
  void _openJobOrderDialog(
    BuildContext context,
    List<MapEntry<dynamic, dynamic>> allClientRecords,
    String clientCode,
  ) {
    // استخراج الأصناف الحقيقية فقط (ليس سجل العميل الأساسي)
    final items = allClientRecords
        .where((e) => e.value is Map && e.value['isClientRecord'] != true)
        .map((e) => Map<String, dynamic>.from(e.value as Map))
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => JobOrderDialog(
        clientName: widget.clientName,
        clientCode: clientCode,
        clientItems: items,
      ),
    );
  }
}
