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
  final TextEditingController? formNumberController;
  final TextEditingController? numberOfBoxesController;
  final VoidCallback? onImportForm;
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
    this.formNumberController,
    this.numberOfBoxesController,
    this.onImportForm,
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
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text("تفصيل"),
                selected: processType == "تفصيل",
                onSelected: (v) => onProcessTypeChanged("تفصيل"),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text("تكسير"),
                selected: processType == "تكسير",
                onSelected: (v) => onProcessTypeChanged("تكسير"),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // --- بيانات العميل (مشتركة) ---
        _buildTextField(
          context,
          "اسم العميل",
          clientNameController,
          enabled: clientNameEnabled,
          locked: clientNameLocked,
          hint: isAddingClientOnly ? "أدخل اسم العميل (إجباري)" : null,
        ),

        // في وضع إضافة العميل فقط، نخفي "اسم الصنف" و "الأبعاد" ونغير مسمى "الكود"
        if (isAddingClientOnly)
          _buildTextField(
            context,
            "كود العميل (اختياري)",
            productCodeController,
            type: TextInputType.number,
            hint: "يمكن استكماله لاحقاً",
          )
        else ...[
          _buildTextField(context, "اسم الصنف", productNameController),
          _buildTextField(context, 
              "كود الصنف", productCodeController, type: TextInputType.number),

          // --- خيار الشيت ---
          if (processType == "تكسير")
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
          _buildTextField(context, "الطول", lengthController, type: TextInputType.number),
          _buildTextField(context, "العرض", widthController, type: TextInputType.number),
          if (!(isSheet && processType == "تكسير"))
            _buildTextField(context, "الارتفاع", heightController, type: TextInputType.number),



          // --- حقول التكسير ---
          if (processType == "تكسير") ...[
            const SizedBox(height: 8),
            if (onImportForm != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onImportForm,
                    icon: const Icon(Icons.search),
                    label: const Text("استدعاء من مخزن الفورم"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            if (formNumberController != null)
              _buildTextField(context, 
                  "رقم الفورمة", formNumberController!, type: TextInputType.text),
            if (numberOfBoxesController != null)
              _buildTextField(context, 
                  "عدد العلب (من الفورمة)", numberOfBoxesController!, type: TextInputType.number),
            _buildTextField(context, 
                "طول الشيت", sheetLengthManualController!, type: TextInputType.number),
            _buildTextField(context, 
                "عرض الشيت", sheetWidthManualController!, type: TextInputType.number),
            const SizedBox(height: 8),
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

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller,
      {TextInputType? type, bool enabled = true, bool locked = false, String? hint}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    Color? fillColor;
    if (locked) {
      fillColor = Colors.grey.withValues(alpha: 0.12);
    } else {
      fillColor = isDarkMode ? Colors.black26 : Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: fillColor,
          suffixIcon: locked
              ? const Icon(Icons.lock_outline, color: Colors.grey, size: 20)
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        keyboardType: type ?? TextInputType.text,
        inputFormatters: type == TextInputType.number
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
            : null,
      ),
    );
  }
}

