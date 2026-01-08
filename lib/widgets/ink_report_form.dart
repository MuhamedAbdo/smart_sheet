// lib/src/widgets/ink_report_form.dart

import 'package:flutter/material.dart';

class ColorField {
  final TextEditingController colorController;
  final TextEditingController quantityController;

  ColorField({
    required this.colorController,
    required this.quantityController,
  });
}

class InkReportForm extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? reportKey;
  final void Function(Map<String, dynamic>) onSave;

  const InkReportForm({
    super.key,
    this.initialData,
    this.reportKey,
    required this.onSave,
  });

  @override
  State<InkReportForm> createState() => _InkReportFormState();
}

class _InkReportFormState extends State<InkReportForm> {
  late TextEditingController dateController;
  late TextEditingController clientNameController;
  late TextEditingController productController;
  late TextEditingController productCodeController;
  late TextEditingController lengthController;
  late TextEditingController widthController;
  late TextEditingController heightController;
  late TextEditingController quantityController;
  late TextEditingController notesController;

  List<ColorField> colors = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    dateController = TextEditingController();
    clientNameController = TextEditingController();
    productController = TextEditingController();
    productCodeController = TextEditingController();
    lengthController = TextEditingController();
    widthController = TextEditingController();
    heightController = TextEditingController();
    quantityController = TextEditingController();
    notesController = TextEditingController();

    if (widget.initialData != null) {
      _loadInitialData(widget.initialData!);
    } else {
      final now = DateTime.now();
      dateController.text =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    }
  }

  void _loadInitialData(Map<String, dynamic> data) {
    dateController.text = data['date']?.toString() ?? '';
    clientNameController.text = data['clientName']?.toString() ?? '';
    productController.text = data['product']?.toString() ?? '';
    productCodeController.text = data['productCode']?.toString() ?? '';

    final dimensions = Map<String, dynamic>.from(data['dimensions'] ?? {});
    lengthController.text = dimensions['length']?.toString() ?? '';
    widthController.text = dimensions['width']?.toString() ?? '';
    heightController.text = dimensions['height']?.toString() ?? '';

    quantityController.text = data['quantity']?.toString() ?? '';
    notesController.text = data['notes']?.toString() ?? '';

    colors.clear();
    if (data['colors'] is List) {
      for (var c in data['colors']) {
        colors.add(ColorField(
          colorController: TextEditingController(text: c['color']?.toString()),
          quantityController:
              TextEditingController(text: c['quantity']?.toString()),
        ));
      }
    }
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final report = {
        'date': dateController.text,
        'clientName': clientNameController.text.trim(),
        'product': productController.text.trim(),
        'productCode': productCodeController.text.trim(),
        'dimensions': {
          'length': lengthController.text.trim(),
          'width': widthController.text.trim(),
          'height': heightController.text.trim(),
        },
        'colors': colors
            .map((c) => {
                  'color': c.colorController.text.trim(),
                  'quantity': double.tryParse(c.quantityController.text) ?? 0.0,
                })
            .toList(),
        'quantity': int.tryParse(quantityController.text) ?? 0,
        'notes': notesController.text.trim(),
      };

      widget.onSave(report);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    dateController.dispose();
    clientNameController.dispose();
    productController.dispose();
    productCodeController.dispose();
    lengthController.dispose();
    widthController.dispose();
    heightController.dispose();
    quantityController.dispose();
    notesController.dispose();
    for (var c in colors) {
      c.colorController.dispose();
      c.quantityController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
                title: Text(widget.reportKey == null
                    ? "🆕 إضافة تقرير"
                    : "✏️ تعديل تقرير")),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(dateController, "📅 التاريخ",
                        readOnly: true, onTap: _selectDate),
                    const SizedBox(height: 12),
                    _buildTextField(clientNameController, "👤 اسم العميل"),
                    const SizedBox(height: 12),
                    _buildTextField(productController, "📦 الصنف"),
                    const SizedBox(height: 12),
                    _buildTextField(productCodeController, "🔢 كود الصنف",
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(lengthController, "📏 طول",
                                keyboardType: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildTextField(widthController, "📏 عرض",
                                keyboardType: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildTextField(
                                heightController, "📏 ارتفاع",
                                keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildColorsSection(),
                    const SizedBox(height: 12),
                    _buildTextField(quantityController, "🔢 عدد الشيتات",
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    // ✅ حقل الملاحظات أصبح اختيارياً الآن
                    _buildTextField(notesController, "📝 ملاحظات (اختياري)",
                        maxLines: 3, isRequired: false),
                    const SizedBox(height: 30),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
          if (_isSaving) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildColorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("🎨 الألوان", style: TextStyle(fontWeight: FontWeight.bold)),
        ...colors.map((c) => Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Expanded(child: _buildTextField(c.colorController, "اللون")),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildTextField(c.quantityController, "الكمية",
                          keyboardType: TextInputType.number)),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => colors.remove(c))),
                ],
              ),
            )),
        TextButton.icon(
            onPressed: () => setState(() => colors.add(ColorField(
                colorController: TextEditingController(),
                quantityController: TextEditingController()))),
            icon: const Icon(Icons.add),
            label: const Text("إضافة لون")),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
            child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء"))),
        const SizedBox(width: 12),
        Expanded(
            child: ElevatedButton(
                onPressed: _saveReport, child: const Text("💾 حفظ التقرير"))),
      ],
    );
  }

  // ✅ تم تحديث الدالة لتدعم الحقول الاختيارية
  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = true, // افتراضياً الحقل مطلوب
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: (v) {
        if (isRequired && (v == null || v.isEmpty)) {
          return "مطلوب";
        }
        return null;
      },
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (picked != null) {
      setState(() => dateController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}");
    }
  }
}
