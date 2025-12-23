// lib/src/screens/add_sheet_size_screen.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
  String _cuttingType = 'دوبل';

  final clientNameController = TextEditingController();
  final productNameController = TextEditingController();
  final productCodeController = TextEditingController();
  final lengthController = TextEditingController();
  final widthController = TextEditingController();
  final heightController = TextEditingController();
  final sheetLengthManualController = TextEditingController();
  final sheetWidthManualController = TextEditingController();

  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  List<File> _capturedImages = [];

  bool isOverFlap = false;
  bool isFlap = true;
  bool isOneFlap = false;
  bool isTwoFlap = true;
  bool addTwoMm = false;
  bool isFullSize = true;
  bool isQuarterSize = false;
  bool isQuarterWidth = true;

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

  bool _isDuplicateRecord(String clientName, String productCode) {
    if (clientName.isEmpty || productCode.isEmpty) return false;
    final String newClient = clientName.trim().toLowerCase();
    final String newCode = productCode.trim().toLowerCase();

    for (var i = 0; i < _savedSheetSizesBox.length; i++) {
      final key = _savedSheetSizesBox.keyAt(i);
      final record = _savedSheetSizesBox.getAt(i);
      if (record is Map) {
        final existingClient =
            (record['clientName'] ?? '').toString().trim().toLowerCase();
        final existingCode =
            (record['productCode'] ?? '').toString().trim().toLowerCase();
        if (widget.existingDataKey != null && key == widget.existingDataKey) {
          continue;
        }
        if (existingClient == newClient && existingCode == newCode) return true;
      }
    }
    return false;
  }

  Future<void> _saveSheetSize() async {
    final clientName = clientNameController.text.trim();
    final productCode = productCodeController.text.trim();

    if (_isDuplicateRecord(clientName, productCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "⚠️ العميل: '$clientName' مسجل مسبقاً بالكود: '$productCode'"),
          backgroundColor: Colors.orange.shade900,
        ),
      );
      return;
    }

    // تعديل هنا: حفظ اسم الملف فقط لتجنب مشكلة تغير المسارات مستقبلاً
    final List<String> imageNames =
        _capturedImages.map((file) => file.path.split('/').last).toList();

    final newRecord = <String, dynamic>{
      'processType': _processType,
      'clientName': clientName,
      'productName': productNameController.text.trim(),
      'productCode': productCode,
      'length': lengthController.text,
      'width': widthController.text,
      'height': heightController.text,
      'imagePaths': imageNames, // خزن الأسماء فقط
      'date': DateTime.now().toIso8601String(),
    };

    if (_processType == "تفصيل") {
      newRecord.addAll({
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
    } else {
      newRecord.addAll({
        'sheetLengthManual': sheetLengthManualController.text,
        'sheetWidthManual': sheetWidthManualController.text,
        'cuttingType': _cuttingType,
      });
    }

    if (widget.existingDataKey != null) {
      await _savedSheetSizesBox.put(widget.existingDataKey, newRecord);
    } else {
      await _savedSheetSizesBox.add(newRecord);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم حفظ البيانات بنجاح")));
      Navigator.pop(context);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final backCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);
      _cameraController = CameraController(backCamera, ResolutionPreset.medium,
          enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _loadExistingData(Map data) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDirPath = '${appDir.path}/images';

    setState(() {
      _processType = data['processType'] ?? 'تفصيل';
      _cuttingType = data['cuttingType'] ?? 'دوبل';
      clientNameController.text = data['clientName']?.toString() ?? '';
      productNameController.text = data['productName']?.toString() ?? '';
      productCodeController.text = data['productCode']?.toString() ?? '';
      lengthController.text = data['length']?.toString() ?? '';
      widthController.text = data['width']?.toString() ?? '';
      heightController.text = data['height']?.toString() ?? '';

      // معالجة الصور المحملة: تدعم المسار القديم (الكامل) والجديد (الاسم فقط)
      if (data['imagePaths'] != null) {
        _capturedImages = (data['imagePaths'] as List).map((p) {
          String path = p.toString();
          // إذا كان المسار لا يحتوي على فاصل مجلدات، فهو اسم ملف فقط، فنبني له المسار الصحيح
          if (!path.contains('/')) {
            path = '$imageDirPath/$path';
          }
          return File(path);
        }).toList();
      }

      sheetLengthManualController.text =
          data['sheetLengthManual']?.toString() ?? '';
      sheetWidthManualController.text =
          data['sheetWidthManual']?.toString() ?? '';
      isOverFlap = data['isOverFlap'] ?? false;
      isFlap = data['isFlap'] ?? true;
      isOneFlap = data['isOneFlap'] ?? false;
      isTwoFlap = data['isTwoFlap'] ?? true;
      addTwoMm = data['addTwoMm'] ?? false;
      isFullSize = data['isFullSize'] ?? true;
      isQuarterSize = data['isQuarterSize'] ?? false;
      isQuarterWidth = data['isQuarterWidth'] ?? true;
      sheetLengthResult = data['sheetLengthResult'] ?? "";
      sheetWidthResult = data['sheetWidthResult'] ?? "";
      productionWidth1 = data['productionWidth1'] ?? "";
      productionHeight = data['productionHeight'] ?? "";
      productionWidth2 = data['productionWidth2'] ?? "";
    });
  }

  Future<void> _captureImage() async {
    if (!_isCameraReady || _cameraController == null) return;
    setState(() => _isProcessing = true);
    try {
      final XFile image = await _cameraController!.takePicture();
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${appDir.path}/images');
      if (!await imageDir.exists()) await imageDir.create(recursive: true);

      final String fileName =
          'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = '${imageDir.path}/$fileName';

      var compressedFile = await FlutterImageCompress.compressAndGetFile(
          image.path, targetPath,
          quality: 70);

      if (compressedFile != null) {
        setState(() => _capturedImages.add(File(compressedFile.path)));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _calculateSheet() {
    if (_processType != "تفصيل") return;
    double L = double.tryParse(lengthController.text) ?? 0.0;
    double W = double.tryParse(widthController.text) ?? 0.0;
    double H = double.tryParse(heightController.text) ?? 0.0;
    double sL = 0.0;
    double sW = 0.0;

    if (isFullSize) {
      sL = ((L + W) * 2) + 4;
    } else if (isQuarterSize)
      sL = isQuarterWidth ? W + 4 : L + 4;
    else
      sL = L + W + 4;

    if (isOverFlap && isTwoFlap) {
      sW = addTwoMm ? H + (W * 2) + 0.4 : H + (W * 2);
    } else if (isOverFlap && isOneFlap)
      sW = addTwoMm ? H + W + 0.2 : H + W;
    else if (isFlap && isTwoFlap)
      sW = addTwoMm ? H + W + 0.4 : H + W;
    else if (isFlap && isOneFlap)
      sW = addTwoMm ? H + (W / 2) + 0.2 : H + (W / 2);

    productionHeight = H.toStringAsFixed(2);
    if (isOverFlap && isTwoFlap) {
      productionWidth1 =
          addTwoMm ? (W + 0.2).toStringAsFixed(2) : W.toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isOverFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 =
          addTwoMm ? (W + 0.2).toStringAsFixed(2) : W.toStringAsFixed(2);
    } else if (isFlap && isTwoFlap) {
      productionWidth1 = addTwoMm
          ? ((W / 2) + 0.2).toStringAsFixed(2)
          : (W / 2).toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 = addTwoMm
          ? ((W / 2) + 0.2).toStringAsFixed(2)
          : (W / 2).toStringAsFixed(2);
    } else {
      productionWidth1 = productionWidth2 = ".....";
    }

    setState(() {
      sheetLengthResult = "طول الشيت: ${sL.toStringAsFixed(2)} سم";
      sheetWidthResult = "عرض الشيت: ${sW.toStringAsFixed(2)} سم";
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    clientNameController.dispose();
    productNameController.dispose();
    productCodeController.dispose();
    lengthController.dispose();
    widthController.dispose();
    heightController.dispose();
    sheetLengthManualController.dispose();
    sheetWidthManualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
            widget.existingDataKey != null ? "تعديل مقاس" : "إضافة مقاس جديد"),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.check_circle), onPressed: _saveSheetSize)
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
                processType: _processType,
                cuttingType: _cuttingType,
                onProcessTypeChanged: (v) => setState(() => _processType = v),
                onCuttingTypeChanged: (v) => setState(() => _cuttingType = v!),
              ),
              const Divider(height: 32),
              SheetSizeCamera(
                cameraController: _cameraController,
                isCameraReady: _isCameraReady,
                isProcessing: _isProcessing,
                capturedImages: _capturedImages,
                onCaptureImage: _captureImage,
                onRemoveImage: (i) =>
                    setState(() => _capturedImages.removeAt(i)),
              ),
              if (_processType == "تفصيل") ...[
                const SizedBox(height: 16),
                SheetSizeCheckboxes(
                  isOverFlap: isOverFlap,
                  isFlap: isFlap,
                  isOneFlap: isOneFlap,
                  isTwoFlap: isTwoFlap,
                  addTwoMm: addTwoMm,
                  isFullSize: isFullSize,
                  isQuarterSize: isQuarterSize,
                  isQuarterWidth: isQuarterWidth,
                  onOverFlapChanged: (v) => setState(() {
                    isOverFlap = v!;
                    isFlap = !v;
                  }),
                  onFlapChanged: (v) => setState(() {
                    isFlap = v!;
                    isOverFlap = !v;
                  }),
                  onOneFlapChanged: (v) => setState(() {
                    isOneFlap = v!;
                    isTwoFlap = !v;
                  }),
                  onTwoFlapChanged: (v) => setState(() {
                    isTwoFlap = v!;
                    isOneFlap = !v;
                  }),
                  onAddTwoMmChanged: (v) => setState(() => addTwoMm = v!),
                  onFullSizeChanged: (v) => setState(() {
                    isFullSize = v!;
                    isQuarterSize = false;
                  }),
                  onQuarterSizeChanged: (v) => setState(() {
                    isQuarterSize = v!;
                    isFullSize = false;
                  }),
                  onQuarterWidthChanged: (v) =>
                      setState(() => isQuarterWidth = v!),
                ),
                const SizedBox(height: 16),
                SheetSizeButtons(
                    onCalculate: _calculateSheet, onSave: _saveSheetSize),
                const SizedBox(height: 16),
                SheetSizeCalculations(
                    sheetLengthResult: sheetLengthResult,
                    sheetWidthResult: sheetWidthResult),
                const SizedBox(height: 16),
                SheetSizeProductionTable(
                    productionWidth1: productionWidth1,
                    productionHeight: productionHeight,
                    productionWidth2: productionWidth2),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
