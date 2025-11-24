// lib/src/widgets/sheet_size/sheet_size_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SheetSizeForm extends StatelessWidget {
  // --- بيانات العميل (مشتركة) ---
  final TextEditingController clientNameController;
  final TextEditingController productNameController;
  final TextEditingController productCodeController;

  // --- الأبعاد (مشتركة) ---
  final TextEditingController lengthController;
  final TextEditingController widthController;
  final TextEditingController heightController;

  // --- للتكسير ---
  final TextEditingController? sheetLengthManualController;
  final TextEditingController? sheetWidthManualController;
  final String? cuttingType; // "دوبل" | "سنجل C" | "سنجل E"
  final ValueChanged<String?>? onCuttingTypeChanged;

  // --- نوع العملية ---
  final String processType;
  final ValueChanged<String> onProcessTypeChanged;

  const SheetSizeForm({
    super.key,
    required this.clientNameController,
    required this.productNameController,
    required this.productCodeController,
    required this.lengthController,
    required this.widthController,
    required this.heightController,
    this.sheetLengthManualController,
    this.sheetWidthManualController,
    this.cuttingType,
    this.onCuttingTypeChanged,
    required this.processType,
    required this.onProcessTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- اختيار نوع العملية ---
        Row(
          children: [
            const Text("نوع العملية:"),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text("تفصيل"),
              selected: processType == "تفصيل",
              onSelected: (v) => onProcessTypeChanged("تفصيل"),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text("تكسير"),
              selected: processType == "تكسير",
              onSelected: (v) => onProcessTypeChanged("تكسير"),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- بيانات العميل (مشتركة) ---
        _buildTextField("اسم العميل", clientNameController),
        _buildTextField("اسم الصنف", productNameController),
        _buildTextField(
            "كود الصنف", productCodeController, TextInputType.number),

        // --- الأبعاد (مشتركة) ---
        _buildTextField("الطول", lengthController, TextInputType.number),
        _buildTextField("العرض", widthController, TextInputType.number),
        _buildTextField("الارتفاع", heightController, TextInputType.number),

        // --- حقول التكسير ---
        if (processType == "تكسير") ...[
          const SizedBox(height: 16),
          _buildTextField("طول الشيت", sheetLengthManualController!),
          _buildTextField("عرض الشيت", sheetWidthManualController!),
          const SizedBox(height: 12),
          const Text("نوع الشريحة:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // --- checkboxes عمودية ---
          RadioListTile<String>(
            title: const Text("دوبل"),
            value: "دوبل",
            groupValue: cuttingType,
            onChanged: onCuttingTypeChanged,
          ),
          RadioListTile<String>(
            title: const Text("سنجل C"),
            value: "سنجل C",
            groupValue: cuttingType,
            onChanged: onCuttingTypeChanged,
          ),
          RadioListTile<String>(
            title: const Text("سنجل E"),
            value: "سنجل E",
            groupValue: cuttingType,
            onChanged: onCuttingTypeChanged,
          ),
        ],
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
