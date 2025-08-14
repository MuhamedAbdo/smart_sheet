// lib/src/widgets/sheet_size/sheet_size_calculations.dart

import 'package:flutter/material.dart';

class SheetSizeCalculations extends StatelessWidget {
  final String sheetLengthResult;
  final String sheetWidthResult;

  const SheetSizeCalculations({
    super.key,
    required this.sheetLengthResult,
    required this.sheetWidthResult,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(sheetLengthResult,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(sheetWidthResult,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
