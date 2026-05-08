import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/screens/archive_detail_screen.dart';

class FlexoArchiveScreen extends StatefulWidget {
  const FlexoArchiveScreen({super.key});

  @override
  State<FlexoArchiveScreen> createState() => _FlexoArchiveScreenState();
}

class _FlexoArchiveScreenState extends State<FlexoArchiveScreen> {
  Box? _archiveBox;
  bool _isSearching = false;
  String _searchQuery = "";
  String? _selectedDate;

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
          message: "تم استعادة نسخة من تقرير الإنتاج للقسم النشط بنجاح",
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
      content:
          "سيتم نسخ كافة تقارير الأرشيف إلى القسم النشط مع الإبقاء عليها في الأرشيف. هل تريد الاستمرار؟",
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
              message:
                  "تم إستعادة نسخة من كافة تقارير الإنتاج للقسم النشط بنجاح",
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

  // ✅ توحيد صيغة التاريخ وتجاهل الوقت (YYYY-MM-DD)
  String _normalizeDateOnly(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == "---") return "";
    try {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      }
    } catch (_) {}
    // في حال فشل الـ parse، نحاول استخراج أول جزء (التاريخ) يدوياً
    return dateStr.split(' ')[0].split('T')[0];
  }

  List<MapEntry<dynamic, dynamic>> _getFilteredEntries(Box box) {
    final query = _normalizeString(_searchQuery);
    var entries = box.toMap().entries.toList();

    // 1. الفلترة باسم العميل أو كود الصنف
    if (query.isNotEmpty) {
      entries = entries.where((e) {
        final data = e.value as Map;
        final report = data['data'] ?? data;
        final clientName =
            _normalizeString(report['clientName']?.toString() ?? '');
        final productCode =
            _normalizeString(report['productCode']?.toString() ?? '');
        return clientName.contains(query) || productCode.contains(query);
      }).toList();
    }

    // 2. الفلترة بتاريخ الإنتاج المختار (بعد التطبيع)
    if (_selectedDate != null) {
      entries = entries.where((e) {
        final data = e.value as Map;
        final report = data['data'] ?? data;
        final prodDate = _normalizeDateOnly(report['date']?.toString());
        return prodDate == _selectedDate;
      }).toList();
    }

    return entries;
  }

  List<String> _getUniqueDates() {
    if (_archiveBox == null) return [];
    final Set<String> dates = {};
    for (var value in _archiveBox!.values) {
      final data = value as Map;
      final report = data['data'] ?? data;
      final rawDate = report['date']?.toString();
      final normalizedDate = _normalizeDateOnly(rawDate);
      if (normalizedDate.isNotEmpty) {
        dates.add(normalizedDate);
      }
    }
    final sortedDates = dates.toList();
    sortedDates.sort((a, b) {
      final dA = DateTime.tryParse(a) ?? DateTime(2000);
      final dB = DateTime.tryParse(b) ?? DateTime(2000);
      return dB.compareTo(dA);
    });
    return sortedDates;
  }

  void _showDateFilterDialog() {
    final uniqueDates = _getUniqueDates();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.all(0),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: const Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.white),
              SizedBox(width: 10),
              Text("اختر تاريخ الإنتاج",
                  style: TextStyle(
                      color: Colors.white, fontFamily: 'Cairo', fontSize: 18)),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // خيار عرض الكل
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: Colors.green),
                title: const Text("عرض الكل (إلغاء الفلترة)",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontFamily: 'Cairo')),
                onTap: () {
                  setState(() => _selectedDate = null);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              if (uniqueDates.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("لا توجد تواريخ متاحة"),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: uniqueDates.length,
                    itemBuilder: (ctx, index) {
                      final date = uniqueDates[index];
                      final isSelected = _selectedDate == date;
                      return ListTile(
                        leading: Icon(Icons.date_range,
                            color:
                                isSelected ? Colors.blueAccent : Colors.grey),
                        title: Text(date,
                            style: TextStyle(
                              color: isSelected ? Colors.blueAccent : null,
                              fontWeight: isSelected ? FontWeight.bold : null,
                            )),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.blueAccent)
                            : null,
                        onTap: () {
                          setState(() => _selectedDate = date);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color appBarIconColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: appBarIconColor),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: _isSearching
            ? Container(
                height: 40,
                decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  autofocus: true,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'بحث باسم العميل...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                              _selectedDate = null;
                            })),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              )
            : const Text("أرشيف تقارير الإنتاج"),
        centerTitle: !_isSearching,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: appBarIconColor),
            tooltip: "خيارات الأرشيف",
            onSelected: (value) async {
              if (value == 'search') {
                setState(() => _isSearching = true);
              } else if (value == 'filter') {
                _showDateFilterDialog();
              } else if (value == 'restore') {
                _restoreAllEntries();
              } else if (value == 'clear') {
                _clearArchive();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'search',
                  child:
                      ListTile(leading: Icon(Icons.search), title: Text('بحث'))),
              const PopupMenuItem(
                  value: 'filter',
                  child: ListTile(
                      leading: Icon(Icons.calendar_month),
                      title: Text('تصفية بالتاريخ'))),
              const PopupMenuItem(
                  value: 'restore',
                  child: ListTile(
                      leading: Icon(Icons.settings_backup_restore),
                      title: Text('استعادة الكل'))),
              const PopupMenuItem(
                  value: 'clear',
                  child: ListTile(
                      leading:
                          Icon(Icons.delete_sweep_outlined, color: Colors.red),
                      title: Text('مسح الأرشيف',
                          style: TextStyle(color: Colors.red)))),
            ],
          ),
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
                      color:
                          isDark ? Colors.blueAccent[100] : Colors.blueAccent,
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
                    if (_selectedDate != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event,
                                size: 14, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              _selectedDate!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(() => _selectedDate = null),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold),
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

            final nameA =
                (reportA['clientName'] ?? '').toString().toLowerCase();
            final nameB =
                (reportB['clientName'] ?? '').toString().toLowerCase();

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
    final String dimStr =
        dims != null && (dims['length'] != 0 || dims['width'] != 0)
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
                        icon: const Icon(Icons.settings_backup_restore,
                            color: Colors.green),
                        onPressed: () => _restoreEntry(key, data),
                        tooltip: "إستعادة للرئيسية",
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red.shade300),
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
                  const Icon(Icons.inventory_2_outlined,
                      size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white70
                                  : Colors.black87,
                              fontSize: 15,
                            ),
                            children: [
                              TextSpan(
                                text: product.replaceAll("\n", " "),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
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
                                const Text("📏 المقاس: ",
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
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
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            report['notes'],
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle,
                                size: 10, color: Colors.blueAccent),
                            const SizedBox(width: 6),
                            Text(
                              "$name: $qty ل",
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
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
