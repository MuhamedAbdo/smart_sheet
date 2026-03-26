import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/screens/client_items_screen.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/saved_size_search_bar.dart';

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
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: isSearching
            ? SavedSizeSearchBar(
                onChanged: (v) => setState(() => searchQuery = v))
            : const Text("سجل العملاء"),
        centerTitle: !isSearching,
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              isSearching = !isSearching;
              if (!isSearching) searchQuery = "";
            }),
          ),
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
      body: ValueListenableBuilder(
        valueListenable: _savedSheetSizesBox.listenable(),
        builder: (context, Box box, _) {
          final clients = _getUniqueClients(box);

          if (clients.isEmpty) {
            return Center(
              child: Text(
                searchQuery.isEmpty ? "لا يوجد عملاء مسجلون حالياً" : "لا توجد نتائج لبحثك",
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final String clientName = clients[index];
              final int itemCount = box.values
                  .where((e) =>
                      e is Map &&
                      (e['clientName']?.toString().trim() ?? '') == clientName &&
                      e['isClientRecord'] != true)
                  .length;

              return _ClientCard(
                clientName: clientName,
                itemCount: itemCount,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => ClientItemsScreen(clientName: clientName),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
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

  const _ClientCard({
    required this.clientName,
    required this.itemCount,
    required this.onTap,
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
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}