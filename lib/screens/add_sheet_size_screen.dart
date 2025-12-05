// lib/src/screens/add_sheet_size_screen.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/sheet_size_buttons.dart';
import 'package:smart_sheet/widgets/sheet_size_calculations.dart';
import 'package:smart_sheet/widgets/sheet_size_camera.dart';
import 'package:smart_sheet/widgets/sheet_size_checkboxes.dart';
import 'package:smart_sheet/widgets/sheet_size_form.dart';
import 'package:smart_sheet/widgets/sheet_size_production_table.dart';

class AddSheetSizeScreen extends StatefulWidget {
  final Map? existingData;
  final dynamic existingDataKey;

  const AddSheetSizeScreen({
    super.key,
    this.existingData,
    this.existingDataKey,
  });

  @override
  State<AddSheetSizeScreen> createState() => _AddSheetSizeScreenState();
}

class _AddSheetSizeScreenState extends State<AddSheetSizeScreen> {
  String _processType = "تفصيل";

  // --- مشترك ---
  final clientNameController = TextEditingController();
  final productNameController = TextEditingController();
  final productCodeController = TextEditingController();
  final lengthController = TextEditingController();
  final widthController = TextEditingController();
  final heightController = TextEditingController();

  // --- للتكسير ---
  final sheetLengthManualController = TextEditingController();
  final sheetWidthManualController = TextEditingController();
  String? _cuttingType = "دوبل"; // افتراضي

  // --- الكاميرا (مشتركة) ---
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  List<File> _capturedImages = [];

  // --- الفلاب (للتفصيل فقط) ---
  bool isOverFlap = false;
  bool isFlap = true;
  bool isOneFlap = false;
  bool isTwoFlap = true;
  bool addTwoMm = false;
  bool isFullSize = true;
  bool isQuarterSize = false;
  bool isQuarterWidth = true;

  // --- النتائج (للتفصيل فقط) ---
  String sheetLengthResult = "";
  String sheetWidthResult = "";
  String productionWidth1 = "";
  String productionHeight = "";
  String productionWidth2 = "";

  late Box _savedSheetSizesBox;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _savedSheetSizesBox = await Hive.openBox('savedSheetSizes');
    _initializeCamera();
    if (widget.existingData != null) {
      _loadExistingData(widget.existingData!);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.isNotEmpty ? cameras.first : throw Exception(),
      );

