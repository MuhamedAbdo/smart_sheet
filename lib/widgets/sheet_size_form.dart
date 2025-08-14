// lib/src/widgets/sheet_size/sheet_size_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SheetSizeForm extends StatelessWidget {
  final TextEditingController clientNameController;
  final TextEditingController productNameController;
  final TextEditingController productCodeController;
  final TextEditingController lengthController;
  final TextEditingController widthController;
  final TextEditingController heightController;

  const SheetSizeForm({
    super.key,
    required this.clientNameController,
    required this.productNameController,
    required this.productCodeController,
    required this.lengthController,
    required this.widthController,
    required this.heightController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTextField("اسم العميل", clientNameController),
        _buildTextField("اسم الصنف", productNameController),
        _buildTextField(
            "كود الصنف", productCodeController, TextInputType.number),
        _buildTextField("الطول", lengthController, TextInputType.number),
        _buildTextField("العرض", widthController, TextInputType.number),
        _buildTextField("الارتفاع", heightController, TextInputType.number),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      [TextInputType? type]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: type ?? TextInputType.text,
        inputFormatters: type == TextInputType.number
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
            : null,
      ),
    );
  }
}
