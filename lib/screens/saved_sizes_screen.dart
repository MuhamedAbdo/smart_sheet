import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/screens/client_items_screen.dart';
import 'package:smart_sheet/screens/add_sheet_size_screen.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/services/sync_service.dart';

// تعريف أنواع الترتيب
enum SortType {
  alphabetical,
  newest,
}

class SavedSizesScreen extends StatefulWidget {
  const SavedSizesScreen({super.key});

  @override
  State<SavedSizesScreen> createState() => _SavedSizesScreenState();
}

class _SavedSizesScreenState extends State<SavedSizesScreen> {
  String searchQuery = "";
  SortType _currentSort = SortType.alphabetical;
  bool isSearching = false;
  late Box _savedSheetSizesBox;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initBox();
  }

  Future<void> _initBox() async {
    _savedSheetSizesBox = await Hive.openBox('savedSheetSizes');
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("سجل العملاء"),
        centerTitle: true,
        actions: [
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort),
            onSelected: (val) => setState(() => _currentSort = val),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: SortType.alphabetical, child: Text("ترتيب أبجدي")),
              const PopupMenuItem(
                  value: SortType.newest, child: Text("الأحدث أولاً")),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: _savedSheetSizesBox.listenable(),
          builder: (context, Box box, _) {
            final clients = _getUniqueClients(box);
            final viewInsets = MediaQuery.of(context).viewInsets;
            final bottomInset = viewInsets.bottom;

            if (clients.isEmpty) {
              return Center(
                child: Text(
                  searchQuery.isEmpty
                      ? "لا يوجد عملاء مسجلون حالياً"
                      : "لا توجد نتائج لبحثك",
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            return Column(
              children: [
                // شريط البحث
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (v) => setState(() => searchQuery = v),
                    decoration: InputDecoration(
                      hintText: "البحث باسم أو كود العميل...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                // قائمة العملاء
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      left: 10,
                      right: 10,
                      bottom: bottomInset + 100,
                    ),
                    itemCount: clients.length,
                    itemBuilder: (context, index) {
                      final String clientName = clients[index];
                      final int itemCount = box.values
                          .where((e) =>
                              e is Map &&
                              (e['clientName']?.toString().trim() ?? '') ==
                                  clientName &&
                              e['isClientRecord'] != true)
                          .length;

                      return _ClientCard(
                        clientName: clientName,
                        itemCount: itemCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) =>
                                ClientItemsScreen(clientName: clientName),
                          ),
                        ),
                        onEdit: () => _navigateToEditClient(clientName),
                        onDelete: () => _confirmDeleteClient(clientName),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _navigateToEditClient(String clientName) {
    // جلب كافة السجلات المرتبطة بهذا العميل
    final allClientRecords = _savedSheetSizesBox.toMap().entries.where((e) {
      if (e.value is! Map) return false;
      return (e.value['clientName']?.toString().trim() ?? '') ==
          clientName.trim();
    }).toList();

    if (allClientRecords.isEmpty) return;

    // نبحث عن سجل العميل الأساسي
    final clientRecordIndex =
        allClientRecords.indexWhere((e) => e.value['isClientRecord'] == true);

    if (clientRecordIndex != -1) {
      final clientRecord = allClientRecords[clientRecordIndex];
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
            clientName: clientName,
            isClientOnlyMode: true,
          ),
        ),
      );
    }
  }

  void _confirmDeleteClient(String clientName) {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "حذف العميل نهائياً",
      content:
          "هل أنت متأكد من حذف العميل \"$clientName\" وجميع الأصناف المرتبطة به؟\nسيتم حذف كافة البيانات المتعلقة بهذا العميل.",
      onConfirm: () => _deleteClientWithUndo(clientName),
    );
  }

  void _deleteClientWithUndo(String clientName) async {
    final box = _savedSheetSizesBox;
    final List<MapEntry<dynamic, dynamic>> backup = [];
    final keysToRemove = [];
    final List<Map<String, dynamic>> syncPayloads = [];

    for (var i = 0; i < box.length; i++) {
      final key = box.keyAt(i);
      final record = box.getAt(i);
      if (record is Map &&
          (record['clientName']?.toString().trim() ?? '') ==
              clientName.trim()) {
        backup.add(MapEntry(key, record));
        keysToRemove.add(key);
        // جمع sync_ids للحذف السحابي
        final syncId = record['sync_id']?.toString();
        if (syncId != null) {
          syncPayloads.add({'sync_id': syncId, 'id': syncId});
        }
      }
    }

    if (keysToRemove.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    await box.deleteAll(keysToRemove);

    // مزامنة الحذف سحابياً
    for (final payload in syncPayloads) {
      SyncService.instance
          .pushToQueue('customers', payload, operation: 'delete');
    }

    if (mounted) {
      messenger.clearSnackBars();
      UIUtils.showUndoSnackBar(
        context: context,
        message: 'تم حذف العميل "$clientName"',
        onUndo: () async {
          messenger.clearSnackBars();
          for (var entry in backup) {
            await box.put(entry.key, entry.value);
          }
          // إعادة السجلات سحابياً
          for (final entry in backup) {
            if (entry.value is Map) {
              SyncService.instance.pushToQueue(
                'customers',
                Map<String, dynamic>.from(entry.value),
              );
            }
          }
        },
      );
    }
  }

  List<String> _getUniqueClients(Box box) {
    final Map<String, DateTime> clientMap = {};
    final Map<String, String> clientCodeMap = {}; // تخزين كود لكل عميل للبحث
    final String query = _normalizeString(searchQuery);

    for (var i = 0; i < box.length; i++) {
      final record = box.getAt(i);
      if (record is Map) {
        final String name = (record['clientName'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final String code = (record['productCode'] ?? '').toString().trim();
        final DateTime date = DateTime.tryParse(record['date'] ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        // تحديث التاريخ وتخزين الكود (نفضل كود سجل العميل الأساسي إن وجد)
        if (!clientMap.containsKey(name) || date.isAfter(clientMap[name]!)) {
          clientMap[name] = date;
        }

        // نأخذ الكود فقط من سجل العميل الأساسي لضمان عدم الخلط بين كود الصنف وكود العميل
        if (record['isClientRecord'] == true) {
          clientCodeMap[name] = code;
        }
      }
    }

    // تصفية بحسب البحث (بالاسم أو بالكود)
    List<String> names = clientMap.keys.where((name) {
      if (query.isEmpty) return true;
      final String normalizedName = _normalizeString(name);
      final String normalizedCode = _normalizeString(clientCodeMap[name] ?? "");
      return normalizedName.contains(query) || normalizedCode.contains(query);
    }).toList();

    // الترتيب
    if (_currentSort == SortType.alphabetical) {
      names.sort((a, b) => a.compareTo(b));
    } else {
      names.sort((a, b) => clientMap[b]!.compareTo(clientMap[a]!));
    }

    return names;
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
}

class _ClientCard extends StatelessWidget {
  final String clientName;
  final int itemCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClientCard({
    required this.clientName,
    required this.itemCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade700,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          clientName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text('$itemCount صنف مسجل'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: onEdit,
              tooltip: "تعديل بيانات العميل",
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: onDelete,
              tooltip: "حذف العميل",
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
