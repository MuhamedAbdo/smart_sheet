import 'package:flutter/material.dart';

class ColorField {
  final TextEditingController colorController;
  final TextEditingController quantityController;

  ColorField({
    required this.colorController,
    required this.quantityController,
  });

  // ✅ إضافة دالة dispose()
  void dispose() {
    colorController.dispose();
    quantityController.dispose();
  }
}
