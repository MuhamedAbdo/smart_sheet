// lib/src/widgets/sheet_size/sheet_size_production_table.dart

import 'package:flutter/material.dart';

class SheetSizeProductionTable extends StatelessWidget {
  final String productionWidth1;
  final String productionHeight;
  final String productionWidth2;

  const SheetSizeProductionTable({
    super.key,
    required this.productionWidth1,
    required this.productionHeight,
    required this.productionWidth2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "مقاسات خط الإنتاج",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
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
    );
  }

  Widget _buildTableCell(String value) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
