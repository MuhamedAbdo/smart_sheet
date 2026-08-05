import 'package:smart_sheet/models/flexo_production_report.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_sheet/screens/job_order_dialog.dart';
import 'package:smart_sheet/screens/production_report_screen.dart';
import 'package:smart_sheet/screens/add_sheet_size_screen.dart';
import 'package:smart_sheet/widgets/start_session_dialog.dart';
import 'package:smart_sheet/screens/production_line/start_production_session_screen.dart';
import 'package:smart_sheet/screens/production_line_screen.dart';
import 'package:smart_sheet/widgets/saved_size_card.dart';
import 'package:smart_sheet/widgets/saved_size_search_bar.dart';
import 'package:smart_sheet/widgets/production_report_form.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:smart_sheet/utils/auth_helper.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/utils/cache_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';

DateTime? _parseTimeForDieCutting(String? dateStr, String? timeStr) {
  if (dateStr == null || timeStr == null || timeStr.isEmpty || timeStr == '--:--') return null;
  try {
    final d = DateTime.parse(dateStr);
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    return DateTime(d.year, d.month, d.day, int.parse(parts[0]), int.parse(parts[1]));
  } catch (_) {
    return null;
  }
}

/// شاشة تعرض جميع الأصناف والمقاسات المرتبطة بعميل معين
class ClientItemsScreen extends StatefulWidget {
  final String clientName;

  const ClientItemsScreen({super.key, required this.clientName});

  @override
  State<ClientItemsScreen> createState() => _ClientItemsScreenState();
}

class _ClientItemsScreenState extends State<ClientItemsScreen> {
  Box? _savedSheetSizesBox;
  Box<Worker>? _workersBox;
  bool _isLoading = true;
  String searchQuery = "";
  bool isSearching = false;

