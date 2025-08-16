// lib/src/widgets/sheet_size/new_sheet_size_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NewSheetSizeForm extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final void Function(Map<String, dynamic>) onSave;

  const NewSheetSizeForm({
    super.key,
    this.existingData,
    required this.onSave,
  });

  @override
  State<NewSheetSizeForm> createState() => _NewSheetSizeFormState();
}

class _NewSheetSizeFormState extends State<NewSheetSizeForm> {
  late TextEditingController lengthController;
  late TextEditingController widthController;
  late TextEditingController heightController;

  bool isOverFlap = false;
  bool isFlap = true;
  bool isOneFlap = false;
  bool isTwoFlap = true;
  bool addTwoMm = false;
  bool isFullSize = true;
  bool isQuarterSize = false;
  bool isQuarterWidth = true;

  String sheetLengthResult = '';
  String sheetWidthResult = '';
  String productionWidth1 = '';
  String productionWidth2 = '';
  String productionHeight = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    if (widget.existingData != null) {
      _loadExistingData(widget.existingData!);
    }
  }

  void _initializeControllers() {
    lengthController = TextEditingController();
    widthController = TextEditingController();
    heightController = TextEditingController();
  }

  void _loadExistingData(Map<String, dynamic> data) {
    lengthController.text = data['length']?.toString() ?? '';
    widthController.text = data['width']?.toString() ?? '';
    heightController.text = data['height']?.toString() ?? '';

    sheetLengthResult = data['sheetLengthResult'] ?? '';
    sheetWidthResult = data['sheetWidthResult'] ?? '';
    productionWidth1 = data['productionWidth1'] ?? '';
    productionWidth2 = data['productionWidth2'] ?? '';
    productionHeight = data['productionHeight'] ?? '';

    isOverFlap = data['isOverFlap'] ?? false;
    isFlap = data['isFlap'] ?? true;
    isOneFlap = data['isOneFlap'] ?? false;
    isTwoFlap = data['isTwoFlap'] ?? true;
    addTwoMm = data['addTwoMm'] ?? false;
    isFullSize = data['isFullSize'] ?? true;
    isQuarterSize = data['isQuarterSize'] ?? false;
    isQuarterWidth = data['isQuarterWidth'] ?? true;
  }

  void _calculateSheet() {
    double length = double.tryParse(lengthController.text) ?? 0.0;
    double width = double.tryParse(widthController.text) ?? 0.0;
    double height = double.tryParse(heightController.text) ?? 0.0;
    double sheetLength = 0.0;
    double sheetWidth = 0.0;

    if (isFullSize) {
      sheetLength = ((length + width) * 2) + 4;
    } else if (isQuarterSize) {
      sheetLength = isQuarterWidth ? width + 4 : length + 4;
    } else {
      sheetLength = length + width + 4;
    }

    if (isOverFlap && isTwoFlap) {
      sheetWidth = addTwoMm ? height + (width * 2) + 0.4 : height + (width * 2);
    } else if (isOverFlap && isOneFlap) {
      sheetWidth = addTwoMm ? height + width + 0.2 : height + width;
    } else if (isFlap && isTwoFlap) {
      sheetWidth = addTwoMm ? height + width + 0.4 : height + width;
    } else if (isFlap && isOneFlap) {
      sheetWidth = addTwoMm ? height + (width / 2) + 0.2 : height + (width / 2);
    }

    productionHeight = height.toStringAsFixed(2);

    if (isOverFlap && isTwoFlap) {
      productionWidth1 = addTwoMm
          ? (width + 0.2).toStringAsFixed(2)
          : width.toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isOverFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 = addTwoMm
          ? (width + 0.2).toStringAsFixed(2)
          : width.toStringAsFixed(2);
    } else if (isFlap && isTwoFlap) {
      productionWidth1 = addTwoMm
          ? ((width / 2) + 0.2).toStringAsFixed(2)
          : (width / 2).toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 = addTwoMm
          ? ((width / 2) + 0.2).toStringAsFixed(2)
          : (width / 2).toStringAsFixed(2);
    } else {
      productionWidth1 = productionWidth2 = ".....";
    }

    setState(() {
      sheetLengthResult = "📏 طول الشيت: ${sheetLength.toStringAsFixed(2)} سم";
      sheetWidthResult = "📐 عرض الشيت: ${sheetWidth.toStringAsFixed(2)} سم";
    });
  }

  void _save() {
    final newRecord = {
      'length': lengthController.text,
      'width': widthController.text,
      'height': heightController.text,
      'sheetLengthResult': sheetLengthResult,
      'sheetWidthResult': sheetWidthResult,
      'productionWidth1': productionWidth1,
      'productionWidth2': productionWidth2,
      'productionHeight': productionHeight,
      'isOverFlap': isOverFlap,
      'isFlap': isFlap,
      'isOneFlap': isOneFlap,
      'isTwoFlap': isTwoFlap,
      'addTwoMm': addTwoMm,
      'isFullSize': isFullSize,
      'isQuarterSize': isQuarterSize,
      'isQuarterWidth': isQuarterWidth,
      'date': DateTime.now().toIso8601String(),
    };

    widget.onSave(newRecord);
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    lengthController.dispose();
    widthController.dispose();
    heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _hideKeyboard,
      child: Column(
        children: [
          _buildTextField("الطول", lengthController),
          const SizedBox(
            height: 10,
          ),
          _buildTextField("العرض", widthController),
          const SizedBox(
            height: 10,
          ),
          _buildTextField("الارتفاع", heightController),
          const SizedBox(height: 16),

          // أوڨر فلاب / فلاب
          _buildToggleRow(
            "أوڨر فلاب",
            isOverFlap,
            (v) => setState(() {
              isOverFlap = v!;
              isFlap = !v;
            }),
            "فلاب",
            isFlap,
            (v) => setState(() {
              isFlap = v!;
              isOverFlap = !v;
            }),
          ),

          // 1 فلاب / 2 فلاب
          _buildToggleRow(
            "1 فلاب",
            isOneFlap,
            (v) => setState(() {
              isOneFlap = v!;
              isTwoFlap = !v;
            }),
            "2 فلاب",
            isTwoFlap,
            (v) => setState(() {
              isTwoFlap = v!;
              isOneFlap = !v;
            }),
          ),

          // إضافة 2 مم
          CheckboxListTile(
            title: const Text("➕ إضافة 2 مم"),
            value: addTwoMm,
            onChanged: (v) => setState(() => addTwoMm = v ?? false),
          ),

          // ص / 1/2 ص / 1/4 ص
          _buildToggleRow(
            "ص",
            isFullSize,
            (v) => setState(() {
              isFullSize = v!;
              isQuarterSize = false;
            }),
            "½ ص",
            !isFullSize && !isQuarterSize,
            (v) => setState(() {
              isFullSize = !v!;
              isQuarterSize = false;
            }),
          ),
          CheckboxListTile(
            title: const Text("¼ ص"),
            value: isQuarterSize,
            onChanged: (v) => setState(() {
              isQuarterSize = v ?? false;
              isFullSize = false;
            }),
          ),

          if (isQuarterSize)
            _buildToggleRow(
              "عرض",
              isQuarterWidth,
              (v) => setState(() {
                isQuarterWidth = v!;
              }),
              "طول",
              !isQuarterWidth,
              (v) => setState(() {
                isQuarterWidth = !v!;
              }),
            ),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _calculateSheet,
            icon: const Icon(Icons.calculate),
            label: const Text("احسب المقاس"),
          ),

          const SizedBox(height: 20),
          if (sheetLengthResult.isNotEmpty)
            Text(sheetLengthResult,
                style: Theme.of(context).textTheme.titleMedium),
          if (sheetWidthResult.isNotEmpty)
            Text(sheetWidthResult,
                style: Theme.of(context).textTheme.titleMedium),

          const SizedBox(height: 20),
          const Text(
            "🔧 مقاسات خط الإنتاج",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
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

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
    );
  }

  Widget _buildToggleRow(
    String title1,
    bool value1,
    ValueChanged<bool?> onChanged1,
    String title2,
    bool value2,
    ValueChanged<bool?> onChanged2,
  ) {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            title: Text(title1),
            value: value1,
            onChanged: onChanged1,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        Expanded(
          child: CheckboxListTile(
            title: Text(title2),
            value: value2,
            onChanged: onChanged2,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(String value) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
