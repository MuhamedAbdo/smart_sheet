// lib/src/widgets/sheet_size/sheet_size_buttons.dart

import 'package:flutter/material.dart';

class SheetSizeButtons extends StatelessWidget {
  final VoidCallback onCalculate;
  final VoidCallback onSave;

  const SheetSizeButtons({
    super.key,
    required this.onCalculate,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onCalculate,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          ),
          child: const Text("احسب"),
        ),
        //
      ],
    );
  }
}