  List<MapEntry<dynamic, Map<String, dynamic>>> _allClientRecords = [];
  StreamSubscription? _boxSubscription;
  Timer? _debounceTimer;
  Timer? _searchDebounce;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _initBox();
  }

  void _initBox() {
    if (Hive.isBoxOpen('savedSheetSizes')) {
      _setupBox(Hive.box('savedSheetSizes'));
    } else {
      Hive.openBox('savedSheetSizes').then((box) {
        if (mounted) {
          _setupBox(box);
        }
      });
    }
    // فتح workers box لمراقبة تغيير الصلاحيات
    if (Hive.isBoxOpen('workers')) {
      _workersBox = Hive.box<Worker>('workers');
    } else {
      Hive.openBox<Worker>('workers').then((box) {
        if (mounted) setState(() => _workersBox = box);
      });
    }
  }

  void _setupBox(Box box) {
    _savedSheetSizesBox = box;
    _refreshLocalData();
    
    _boxSubscription = box.watch().listen((event) {
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _refreshLocalData();
        }
      });
    });
    
    setState(() {
      _isLoading = false;
    });
  }

  void _refreshLocalData() {
    if (_savedSheetSizesBox == null) return;
    final box = _savedSheetSizesBox!;
    final records = box.toMap().entries.where((e) {
      if (e.value is! Map) return false;
      return (e.value['clientName']?.toString().trim() ?? '') == widget.clientName.trim();
    }).map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value))).toList();
    
    setState(() {
      _allClientRecords = records;
    });
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _boxSubscription?.cancel();
    _debounceTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final query = _normalizeString(searchQuery);

    // استخدام القائمة المحلية بدلاً من الحساب المباشر من الـ Box في كل build
    final allClientRecords = _allClientRecords;

    // السجلات التي تمثل "أصناف" فقط (ليست سجل العميل الأساسي)
    final rawItemEntries = allClientRecords.where((e) {
      return e.value['isClientRecord'] != true;
    }).toList();

    // التصفية البرمجية للأصناف المكررة (Unique Filtering)
    final Map<String, MapEntry<dynamic, Map<String, dynamic>>> uniqueItemsMap = {};
    for (var entry in rawItemEntries) {
      final productCode = entry.value['productCode']?.toString().trim() ?? '';
      final uniqueId = productCode.isNotEmpty
          ? productCode
          : (entry.value['sync_id'] ?? entry.value['id'] ?? entry.key).toString();
      uniqueItemsMap[uniqueId] = entry;
    }
    final itemEntries = uniqueItemsMap.values.toList();

    final filteredEntries = itemEntries
        .where((e) {
          if (query.isEmpty) return true;
          final String pName =
              _normalizeString((e.value['productName'] ?? '').toString());
          final String pCode =
              _normalizeString((e.value['productCode'] ?? '').toString());
          return pName.contains(query) || pCode == query;
        }).toList();

    // ترتيب تصاعدي بناءً على كود الصنف (رقمياً)
    filteredEntries.sort((a, b) {
      final codeA = int.tryParse(a.value['productCode']?.toString() ?? '') ?? 0;
      final codeB = int.tryParse(b.value['productCode']?.toString() ?? '') ?? 0;
      return codeA.compareTo(codeB);
    });

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
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (v) {
                    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                      if (mounted) setState(() => searchQuery = v);
                    });
                  })
              : Text(widget.clientName),
          centerTitle: !isSearching,
          actions: [
            // ── زر إصدار أمر التشغيل — حصري لسطح المكتب ──────────────────
            if ((!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) ||
                (kIsWeb && MediaQuery.of(context).size.width > 900))
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
                if (!isSearching) {
                  searchQuery = "";
                  _searchController.clear();
                  _searchFocusNode.unfocus();
                } else {
                  _searchFocusNode.requestFocus();
                }
              }),
            )
          ],
        ),
          floatingActionButton: _workersBox == null
              ? null
              : ValueListenableBuilder<Box<Worker>>(
                  valueListenable: _workersBox!.listenable(),
                  builder: (context, _, __) {
                    if (!PermissionHelper.canManageClientsAdd) return const SizedBox.shrink();
                    return FloatingActionButton.extended(
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
                    );
                  },
                ),
      body: _buildBody(allClientRecords, itemEntries.length, filteredEntries, clientCode),
    );
  }

  Widget _buildBody(List<MapEntry<dynamic, dynamic>> allClientRecords,
      int totalItemsCount, List<MapEntry<dynamic, Map<String, dynamic>>> filteredEntries, String clientCode) {
    
    final canEdit = PermissionHelper.canManageClientsEdit;
    final canDelete = PermissionHelper.canManageClientsDelete;
    // صلاحية بدء إنتاج فلكسو — تعتمد على قسم المستخدم + صلاحية canAdd
    final canAddFlexo = AuthHelper.currentUserCanManageProduction('flexo', 'canAdd');
    // صلاحية بدء إنتاج خط الإنتاج — مستقلة عن الفلكسو
    final canAddProductionLine = AuthHelper.currentUserCanManageProduction('production_line', 'canAdd');
    // صلاحية بدء إنتاج التكسير
    final canAddDieCutting = AuthHelper.currentUserCanManageProduction('crushing', 'canAdd');

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
              return RepaintBoundary(
                child: SavedSizeCard(
                  key: ValueKey(entry.key),
                  record: entry.value,
                  canEdit: canEdit,
                  canDelete: canDelete,
                  canAddFlexo: canAddFlexo,
                  canAddProductionLine: canAddProductionLine,
                  canAddDieCutting: canAddDieCutting,
                  onEdit: () => _navigateToEdit(entry.key, entry.value),
                  onDelete: () => _confirmDelete(entry.key),
                  onStartProduction: (data) => _openFlexoProductionReportWithSheetData(context, data),
                  onStartProductionLine: (data) => _openProductionLineSessionWithSheetData(context, data),
                  onStartDieCutting: (data) => _openDieCuttingSessionWithSheetData(context, data),
                ),
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

    // استخراج مسارات الصور إذا كانت موجودة للحذف اليدوي من الكاش
    final imagePaths = backupRecord['imagePaths'];

    // استخراج sync_id قبل الحذف لاستخدامه في المزامنة السحابية
    final syncId = backupRecord['sync_id']?.toString() ?? key.toString();
    final messenger = ScaffoldMessenger.of(context);
    await box.delete(key);

    // تفريغ صور الصنف من الكاش المحلي (للموبايل والديسكتوب)
    if (imagePaths is List) {
      for (var path in imagePaths) {
        if (path is String && path.startsWith('http')) {
          CacheHelper.deleteImageCache(path);
        }
      }
    }

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

  // ─── بناء البيانات الأولية المشتركة من بطاقة الصنف ──────────────────────────
  Future<Map<String, dynamic>?> _prepareInitialDataFromCard(
      BuildContext context, Map<String, dynamic> dataFromCard,
      {bool useProductName = false}) async {
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
            final fileName =
                path.split('/').last.split(Platform.pathSeparator).last;
            final localPath = '${imageDir.path}/$fileName';
            if (await File(localPath).exists()) {
              finalImages.add(localPath);
            } else if (!path.startsWith('http')) {
              finalImages.add(path);
            }
          }
        }
      }

      if (context.mounted) Navigator.pop(context);

      return {
        'date': DateTime.now().toString().split(' ')[0],
        'clientName': dataFromCard['clientName'] ?? '',
        'product': dataFromCard['productName'] ?? dataFromCard['product'] ?? '',
        'productName': dataFromCard['productName'] ?? dataFromCard['product'] ?? '',
        'productCode': dataFromCard['productCode'] ?? '',
        'dimensions': {
          'length': dataFromCard['length']?.toString() ?? '',
          'width': dataFromCard['width']?.toString() ?? '',
          'height': dataFromCard['height']?.toString() ?? '',
        },
        'formNumber': dataFromCard['formNumber']?.toString() ?? '',
        'imagePaths': finalImages,
        'isSheet': dataFromCard['isSheet'] ?? false,
        'notes': 'مستورد من قسم المقاسات',
      };
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Error preparing data: $e");
      return null;
    }
  }

  // ─── BottomSheet اختيار نوع الإنتاج (فلكسو) ──────────────────────────────────
  void _openFlexoProductionReportWithSheetData(
      BuildContext context, Map<String, dynamic> dataFromCard) async {
    final initialData =
        await _prepareInitialDataFromCard(context, dataFromCard);
    if (initialData == null || !context.mounted) return;

    showProductionOptionsSheet(
      context: context,
      initialData: initialData,
      department: 'flexo',
    );
  }

  // ─── BottomSheet اختيار نوع الإنتاج (خط الإنتاج) ────────────────────────────
  void _openProductionLineSessionWithSheetData(
      BuildContext context, Map<String, dynamic> dataFromCard) async {
    final initialData = await _prepareInitialDataFromCard(
        context, dataFromCard,
        useProductName: true);
    if (initialData == null || !context.mounted) return;

    showProductionOptionsSheet(
      context: context,
      initialData: initialData,
      department: 'production_line',
    );
  }

  // ─── BottomSheet اختيار نوع الإنتاج (تكسير) ────────────────────────────
  void _openDieCuttingSessionWithSheetData(
      BuildContext context, Map<String, dynamic> dataFromCard) async {
    final initialData =
        await _prepareInitialDataFromCard(context, dataFromCard);
    if (initialData == null || !context.mounted) return;

    showProductionOptionsSheet(
      context: context,
      initialData: initialData,
      department: 'crushing',
    );
  }

  // ─── دالة الـ BottomSheet المشتركة ───────────────────────────────────────────
  void showProductionOptionsSheet({
    required BuildContext context,
    required Map<String, dynamic> initialData,
    required String department, // 'flexo' | 'production_line' | 'crushing'
  }) {
    final isFlexo = department == 'flexo';
    final isCrushing = department == 'crushing';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final isDark = theme.brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
        final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── مقبض ─────────────────────────────────────────────────
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ─── العنوان ───────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isFlexo
                              ? Colors.blue.shade700
                              : Colors.green.shade700)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCrushing
                          ? Icons.content_cut
                          : (isFlexo ? Icons.precision_manufacturing : Icons.factory),
                      color: isCrushing
                          ? Colors.orange.shade700
                          : (isFlexo
                              ? Colors.blue.shade700
                              : Colors.green.shade700),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCrushing
                              ? 'إنتاج تكسير'
                              : (isFlexo ? 'إنتاج فلكسو' : 'خط الإنتاج'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          initialData['clientName']?.toString() ?? '',
                          style: TextStyle(
                              fontSize: 12, color: subtitleColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ─── الخيار الأول: بدء تشغيل ───────────────────────────
              _buildProductionOptionTile(
                context: sheetCtx,
                icon: Icons.play_circle_filled_rounded,
                iconColor: Colors.green.shade600,
                bgColor: Colors.green.shade600.withValues(alpha: 0.1),
                title: 'بدء تشغيل 🚀',
                subtitle: 'تشغيل المؤقت وبدء العمل الآن.',
                isDark: isDark,
                subtitleColor: subtitleColor,
                onTap: () {
                  Navigator.pop(sheetCtx); // إغلاق الـ BottomSheet
                  _startLiveSession(
                    context,
                    initialData: initialData,
                    department: department,
                  );
                },
              ),

              const SizedBox(height: 12),

              // ─── الخيار الثاني: تسجيل تقرير مباشر ────────────────────
              _buildProductionOptionTile(
                context: sheetCtx,
                icon: Icons.edit_note_rounded,
                iconColor: Colors.orange.shade700,
                bgColor: Colors.orange.shade700.withValues(alpha: 0.1),
                title: 'إدخال تقرير يدوي (منتهي) 📝',
                subtitle:
                    'تسجيل بيانات أوردر تم الانتهاء منه بالفعل.',
                isDark: isDark,
                subtitleColor: subtitleColor,
                onTap: () {
                  Navigator.pop(sheetCtx); // إغلاق الـ BottomSheet
                  _openDirectReportForm(
                    context,
                    initialData: initialData,
                    department: department,
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─── بناء بلاط خيار الإنتاج ──────────────────────────────────────────────
  Widget _buildProductionOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: subtitleColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── تشغيل الجلسة الحية (الوظيفة الأصلية) ───────────────────────────────
  void _startLiveSession(
    BuildContext context, {
    required Map<String, dynamic> initialData,
    required String department,
  }) async {
    if (department == 'production_line') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StartProductionSessionScreen(initialData: initialData),
        ),
      );
      if (result == true && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProductionLineScreen(),
          ),
        );
      }
    } else {
      // فلكسو أو تكسير
      final started = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => StartSessionDialog(
          initialData: initialData,
          department: department,
        ),
      );

      if (started == true && context.mounted) {
        if (department == 'crushing') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FlexoProductionReportScreen(department: 'crushing'),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FlexoProductionReportScreen(),
            ),
          );
        }
      }
    }
  }

  // ─── فتح نموذج التقرير المباشر (منتهي) ──────────────────────────────────
  void _openDirectReportForm(
    BuildContext context, {
    required Map<String, dynamic> initialData,
    required String department,
  }) {
    // تحضير البيانات الأولية بصيغة النموذج
    final formData = {
      ...initialData,
      'department': department,
      'product': initialData['product'] ??
          initialData['productName'] ??
          '',
      'productName': initialData['productName'] ??
          initialData['product'] ??
          '',
    };

    // تحديد البوكس والجدول المناسب بناءً على القسم
    Future<void> saveReport(Map<String, dynamic> r) async {
      final syncId = const Uuid().v4();
      r['sync_id'] = syncId;
      r['id'] = syncId;

      final bool isDieCutting = (department == 'crushing' || department == 'die_cutting');
      final String tableName = isDieCutting ? 'die_cutting_production_reports' : (department == 'production_line' ? 'line_production_reports' : 'flexo_production_reports');
      final String boxName = isDieCutting ? 'die_cutting_production_reports' : 'flexo_production_reports_box';

      if (isDieCutting) {
        if (!Hive.isBoxOpen(boxName)) await Hive.openBox<DieCuttingProductionReport>(boxName);
        final box = Hive.box<DieCuttingProductionReport>(boxName);
        final report = DieCuttingProductionReport(
          id: syncId,
          machineName: r['machineName']?.toString() ?? '',
          technicianName: r['technicianName']?.toString() ?? '',
          reportDate: DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now(),
          customerName: r['clientName']?.toString() ?? '',
          itemName: r['product']?.toString() ?? '',
          itemCode: r['productCode']?.toString() ?? '',
          formNumber: r['formNumber']?.toString() ?? '',
          workOrder: r['orderNumber']?.toString() ?? '',
          runTimeStart: _parseTimeForDieCutting(r['date']?.toString(), r['startTime']?.toString()),
          runTimeEnd: _parseTimeForDieCutting(r['date']?.toString(), r['endTime']?.toString()),
          downtimeStart: _parseTimeForDieCutting(r['date']?.toString(), r['downtimeStart']?.toString()),
          downtimeEnd: _parseTimeForDieCutting(r['date']?.toString(), r['downtimeEnd']?.toString()),
          productionQuantity: double.tryParse(r['quantity']?.toString() ?? '0') ?? 0.0,
          wasteQuantity: double.tryParse(r['lineWaste']?.toString() ?? '0') ?? 0.0,
          notes: r['notes']?.toString(),
          dimensions: r['dimensions'] is Map ? Map<String, dynamic>.from(r['dimensions']) : null,
          crewMembers: r['crewMembers'] != null ? List<String>.from(r['crewMembers']) : (r['crew_members'] != null ? List<String>.from(r['crew_members']) : null),
        );
        await box.put(syncId, report);
        SyncService.instance.pushToQueue(tableName, report.toJson());
      } else {
        if (!Hive.isBoxOpen(boxName)) await Hive.openBox<FlexoProductionReport>(boxName);
        final box = Hive.box<FlexoProductionReport>(boxName);
        final reportObj = FlexoProductionReport.fromJson(r);
        await box.put(syncId, reportObj);
        SyncService.instance.pushToQueue(tableName, reportObj.toJson());
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => FlexoProductionReportForm(
        initialData: formData,
        department: department,
        onSave: (r) async {
          await saveReport(r);
          if (c.mounted) Navigator.pop(c);

          // الانتقال لشاشة التقارير لعرض الإدخال الجديد
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FlexoProductionReportScreen(department: department),
              ),
            );
          }
        },
      ),
    );
  }

  /// يفتح dialog إصدار أمر التشغيل (حصري لسطح المكتب)
  void _openJobOrderDialog(
    BuildContext context,
    List<MapEntry<dynamic, dynamic>> allClientRecords,
    String clientCode,
  ) {
    // تجميع الأصناف فقط (تجاهل السجل الرئيسي للعميل)
    final items = allClientRecords
        .where((e) => e.value is Map && e.value['isClientRecord'] != true)
        .map((e) => Map<String, dynamic>.from(e.value as Map))
        .toList();

    // استخراج بيانات العميل الأساسية من السجل الرئيسي
    String clientAddress = '';
    String clientSupervisor = '';
    String clientPhone = '';

    try {
      final clientRecord = allClientRecords.firstWhere(
        (e) => e.value is Map && e.value['isClientRecord'] == true,
      );
      final data = clientRecord.value as Map;
      clientAddress = data['address']?.toString() ?? '';
      clientSupervisor = data['supervisor']?.toString() ?? '';
      clientPhone = data['phone']?.toString() ?? '';
    } catch (_) {
      // no client record found
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => JobOrderDialog(
        clientName: widget.clientName,
        clientCode: clientCode,
        clientAddress: clientAddress,
        clientSupervisor: clientSupervisor,
        clientPhone: clientPhone,
        clientItems: items,
      ),
    );
  }
}

