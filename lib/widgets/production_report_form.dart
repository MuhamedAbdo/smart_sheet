// lib/widgets/production_report_form.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/utils/worker_utils.dart';

class ColorField {
  final TextEditingController colorController;
  final TextEditingController quantityController;

  ColorField({
    required this.colorController,
    required this.quantityController,
  });
}

class ProductionReportForm extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? reportKey;
  final String? department;
  final void Function(Map<String, dynamic>) onSave;

  const ProductionReportForm({
    super.key,
    this.initialData,
    this.reportKey,
    this.department,
    required this.onSave,
  });

  @override
  State<ProductionReportForm> createState() => _ProductionReportFormState();
}

class _ProductionReportFormState extends State<ProductionReportForm> {
  bool get isProductionLine =>
      (widget.department == 'production_line') ||
      (widget.initialData?['department'] == 'production_line');

  bool get isCrushing =>
      (widget.department == 'crushing') ||
      (widget.initialData?['department'] == 'crushing');

  late TextEditingController dateController;
  late TextEditingController clientNameController;
  late TextEditingController productController;
  late TextEditingController productCodeController;
  late TextEditingController lengthController;
  late TextEditingController widthController;
  late TextEditingController heightController;
  late TextEditingController quantityController;
  late TextEditingController weightController;
  late TextEditingController notesController;
  List<TextEditingController> paperLayerControllers = [];

  // New Fields
  late TextEditingController orderNumberController;
  late TextEditingController startTimeController;
  late TextEditingController endTimeController;
  late TextEditingController formNumberController;
  late TextEditingController lineWasteController;
  late TextEditingController printWasteController;
  late TextEditingController downtimeStartController;
  late TextEditingController downtimeEndController;
  late TextEditingController totalDowntimeController;
  // الماكينة والفني — يُستخدمان فقط للقراءة/الكتابة عند التحميل والحفظ
  // القيمة المختارة من الـ Dropdown
  String? _selectedMachineName;
  String? _selectedTechnicianName;

  List<ColorField> colors = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool isSheet = false;


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
    weightController = TextEditingController();
    notesController = TextEditingController();

    orderNumberController = TextEditingController();
    startTimeController = TextEditingController();
    endTimeController = TextEditingController();
    formNumberController = TextEditingController();
    lineWasteController = TextEditingController();
    printWasteController = TextEditingController();
    downtimeStartController = TextEditingController();
    downtimeEndController = TextEditingController();
    totalDowntimeController = TextEditingController();
    // Default values for waste as requested
    lineWasteController.text = "0";
    printWasteController.text = "0";
    paperLayerControllers = [];

    if (widget.initialData != null) {
      _loadInitialData(widget.initialData!);
    } else {
      final now = DateTime.now();
      dateController.text =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    }