      _cameraController = CameraController(backCamera, ResolutionPreset.medium);
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("الكاميرا غير متاحة")),
        );
      }
    }
  }

  void _loadExistingData(Map data) {
    _processType = data['processType'] ?? 'تفصيل';

    clientNameController.text = data['clientName'] ?? '';
    productNameController.text = data['productName'] ?? '';
    productCodeController.text = data['productCode']?.toString() ?? '';
    lengthController.text = data['length'] ?? '';
    widthController.text = data['width'] ?? '';
    heightController.text = data['height'] ?? '';

    if (_processType == "تفصيل") {
      isOverFlap = data['isOverFlap'] ?? false;
      isFlap = data['isFlap'] ?? true;
      isOneFlap = data['isOneFlap'] ?? false;
      isTwoFlap = data['isTwoFlap'] ?? true;
      addTwoMm = data['addTwoMm'] ?? false;
      isFullSize = data['isFullSize'] ?? true;
      isQuarterSize = data['isQuarterSize'] ?? false;
      isQuarterWidth = data['isQuarterWidth'] ?? true;
      sheetLengthResult = data['sheetLengthResult'] ?? '';
      sheetWidthResult = data['sheetWidthResult'] ?? '';
      productionWidth1 = data['productionWidth1'] ?? '';
      productionHeight = data['productionHeight'] ?? '';
      productionWidth2 = data['productionWidth2'] ?? '';
    } else if (_processType == "تكسير") {
      sheetLengthManualController.text = data['sheetLengthManual'] ?? '';
      sheetWidthManualController.text = data['sheetWidthManual'] ?? '';
      _cuttingType = data['cuttingType'] ?? 'دوبل';
    }

    if (data.containsKey('imagePaths') && data['imagePaths'] is List) {
      _capturedImages =
          (data['imagePaths'] as List).map((p) => File(p.toString())).toList();
    }
  }

  Future<void> _captureImage() async {
    if (!_isCameraReady ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("الكاميرا غير جاهزة")));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final XFile image = await _cameraController!.takePicture();
      final dir = await getTemporaryDirectory();
      final pathStr =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await File(image.path).copy(pathStr);
      setState(() {
        _capturedImages.add(saved);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  void _removeImage(int index) =>
      setState(() => _capturedImages.removeAt(index));

  void calculateSheet() {
    if (_processType != "تفصيل") return;

    double l = double.tryParse(lengthController.text) ?? 0;
    double w = double.tryParse(widthController.text) ?? 0;
    double h = double.tryParse(heightController.text) ?? 0;
    double sheetL = 0, sheetW = 0;

    if (isFullSize) {
      sheetL = (l + w) * 2 + 4;
    } else if (isQuarterSize) {
      sheetL = isQuarterWidth ? w + 4 : l + 4;
    } else {
      sheetL = l + w + 4;
    }

    if (isOverFlap && isTwoFlap) {
      sheetW = addTwoMm ? h + w * 2 + 0.4 : h + w * 2;
    } else if (isOverFlap && isOneFlap) {
      sheetW = addTwoMm ? h + w + 0.2 : h + w;
    } else if (isFlap && isTwoFlap) {
      sheetW = addTwoMm ? h + w + 0.4 : h + w;
    } else if (isFlap && isOneFlap) {
      sheetW = addTwoMm ? h + w / 2 + 0.2 : h + w / 2;
    }

    productionHeight = h.toStringAsFixed(2);

    if (isOverFlap && isTwoFlap) {
      productionWidth1 =
          addTwoMm ? (w + 0.2).toStringAsFixed(2) : w.toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isOverFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 =
          addTwoMm ? (w + 0.2).toStringAsFixed(2) : w.toStringAsFixed(2);
    } else if (isFlap && isTwoFlap) {
      productionWidth1 = addTwoMm
          ? ((w / 2) + 0.2).toStringAsFixed(2)
          : (w / 2).toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 = addTwoMm
          ? ((w / 2) + 0.2).toStringAsFixed(2)
          : (w / 2).toStringAsFixed(2);
    } else {
      productionWidth1 = productionWidth2 = ".....";
    }

    setState(() {
      sheetLengthResult = "طول الشيت: ${sheetL.toStringAsFixed(2)} سم";
      sheetWidthResult = "عرض الشيت: ${sheetW.toStringAsFixed(2)} سم";
    });
  }

  Future<void> _saveSheetSize() async {
    // ✅ الحقول الأساسية تُحفَظ دائمًا (للعرض والبحث)
    final record = <String, dynamic>{
      'processType': _processType,
      'clientName': clientNameController.text,
      'productName': productNameController.text,
      'productCode': productCodeController.text,
      'length': lengthController.text,
      'width': widthController.text,
      'height': heightController.text,
      'imagePaths': _capturedImages.map((f) => f.path).toList(),
      'date': DateTime.now().toIso8601String(),
    };

    // ✅ إضافة الحقول الخاصة حسب النوع
    if (_processType == "تفصيل") {
      record.addAll({
        'isOverFlap': isOverFlap,
        'isFlap': isFlap,
        'isOneFlap': isOneFlap,
        'isTwoFlap': isTwoFlap,
        'addTwoMm': addTwoMm,
        'isFullSize': isFullSize,
        'isQuarterSize': isQuarterSize,
        'isQuarterWidth': isQuarterWidth,
        'sheetLengthResult': sheetLengthResult,
        'sheetWidthResult': sheetWidthResult,
        'productionWidth1': productionWidth1,
        'productionHeight': productionHeight,
        'productionWidth2': productionWidth2,
      });
    } else if (_processType == "تكسير") {
      record.addAll({
        'sheetLengthManual': sheetLengthManualController.text,
        'sheetWidthManual': sheetWidthManualController.text,
        'cuttingType': _cuttingType,
      });
    }

    if (widget.existingDataKey != null) {
      await _savedSheetSizesBox.put(widget.existingDataKey, record);
    } else {
      await _savedSheetSizesBox.add(record);
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("تم الحفظ")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("إضافة مقاس جديد"),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveSheetSize)
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SheetSizeForm(
                clientNameController: clientNameController,
                productNameController: productNameController,
                productCodeController: productCodeController,
                lengthController: lengthController,
                widthController: widthController,
                heightController: heightController,
                sheetLengthManualController: sheetLengthManualController,
                sheetWidthManualController: sheetWidthManualController,
                cuttingType: _cuttingType,
                onCuttingTypeChanged: (value) =>
                    setState(() => _cuttingType = value),
                processType: _processType,
                onProcessTypeChanged: (value) =>
                    setState(() => _processType = value),
              ),
              const SizedBox(height: 20),

              // --- الكاميرا (مشتركة) ---
              SheetSizeCamera(
                cameraController: _cameraController,
                isCameraReady: _isCameraReady,
                isProcessing: _isProcessing,
                capturedImages: _capturedImages,
                onCaptureImage: _captureImage,
                onRemoveImage: _removeImage,
              ),
              const SizedBox(height: 20),

              // --- الفلاب و"احسب" و"مقاسات خط الإنتاج" (للتفصيل فقط) ---
              if (_processType == "تفصيل") ...[
                SheetSizeCheckboxes(
                  isOverFlap: isOverFlap,
                  isFlap: isFlap,
                  isOneFlap: isOneFlap,
                  isTwoFlap: isTwoFlap,
                  addTwoMm: addTwoMm,
                  isFullSize: isFullSize,
                  isQuarterSize: isQuarterSize,
                  isQuarterWidth: isQuarterWidth,
                  onOverFlapChanged: (v) => setState(() => isOverFlap = v!),
                  onFlapChanged: (v) => setState(() => isFlap = v!),
                  onOneFlapChanged: (v) => setState(() => isOneFlap = v!),
                  onTwoFlapChanged: (v) => setState(() => isTwoFlap = v!),
                  onAddTwoMmChanged: (v) => setState(() => addTwoMm = v!),
                  onFullSizeChanged: (v) => setState(() => isFullSize = v!),
                  onQuarterSizeChanged: (v) =>
                      setState(() => isQuarterSize = v!),
                  onQuarterWidthChanged: (v) =>
                      setState(() => isQuarterWidth = v!),
                ),
                const SizedBox(height: 20),
                SheetSizeButtons(onCalculate: calculateSheet, onSave: () {}),
                const SizedBox(height: 20),
                SheetSizeCalculations(
                  sheetLengthResult: sheetLengthResult,
                  sheetWidthResult: sheetWidthResult,
                ),
                const SizedBox(height: 20),
                SheetSizeProductionTable(
                  productionWidth1: productionWidth1,
                  productionHeight: productionHeight,
                  productionWidth2: productionWidth2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
