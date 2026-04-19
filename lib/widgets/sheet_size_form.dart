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

  // --- خيار الشيت (جديد) ---
  final bool isSheet;
  final ValueChanged<bool?> onSheetChanged;

  // --- تحكم في حقل اسم العميل ---

  final bool clientNameEnabled;
  final bool clientNameLocked;

  // --- وضع الإضافة المبسط (عميل فقط) ---
  final bool isAddingClientOnly;

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
    required this.isSheet,
    required this.onSheetChanged,
    this.clientNameEnabled = true,
    this.clientNameLocked = false,
    this.isAddingClientOnly = false,
  });


  // ✅ الحصول على القيمة الفعلية لنوع الشريحة (مع افتراضي)
  String get _effectiveCuttingType => cuttingType ?? 'دوبل';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- اختيار نوع العملية ---
        if (!isAddingClientOnly) ...[
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
        ],

        // --- بيانات العميل (مشتركة) ---
        _buildTextField(
          "اسم العميل",
          clientNameController,
          enabled: clientNameEnabled,
          locked: clientNameLocked,
          hint: isAddingClientOnly ? "أدخل اسم العميل (إجباري)" : null,
        ),

        // في وضع إضافة العميل فقط، نخفي "اسم الصنف" و "الأبعاد" ونغير مسمى "الكود"
        if (isAddingClientOnly)
          _buildTextField(
            "كود العميل (اختياري)",
            productCodeController,
            type: TextInputType.number,
            hint: "يمكن استكماله لاحقاً",
          )
        else ...[
          _buildTextField("اسم الصنف", productNameController),
          _buildTextField(
              "كود الصنف", productCodeController, type: TextInputType.number),

          // --- خيار الشيت ---
          CheckboxListTile(
            title: const Text("شيت",
                style: TextStyle(fontWeight: FontWeight.bold)),
            value: isSheet,
            onChanged: onSheetChanged,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),

          // --- الأبعاد (مشتركة) ---
          _buildTextField("الطول", lengthController, type: TextInputType.number),
          _buildTextField("العرض", widthController, type: TextInputType.number),
          if (!isSheet)
            _buildTextField("الارتفاع", heightController, type: TextInputType.number),


          // --- حقول التكسير ---
          if (processType == "تكسير") ...[
            const SizedBox(height: 16),
            _buildTextField(
                "طول الشيت", sheetLengthManualController!, type: TextInputType.number),
            _buildTextField(
                "عرض الشيت", sheetWidthManualController!, type: TextInputType.number),
            const SizedBox(height: 12),
            const Text("نوع الشريحة:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // ignore: deprecated_member_use
            RadioListTile<String>(
              title: const Text("دوبل"),
              value: "دوبل",
              // ignore: deprecated_member_use
              groupValue: _effectiveCuttingType,
              // ignore: deprecated_member_use
              onChanged: onCuttingTypeChanged,
            ),
            // ignore: deprecated_member_use
            RadioListTile<String>(
              title: const Text("سنجل C"),
              value: "سنجل C",
              // ignore: deprecated_member_use
              groupValue: _effectiveCuttingType,
              // ignore: deprecated_member_use
              onChanged: onCuttingTypeChanged,
            ),
            // ignore: deprecated_member_use
            RadioListTile<String>(
              title: const Text("سنجل E"),
              value: "سنجل E",
              // ignore: deprecated_member_use
              groupValue: _effectiveCuttingType,
              // ignore: deprecated_member_use
              onChanged: onCuttingTypeChanged,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType? type, bool enabled = true, bool locked = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          filled: locked,
          fillColor: locked ? Colors.grey.withValues(alpha: 0.12) : null,
          suffixIcon: locked
              ? const Icon(Icons.lock_outline, color: Colors.grey, size: 20)
              : null,
        ),
        keyboardType: type ?? TextInputType.text,
        inputFormatters: type == TextInputType.number
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
            : null,
      ),
    );
  }
}