    if (isProductionLine && paperLayerControllers.isEmpty) {
      paperLayerControllers = [
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ];
    }
  }

  void _loadInitialData(Map<String, dynamic> data) {
    dateController.text = data['date']?.toString() ?? '';
    clientNameController.text = data['clientName']?.toString() ?? '';
    productController.text = data['product']?.toString() ??
        data['productName']?.toString() ??
        '';
    productCodeController.text = data['productCode']?.toString() ?? '';
    isSheet = data['isSheet'] ?? false;


    final dimensions = Map<String, dynamic>.from(data['dimensions'] ?? {});
    lengthController.text = dimensions['length']?.toString() ?? '';
    widthController.text = dimensions['width']?.toString() ?? '';
    heightController.text = dimensions['height']?.toString() ?? '';

    quantityController.text = data['quantity']?.toString() ?? '';
    weightController.text =
        data['weight']?.toString() ?? dimensions['weight']?.toString() ?? '';
    notesController.text = data['notes']?.toString() ?? '';

    orderNumberController.text = data['orderNumber']?.toString() ?? data['order_number']?.toString() ?? '';
    formNumberController.text = data['formNumber']?.toString() ?? data['form_number']?.toString() ?? '';
    startTimeController.text = data['startTime']?.toString() ?? data['start_time']?.toString() ?? '';
    endTimeController.text = data['endTime']?.toString() ?? data['end_time']?.toString() ?? '';
    lineWasteController.text = data['lineWaste']?.toString() ?? data['line_waste']?.toString() ?? '';
    printWasteController.text = data['printWaste']?.toString() ?? data['print_waste']?.toString() ?? '';
    downtimeStartController.text = data['downtimeStart']?.toString() ?? data['downtime_start']?.toString() ?? '';
    downtimeEndController.text = data['downtimeEnd']?.toString() ?? data['downtime_end']?.toString() ?? '';
    totalDowntimeController.text = data['totalDowntime']?.toString() ?? '0';
    _selectedMachineName = data['machineName']?.toString() ?? data['machine_name']?.toString();
    if (_selectedMachineName != null && _selectedMachineName!.isEmpty) _selectedMachineName = null;
    _selectedTechnicianName = data['technicianName']?.toString() ?? data['technician_name']?.toString();
    if (_selectedTechnicianName != null && _selectedTechnicianName!.isEmpty) _selectedTechnicianName = null;

    paperLayerControllers.clear();
    final pLayers = data['paperLayers'] ??
        data['paper_layers'] ??
        dimensions['paperLayers'] ??
        dimensions['paper_layers'];
    if (pLayers is List && pLayers.isNotEmpty) {
      for (var layer in pLayers) {
        final str = layer.toString().trim();
        paperLayerControllers.add(TextEditingController(text: str));
      }
    }

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
      final wVal = double.tryParse(weightController.text.trim()) ?? 0.0;
      final layersVal = paperLayerControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final report = {
        'date': dateController.text,
        'clientName': clientNameController.text.trim(),
        'product': productController.text.trim(),
        'productCode': productCodeController.text.trim(),
        'dimensions': {
          'length': lengthController.text.trim(),
          'width': widthController.text.trim(),
          'height': isSheet ? "0" : heightController.text.trim(),
          'weight': wVal,
          'paperLayers': layersVal,
          'form_number': formNumberController.text.trim(),
        },
        'isSheet': isSheet,

        'colors': (isProductionLine || isCrushing)
            ? []
            : colors
                .map((c) => {
                      'color': c.colorController.text.trim(),
                      'quantity':
                          double.tryParse(c.quantityController.text) ?? 0.0,
                    })
                .toList(),
        'quantity': int.tryParse(quantityController.text) ?? 0,
        'weight': wVal,
        'paperLayers': layersVal,
        'paper_layers': layersVal,
        'department':
            widget.department ?? widget.initialData?['department'] ?? 'flexo',
        'shift': widget.initialData?['shift'],
        'notes': notesController.text.trim(),
        'orderNumber': orderNumberController.text.trim(),
        'formNumber': formNumberController.text.trim(),
        'form_number': formNumberController.text.trim(),
        'startTime': startTimeController.text.trim(),
        'endTime': endTimeController.text.trim(),
        'lineWaste': int.tryParse(lineWasteController.text) ?? 0,
        'printWaste': (isProductionLine || isCrushing)
            ? 0
            : (int.tryParse(printWasteController.text) ?? 0),
        'downtimeStart': downtimeStartController.text.trim(),
        'downtimeEnd': downtimeEndController.text.trim(),
        'totalDowntime': int.tryParse(totalDowntimeController.text) ?? 0,
        'machineName': _selectedMachineName ?? '',
        'technicianName': _selectedTechnicianName ?? '',
      };

      widget.onSave(report);
    } catch (e) {
      UIUtils.showInfoSnackBar(
        message: "حدث خطأ أثناء الحفظ",
        backgroundColor: Colors.redAccent,
        icon: Icons.error_outline,
      );
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
    weightController.dispose();
    notesController.dispose();
    orderNumberController.dispose();
    formNumberController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    lineWasteController.dispose();
    printWasteController.dispose();
    downtimeStartController.dispose();
    downtimeEndController.dispose();
    totalDowntimeController.dispose();
    for (var c in colors) {
      c.colorController.dispose();
      c.quantityController.dispose();
    }
    for (var c in paperLayerControllers) {
      c.dispose();
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
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
                title: Text(widget.reportKey == null
                    ? "🆕 إضافة تقرير إنتاج"
                    : "✏️ تعديل تقرير إنتاج")),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(dateController, "📅 التاريخ",
                        readOnly: true, onTap: _selectDate),
                    const SizedBox(height: 12),
                    _buildTextField(orderNumberController, "🔢 رقم أمر التشغيل",
                        icon: Icons.numbers,
                        isRequired: false,
                        keyboardType: TextInputType.number),
                    if (isCrushing) ...[
                      const SizedBox(height: 12),
                      _buildTextField(formNumberController, "📄 رقم الفورمة",
                          icon: Icons.confirmation_number,
                          isRequired: false,
                          keyboardType: TextInputType.number),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(startTimeController, "🕒 وقت البداية",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(startTimeController),
                              isRequired: false),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(endTimeController, "🕒 وقت النهاية",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(endTimeController),
                              isRequired: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(clientNameController, "👤 اسم العميل"),
                    const SizedBox(height: 12),
                    _buildTextField(productController, "📦 الصنف"),
                    const SizedBox(height: 12),
                    _buildTextField(productCodeController, "كود الصنف", icon: Icons.qr_code, keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    _buildMachineAndTechRow(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(lengthController, "📏 طول",
                                keyboardType: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildTextField(widthController, "📏 عرض",
                                keyboardType: TextInputType.number)),
                        if (!isSheet) ...[
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildTextField(
                                  heightController, "📏 ارتفاع",
                                  keyboardType: TextInputType.number)),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),
                    if (isProductionLine)
                      _buildPaperLayersSection()
                    else if (!isCrushing)
                      _buildColorsSection(),
                    const SizedBox(height: 12),
                    _buildTextField(quantityController, "🔢 عدد الشيتات",
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    if (isProductionLine || isCrushing) ...[
                      if (isProductionLine) ...[
                        _buildTextField(
                          weightController,
                          "⚖️ الوزن (بالطن)",
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          isRequired: false,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildTextField(lineWasteController, "📉 الهالك",
                          keyboardType: TextInputType.number, isRequired: false),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                                lineWasteController, "📉 هالك الإنتاج",
                                keyboardType: TextInputType.number,
                                isRequired: false),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTextField(
                                printWasteController, "📉 هالك الطباعة",
                                keyboardType: TextInputType.number,
                                isRequired: false),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(downtimeStartController, "⏱️ بداية العطل",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(downtimeStartController),
                              isRequired: false),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(downtimeEndController, "⏱️ نهاية العطل",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(downtimeEndController),
                              isRequired: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(totalDowntimeController, "⏳ إجمالي دقائق التعطل",
                        icon: Icons.timer_off,
                        keyboardType: TextInputType.number,
                        isRequired: false),
                    const SizedBox(height: 12),
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

  void _addPaperLayer() {
    setState(() {
      paperLayerControllers.add(TextEditingController());
    });
  }

  void _removePaperLayer(int index) {
    if (paperLayerControllers.length > 1) {
      setState(() {
        paperLayerControllers[index].dispose();
        paperLayerControllers.removeAt(index);
      });
    }
  }

  Widget _buildPaperLayersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("📜 طبقات وأنواع الورق",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(
              onPressed: _addPaperLayer,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("إضافة طبقة"),
            ),
          ],
        ),
        ...List.generate(paperLayerControllers.length, (index) {
          final label = index == 0
              ? 'الطبقة 1 (الوجه الخارجي)'
              : index == 1
                  ? 'الطبقة 2 (الفلوت)'
                  : 'الطبقة ${index + 1}';
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    paperLayerControllers[index],
                    label,
                    icon: Icons.layers_outlined,
                    isRequired: false,
                  ),
                ),
                if (paperLayerControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removePaperLayer(index),
                  ),
              ],
            ),
          );
        }),
      ],
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

  // ─── صف الماكينة والفني بـ Dropdowns من Hive ────────────────────────────────
  Widget _buildMachineAndTechRow() {
    final String dept = isCrushing ? 'crushing' : (isProductionLine ? 'production_line' : 'flexo');
    final machineBox = Hive.isBoxOpen('flexo_machines')
        ? Hive.box<FlexoMachine>('flexo_machines')
        : null;

    // قائمة الماكينات (مع إزالة التكرارات والتوافق مع الـ Fallback في خط الإنتاج)
    final List<String> machineNames = FlexoMachine.getMachinesForDepartment(dept)
        .map((m) => m.name)
        .toSet()
        .toList();

    if (dept == 'production_line' &&
        machineNames.length == 1 &&
        machineNames.first == 'خط الإنتاج' &&
        (_selectedMachineName == null || _selectedMachineName!.isEmpty)) {
      _selectedMachineName = 'خط الإنتاج';
    }

    // قائمة العمال (مع إزالة التكرارات وترتيبهم)
    final List<String> workerNames = WorkerUtils.getSortedWorkers(dept)
            .map((w) => w.name)
            .toSet()
            .toList();

    // إذا كانت القيمة المخزّنة غير موجودة في القائمة — أضفها مؤقتاً للتوافق
    if (_selectedMachineName != null &&
        _selectedMachineName!.isNotEmpty &&
        !machineNames.contains(_selectedMachineName)) {
      machineNames.insert(0, _selectedMachineName!);
    }
    if (_selectedTechnicianName != null &&
        _selectedTechnicianName!.isNotEmpty &&
        !workerNames.contains(_selectedTechnicianName)) {
      workerNames.insert(0, _selectedTechnicianName!);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── الماكينة ─────────────────────────────────────────────────────────
        Expanded(
          child: _buildDropdownField(
            label: 'الماكينة',
            icon: Icons.precision_manufacturing,
            value: _selectedMachineName,
            items: machineNames,
            isRequired: false,
            onChanged: (v) => setState(() => _selectedMachineName = v),
            onAddManual: () async {
              final name = await _showAddManualDialog('اسم الماكينة الجديدة');
              if (name != null && name.isNotEmpty) {
                // أضف الماكينة الجديدة إلى Hive
                if (machineBox != null) {
                  final id = 'manual_${DateTime.now().millisecondsSinceEpoch}';
                  await machineBox.add(FlexoMachine(
                    id: id,
                    name: name,
                    department: dept,
                  ));
                }
                setState(() => _selectedMachineName = name);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        // ── الفني ────────────────────────────────────────────────────────────
        Expanded(
          child: _buildDropdownField(
            label: 'الفني المسؤول',
            icon: Icons.engineering,
            value: _selectedTechnicianName,
            items: workerNames,
            isRequired: false,
            onChanged: (v) => setState(() => _selectedTechnicianName = v),
            onAddManual: () async {
              final name = await _showAddManualDialog('اسم الفني');
              if (name != null && name.isNotEmpty) {
                setState(() => _selectedTechnicianName = name);
              }
            },
          ),
        ),
      ],
    );
  }

  // ─── Dropdown موحّد مع زر "إدخال يدوي" ────────────────────────────────────
  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    required Future<void> Function() onAddManual,
    bool isRequired = false,
  }) {
    const manualKey = '__MANUAL__';

    // بناء قائمة العناصر مع الخيار اليدوي
    final dropdownItems = [
      ...items.map((name) => DropdownMenuItem<String>(
            value: name,
            child: Text(name, overflow: TextOverflow.ellipsis),
          )),
      const DropdownMenuItem<String>(
        value: manualKey,
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: Colors.blue),
            SizedBox(width: 6),
            Text('إدخال يدوي...', style: TextStyle(color: Colors.blue)),
          ],
        ),
      ),
    ];

    return DropdownButtonFormField<String>(
      initialValue: (value != null && items.contains(value)) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        // إظهار القيمة المخزّنة كـ hint حتى لو خارج القائمة
        hintText: (value != null && value.isNotEmpty && !items.contains(value))
            ? value
            : null,
      ),
      isExpanded: true,
      items: dropdownItems,
      validator: isRequired
          ? (v) => (v == null || v.isEmpty) ? 'مطلوب' : null
          : null,
      onChanged: (v) async {
        if (v == manualKey) {
          await onAddManual();
        } else {
          onChanged(v);
        }
      },
    );
  }

  // ─── نافذة الإدخال اليدوي ─────────────────────────────────────────────────
  Future<String?> _showAddManualDialog(String title) async {
    String? result;
    await showDialog(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'أدخل الاسم...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                result = c.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
    return result;
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = true,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
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

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }
}
