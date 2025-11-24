// lib/src/widgets/saved_size_card.dart

import 'package:flutter/material.dart';

class SavedSizeCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPrint;

  const SavedSizeCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- نوع العملية ---
    final processType = record['processType'] ?? 'تفصيل';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- العنوان والشريحة ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- بيانات العميل (للتفصيل فقط) ---
                      if (processType == 'تفصيل') ...[
                        Text(
                          record['clientName'] ?? 'غير معروف',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "الصنف: ${record['productName'] ?? '—'}",
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          "الكود: ${record['productCode'] ?? '—'}",
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                      ],
                      // --- نوع العملية ---
                      Chip(
                        label: Text(
                          processType,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: (processType == 'تكسير')
                            ? Colors.orange
                            : Colors.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // --- أيقونة العين ---
                IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    if (processType == 'تكسير') {
                      final sheetL = record['sheetLengthManual'] ?? '—';
                      final sheetW = record['sheetWidthManual'] ?? '—';
                      final type = record['cuttingType'] ?? 'غير معروف';
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("تفاصيل التكسير"),
                          content: Text(
                            "طول الشيت: $sheetL سم\nعرض الشيت: $sheetW سم\nالنوع: $type",
                          ),
                          actions: [
                            TextButton(
                              onPressed: Navigator.of(context).pop,
                              child: const Text("حسنًا"),
                            ),
                          ],
                        ),
                      );
                    } else {
                      _showFullDetails(context, record);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: colorScheme.primary,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: onDelete,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // --- الأبعاد الأساسية (دائماً) ---
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "📏 الطول: "),
                  TextSpan(
                    text: "${record['length'] ?? '—'} سم",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: "\n📐 العرض: "),
                  TextSpan(
                    text: "${record['width'] ?? '—'} سم",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: "\n📏 الارتفاع: "),
                  TextSpan(
                    text: "${record['height'] ?? '—'} سم",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 10),

            // --- طول/عرض الشيت (للتكسير اليدوي أو التفصيل المحسوب) ---
            if (processType == 'تكسير') ...[
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: "📏 طول الشيت: "),
                    TextSpan(
                      text: "${record['sheetLengthManual'] ?? '—'} سم",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: "\n📐 عرض الشيت: "),
                    TextSpan(
                      text: "${record['sheetWidthManual'] ?? '—'} سم",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: "\n🔧 النوع: "),
                    TextSpan(
                      text: record['cuttingType'] ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
            ] else if (processType == 'تفصيل') ...[
              if ((record['sheetLengthResult']?.isNotEmpty ?? false) ||
                  (record['sheetWidthResult']?.isNotEmpty ?? false))
                Text(
                  "${record['sheetLengthResult']}\n${record['sheetWidthResult']}",
                  style: const TextStyle(fontSize: 14),
                ),
              const SizedBox(height: 10),
            ],

            // --- زر الطباعة ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print),
                  label: const Text("طباعة"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFullDetails(BuildContext context, Map<String, dynamic> record) {
    double length = double.tryParse(record['length']?.toString() ?? '0') ?? 0.0;
    double width = double.tryParse(record['width']?.toString() ?? '0') ?? 0.0;
    double height = double.tryParse(record['height']?.toString() ?? '0') ?? 0.0;
    bool isFullSize = record['isFullSize'] ?? true;
    bool isQuarterSize = record['isQuarterSize'] ?? false;
    bool isOverFlap = record['isOverFlap'] ?? false;
    bool isTwoFlap = record['isTwoFlap'] ?? true;
    bool addTwoMm = record['addTwoMm'] ?? false;

    double sheetLength = 0.0;
    double sheetWidth = 0.0;
    String productionWidth1 = '';
    String productionWidth2 = '';
    String productionHeight = '';

    if (isFullSize) {
      sheetLength = ((length + width) * 2) + 4;
    } else if (isQuarterSize) {
      sheetLength = width + 4;
    } else {
      sheetLength = length + width + 4;
    }

    if (isOverFlap && isTwoFlap) {
      sheetWidth = addTwoMm ? height + (width * 2) + 0.4 : height + (width * 2);
    } else if (record['isOneFlap'] == true && isOverFlap) {
      sheetWidth = addTwoMm ? height + width + 0.2 : height + width;
    } else if (record['isTwoFlap'] == true) {
      sheetWidth = addTwoMm ? height + width + 0.4 : height + width;
    } else if (record['isOneFlap'] == true) {
      sheetWidth = addTwoMm ? height + (width / 2) + 0.2 : height + (width / 2);
    }

    productionHeight = height.toStringAsFixed(2);

    if (isOverFlap && isTwoFlap) {
      productionWidth1 = addTwoMm
          ? (width + 0.2).toStringAsFixed(2)
          : width.toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isOverFlap && record['isOneFlap'] == true) {
      productionWidth1 = ".....";
      productionWidth2 = addTwoMm
          ? (width + 0.2).toStringAsFixed(2)
          : width.toStringAsFixed(2);
    } else if (record['isTwoFlap'] == true) {
      productionWidth1 = addTwoMm
          ? ((width / 2) + 0.2).toStringAsFixed(2)
          : (width / 2).toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (record['isOneFlap'] == true) {
      productionWidth1 = ".....";
      productionWidth2 = addTwoMm
          ? ((width / 2) + 0.2).toStringAsFixed(2)
          : (width / 2).toStringAsFixed(2);
    } else {
      productionWidth1 = productionWidth2 = ".....";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تفاصيل المقاس"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📏 طول الشيت: ${sheetLength.toStringAsFixed(2)} سم"),
              Text("📐 عرض الشيت: ${sheetWidth.toStringAsFixed(2)} سم"),
              const SizedBox(height: 16),
              const Text("🔧 مقاسات خط الإنتاج",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Table(
                border: TableBorder.all(),
                children: [
                  TableRow(
                    children: [
                      _buildTableCell(productionWidth1),
                      _buildTableCell(productionHeight),
                      _buildTableCell(productionWidth2),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text("حسنًا"),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String value) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(child: Text(value)),
    );
  }
}
