import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/screens/client_items_screen.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/saved_size_search_bar.dart';

// تعريف أنواع الترتيب
enum SortType {
  alphabeticalAsc, // أ - ي / A - Z
  alphabeticalDesc, // ي - أ / Z - A
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
            : const Text("سجل العملاء"),
        actions: [
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort_by_alpha),
            tooltip: "ترتيب العملاء",
            onSelected: (SortType result) {
              setState(() => _currentSortType = result);
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
          final uniqueClients = _getUniqueClients(box);

          if (uniqueClients.isEmpty && searchQuery.isEmpty) {
            return const Center(
                child: Text("🚫 لا يوجد عملاء بعد، ابدأ بإضافة عميل جديد."));
          }

          // الإحصائيات مبنية على القائمة المفلترة (ليس إجمالي الكل)
          final int totalClients = uniqueClients.length;
          // مجموع أصناف العملاء الظاهرين فقط
          final int totalItems = uniqueClients.fold<int>(0, (sum, clientName) {
            return sum +
                box
                    .toMap()
                    .values
                    .whereType<Map>()
                    .where((v) =>
                        (v['clientName']?.toString().trim() ?? '') == clientName)
                    .length;
          });

          return Column(
            children: [
              // كارد الإحصائيات (ديناميكي مع البحث)
              SavedSizesStatsCard(
                totalProducts: totalItems,
                uniqueClients: totalClients,
              ),

              // قائمة العملاء
              Expanded(
                child: uniqueClients.isEmpty
                    ? const Center(child: Text("🚫 لا توجد نتائج للبحث."))
                    : ListView.builder(
                        itemCount: uniqueClients.length,
                        itemBuilder: (context, index) {
                          final clientName = uniqueClients[index];
                          // عدد الأصناف لهذا العميل
                          final itemCount = box
                              .toMap()
                              .values
                              .where((v) =>
                                  v is Map &&
                                  (v['clientName']?.toString().trim() ?? '') ==
                                      clientName)
                              .length;

                          return _ClientCard(
                            clientName: clientName,
                            itemCount: itemCount,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientItemsScreen(
                                    clientName: clientName),
                              ),
                            ),
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

  /// إرجاع قائمة مرتبة بأسماء العملاء الفريدة مع الفلترة
  List<String> _getUniqueClients(Box box) {
    final query = searchQuery.toLowerCase().trim();

    final names = box
        .toMap()
        .values
        .whereType<Map>()
        .map((v) => (v['clientName']?.toString().trim() ?? 'بدون اسم'))
        .where((name) => query.isEmpty || name.toLowerCase().contains(query))
        .toSet()
        .toList();

    switch (_currentSortType) {
      case SortType.alphabeticalAsc:
        names.sort((a, b) => a.compareTo(b));
        break;
      case SortType.alphabeticalDesc:
        names.sort((a, b) => b.compareTo(a));
        break;
    }

    return names;
  }
}

/// كارد العميل في قائمة سجل العملاء
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
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // أيقونة العميل
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.person_outline,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),

              // اسم العميل وعدد الأصناف
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$itemCount ${itemCount == 1 ? 'صنف' : 'أصناف'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // سهم التنقل
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ويدجت إحصائيات (محتفظ به كما هو)
class SavedSizesStatsCard extends StatelessWidget {
  final int totalProducts;
  final int uniqueClients;

  const SavedSizesStatsCard({
    super.key,
    required this.totalProducts,
    required this.uniqueClients,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.indigo.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _buildStatItem(
              icon: Icons.people_outline_rounded,
              label: "العملاء",
              value: uniqueClients.toString(),
            ),
            VerticalDivider(
              color: Colors.white.withValues(alpha: 0.3),
              thickness: 1,
              indent: 5,
              endIndent: 5,
            ),
            _buildStatItem(
              icon: Icons.inventory_2_outlined,
              label: "الأصناف",
              value: totalProducts.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}