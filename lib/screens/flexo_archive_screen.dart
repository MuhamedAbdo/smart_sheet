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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("أرشيف الفلكسو التاريخي"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearArchive,
            tooltip: "مسح الكل",
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _archiveBox!.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("📂 الأرشيف فارغ"));
          }

          final entries = box.toMap().entries.toList();

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
                record: Map<String, dynamic>.from(report),
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
                  Text(
                    displayDate,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
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
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black87, fontSize: 15),
                        children: [
                          TextSpan(
                            text: product.replaceAll("\n", " "),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (dimStr.isNotEmpty) ...[
                            const TextSpan(text: " | ", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            TextSpan(
                              text: dimStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ],
                      ),
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
                            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
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
