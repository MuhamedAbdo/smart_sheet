import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/screens/archive_detail_screen.dart';
import 'package:smart_sheet/widgets/saved_size_search_bar.dart';

class FlexoArchiveScreen extends StatefulWidget {
  const FlexoArchiveScreen({super.key});

  @override
  State<FlexoArchiveScreen> createState() => _FlexoArchiveScreenState();
}

class _FlexoArchiveScreenState extends State<FlexoArchiveScreen> {
  Box? _archiveBox;
  bool _isSearching = false;
  String _searchQuery = "";


  @override
  void initState() {
    super.initState();
    _archiveBox = Hive.box('flexoArchive');
  }

  void _deleteEntry(dynamic key) {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "تأكيد حذف الأرشيف",
      content: "هل أنت متأكد من حذف هذا السجل نهائياً؟",
      onConfirm: () async {
        await _archiveBox!.delete(key);
      },
    );
  }

  void _clearArchive() {
    if (_archiveBox == null || _archiveBox!.isEmpty) return;
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "⚠️ مسح الأرشيف بالكامل",
      content: "هل أنت متأكد من مسح كافة بيانات الأرشيف نهائياً؟",
      onConfirm: () async {
        await _archiveBox!.clear();
      },
    );
  }

  // ✅ ميزة استعادة سجل واحد للأرشيف
  void _restoreEntry(dynamic key, Map data) async {
    try {
      final reportsBox = Hive.box('inkReports');
      final reportData = data['data'] ?? data;
      
      // نقوم بإضافة نسخة للتقارير النشطة دون حذفها من الأرشيف
      await reportsBox.add(reportData);
      
      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: "تم استعادة نسخة من التقرير للقسم النشط بنجاح",
          backgroundColor: Colors.green,
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      debugPrint("Restore Error: $e");
    }
  }

  // ✅ ميزة استعادة الكل
  void _restoreAllEntries() {
    if (_archiveBox == null || _archiveBox!.isEmpty) return;
    
    UIUtils.showDeleteConfirmation(
      context: context,
      title: "إستعادة نسخة من كافة البيانات",
      content: "سيتم نسخ كافة تقارير الأرشيف إلى القسم النشط مع الإبقاء عليها في الأرشيف. هل تريد الاستمرار؟",
      confirmLabel: "إستعادة الكل",
      confirmColor: Colors.green,
      onConfirm: () async {
        try {
          final reportsBox = Hive.box('inkReports');
          final allArchive = _archiveBox!.toMap();
          
          for (var entry in allArchive.entries) {
            final data = entry.value as Map;
            final reportData = data['data'] ?? data;
            await reportsBox.add(reportData);
          }
          // تم إزالة عملية التفريغ (clear) بناءً على طلب المستخدم لإبقاء الأرشيف كنسخة دائمة
          
          if (mounted) {
            UIUtils.showInfoSnackBar(
              message: "تم إستعادة نسخة من كافة التقارير للقسم النشط بنجاح",
              backgroundColor: Colors.green,
              icon: Icons.settings_backup_restore,
            );
          }
        } catch (e) {
          debugPrint("Restore All Error: $e");
        }
      },
    );
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

  List<MapEntry<dynamic, dynamic>> _getFilteredEntries(Box box) {
    final query = _normalizeString(_searchQuery);
    var entries = box.toMap().entries.toList();

    if (query.isNotEmpty) {
      entries = entries.where((e) {
        final data = e.value as Map;
        final report = data['data'] ?? data;
        final clientName =
            _normalizeString(report['clientName']?.toString() ?? '');
        return clientName.contains(query);
      }).toList();
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? SavedSizeSearchBar(
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text("أرشيف الفلكسو التاريخي"),
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchQuery = "";
            }),
            tooltip: _isSearching ? "إغلاق البحث" : "بحث باسم العميل",
          ),
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.settings_backup_restore),
              onPressed: _restoreAllEntries,
              tooltip: "إستعادة الكل للرئيسية",
              color: Colors.greenAccent,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearArchive,
              tooltip: "مسح الكل",
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40.0),
          child: ValueListenableBuilder(
            valueListenable: _archiveBox!.listenable(),
            builder: (context, Box box, _) {
              final filteredCount = _getFilteredEntries(box).length;
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Container(
                height: 40,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.blueGrey[50],
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.black54 : Colors.blueGrey[100]!,
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 16,
                      color: isDark ? Colors.blueAccent[100] : Colors.blueAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'إجمالي التقارير: $filteredCount',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        color: isDark ? Colors.grey[300] : Colors.blueGrey[800],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: _archiveBox!.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("📂 الأرشيف فارغ"));
          }

          var entries = _getFilteredEntries(box);

          if (entries.isEmpty && _isSearching) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "لا توجد تقارير مؤرشفة لهذا العميل",
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          if (entries.isEmpty) {
            return const Center(child: Text("📂 لا توجد بيانات"));
          }

          // ✅ الفرز النهائي: التاريخ (تنازلي) ثم اسم العميل (تصاعدي)
          entries.sort((a, b) {
            final dataA = a.value as Map;
            final dataB = b.value as Map;

            final reportA = dataA['data'] ?? dataA;
            final reportB = dataB['data'] ?? dataB;

            final dateAStr = reportA['date']?.toString() ?? '2000-01-01';
            final dateBStr = reportB['date']?.toString() ?? '2000-01-01';

            final dateA = DateTime.tryParse(dateAStr) ?? DateTime(2000);
            final dateB = DateTime.tryParse(dateBStr) ?? DateTime(2000);

            int dateCompare = dateB.compareTo(dateA);
            if (dateCompare != 0) return dateCompare;

            final nameA = (reportA['clientName'] ?? '').toString().toLowerCase();
            final nameB = (reportB['clientName'] ?? '').toString().toLowerCase();

            return nameA.compareTo(nameB);
          });

          return ListView.builder(
            itemCount: entries.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _buildArchiveCard(entry.key, entry.value as Map);
            },
          );
        },
      ),
    );
  }

  Widget _buildArchiveCard(dynamic key, Map data) {
    final report = data['data'] ?? data;
    final String clientName = report['clientName'] ?? "بدون اسم";
    final String product = report['product'] ?? "بدون صنف";
    final String displayDate = report['date'] ?? "---";

    final dims = report['dimensions'];
    final String dimStr = dims != null && (dims['length'] != 0 || dims['width'] != 0)
        ? "${dims['length']} × ${dims['width']} × ${dims['height']}"
        : "";

    final colors = report['colors'] as List? ?? [];

    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onLongPress: () => _deleteEntry(key),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArchiveDetailScreen(
                record: {
                  ...Map<String, dynamic>.from(report),
                  'archiveDate': data['archiveDate'] ?? '---',
                },
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      clientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayDate,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.settings_backup_restore, color: Colors.green),
                        onPressed: () => _restoreEntry(key, data),
                        tooltip: "إستعادة للرئيسية",
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                        onPressed: () => _deleteEntry(key),
                        tooltip: "حذف من الأرشيف",
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black87,
                              fontSize: 15,
                            ),
                            children: [
                              TextSpan(
                                text: product.replaceAll("\n", " "),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: " [ ${report['productCode'] ?? '---'} ]",
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (dimStr.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Text("📏 المقاس: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    dimStr,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (report['notes'] != null && 
                  report['notes'].toString().isNotEmpty && 
                  !report['notes'].toString().contains("مستورد"))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sticky_note_2_outlined, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            report['notes'],
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.orange.shade100
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (colors.isNotEmpty) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: colors.map((c) {
                      final name = c['color'] ?? '---';
                      final qty = c['quantity'] ?? '0';
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle, size: 10, color: Colors.blueAccent),
                            const SizedBox(width: 6),
                            Text(
                              "$name: $qty ل",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
