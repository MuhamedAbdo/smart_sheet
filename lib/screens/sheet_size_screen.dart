// lib/src/screens/sheet_size_screen.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/sheet_size_buttons.dart';
import 'package:smart_sheet/widgets/sheet_size_calculations.dart';
import 'package:smart_sheet/widgets/sheet_size_camera.dart';
import 'package:smart_sheet/widgets/sheet_size_checkboxes.dart';
import 'package:smart_sheet/widgets/sheet_size_form.dart';
import 'package:smart_sheet/widgets/sheet_size_production_table.dart';

class SheetSizeScreen extends StatefulWidget {
  final Map? existingData;
  final dynamic existingDataKey;

  const SheetSizeScreen({super.key, this.existingData, this.existingDataKey});

  @override
  State<SheetSizeScreen> createState() => _SheetSizeScreenState();
}

class _SheetSizeScreenState extends State<SheetSizeScreen> {
  // Controllers
  final clientNameController = TextEditingController();
  final productNameController = TextEditingController();
  final productCodeController = TextEditingController();
  final lengthController = TextEditingController();
  final widthController = TextEditingController();
  final heightController = TextEditingController();

  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  List<File> _capturedImages = [];

  // Checkboxes
  bool isOverFlap = false;
  bool isFlap = true;
  bool isOneFlap = false;
  bool isTwoFlap = true;
  bool addTwoMm = false;
  bool isFullSize = true;
  bool isQuarterSize = false;
  bool isQuarterWidth = true;

  // Results
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
          const SnackBar(content: Text("الكاميرا غير متاحة على هذا الجهاز")),
        );
      }
    }
  }

  void _loadExistingData(Map data) {
    clientNameController.text = data['clientName']?.toString() ?? '';
    productNameController.text = data['productName']?.toString() ?? '';
    productCodeController.text = data['productCode']?.toString() ?? '';
    lengthController.text = data['length']?.toString() ?? '';
    widthController.text = data['width']?.toString() ?? '';
    heightController.text = data['height']?.toString() ?? '';

    isOverFlap = data['isOverFlap'] ?? false;
    isFlap = data['isFlap'] ?? true;
    isOneFlap = data['isOneFlap'] ?? false;
    isTwoFlap = data['isTwoFlap'] ?? true;
    addTwoMm = data['addTwoMm'] ?? false;
    isFullSize = data['isFullSize'] ?? true;
    isQuarterSize = data['isQuarterSize'] ?? false;
    isQuarterWidth = data['isQuarterWidth'] ?? true;

    sheetLengthResult = data['sheetLengthResult']?.toString() ?? '';
    sheetWidthResult = data['sheetWidthResult']?.toString() ?? '';
    productionWidth1 = data['productionWidth1']?.toString() ?? '';
    productionHeight = data['productionHeight']?.toString() ?? '';
    productionWidth2 = data['productionWidth2']?.toString() ?? '';

    if (data.containsKey('imagePaths') && data['imagePaths'] is List) {
      final List<dynamic> paths = List.from(data['imagePaths']);
      _capturedImages = paths.map((p) => File(p.toString())).toList();
    }
  }

  Future<void> _captureImage() async {
    if (!_isCameraReady ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الكاميرا غير جاهزة")),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      final Directory dir = await getTemporaryDirectory();
      final String imagePath =
          path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      final File savedImage = await File(image.path).copy(imagePath);

      setState(() {
        _capturedImages.add(savedImage);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ: $e")),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
  }

  void calculateSheet() {
    double length = double.tryParse(lengthController.text) ?? 0.0;
    double width = double.tryParse(widthController.text) ?? 0.0;
    double height = double.tryParse(heightController.text) ?? 0.0;
    double sheetLength = 0.0;
    double sheetWidth = 0.0;

    if (isFullSize) {
      sheetLength = ((length + width) * 2) + 4;
    } else if (isQuarterSize) {
      if (isQuarterWidth) {
        sheetLength = width + 4;
      } else {
        sheetLength = length + 4;
      }
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
      sheetLengthResult = "طول الشيت: ${sheetLength.toStringAsFixed(2)} سم";
      sheetWidthResult = "عرض الشيت: ${sheetWidth.toStringAsFixed(2)} سم";
    });
  }

  Future<void> _saveSheetSize() async {
    final newRecord = {
      'clientName': clientNameController.text,
      'productName': productNameController.text,
      'productCode': productCodeController.text,
      'length': lengthController.text,
      'width': widthController.text,
      'height': heightController.text,
      'sheetLengthResult': sheetLengthResult,
      'sheetWidthResult': sheetWidthResult,
      'productionWidth1': productionWidth1,
      'productionHeight': productionHeight,
      'productionWidth2': productionWidth2,
      'isOverFlap': isOverFlap,
      'isFlap': isFlap,
      'isOneFlap': isOneFlap,
      'isTwoFlap': isTwoFlap,
      'addTwoMm': addTwoMm,
      'isFullSize': isFullSize,
      'isQuarterSize': isQuarterSize,
      'isQuarterWidth': isQuarterWidth,
      'imagePaths': _capturedImages.map((file) => file.path).toList(),
      'date': DateTime.now().toIso8601String(),
    };

    // إذا كان في تعديل
    if (widget.existingDataKey != null) {
      await _savedSheetSizesBox.put(widget.existingDataKey, newRecord);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم تحديث المقاس بنجاح!")),
        );
      }
      Navigator.pop(context);
      return;
    }

    // التحقق من التكرار
    bool isDuplicate = false;
    for (var key in _savedSheetSizesBox.keys) {
      final existing = _savedSheetSizesBox.get(key) as Map;
      if (existing['clientName'] == newRecord['clientName'] &&
          existing['productCode'] == newRecord['productCode']) {
        if (isQuarterSize) {
          if (existing['isQuarterSize'] == true &&
              existing['isQuarterWidth'] == isQuarterWidth) {
            isDuplicate = true;
            break;
          }
        } else {
          isDuplicate = true;
          break;
        }
      }
    }

    if (isDuplicate) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("تنبيه"),
            content: const Text("هذا المقاس موجود بالفعل. هل تريد استبداله؟"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("لا"),
              ),
              TextButton(
                onPressed: () async {
                  await _savedSheetSizesBox.add(newRecord);
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("تم الحفظ بنجاح!")),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text("نعم"),
              ),
            ],
          ),
        );
      }
    } else {
      await _savedSheetSizesBox.add(newRecord);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم الحفظ بنجاح!")),
        );
        Navigator.pop(context);
      }
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("إضافة مقاس جديد"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSheetSize, // ✅ الحفظ من خلال أيقونة الحفظ فقط
          ),
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
              ),
              const SizedBox(height: 20),
              SheetSizeCamera(
                cameraController: _cameraController,
                isCameraReady: _isCameraReady,
                isProcessing: _isProcessing,
                capturedImages: _capturedImages,
                onCaptureImage: _captureImage,
                onRemoveImage: _removeImage,
              ),
              const SizedBox(height: 20),
              SheetSizeCheckboxes(
                isOverFlap: isOverFlap,
                isFlap: isFlap,
                isOneFlap: isOneFlap,
                isTwoFlap: isTwoFlap,
                addTwoMm: addTwoMm,
                isFullSize: isFullSize,
                isQuarterSize: isQuarterSize,
                isQuarterWidth: isQuarterWidth,
                onOverFlapChanged: (value) {
                  setState(() {
                    isOverFlap = value!;
                    isFlap = !value;
                  });
                },
                onFlapChanged: (value) {
                  setState(() {
                    isFlap = value!;
                    isOverFlap = !value;
                  });
                },
                onOneFlapChanged: (value) {
                  setState(() {
                    isOneFlap = value!;
                    isTwoFlap = !value;
                  });
                },
                onTwoFlapChanged: (value) {
                  setState(() {
                    isTwoFlap = value!;
                    isOneFlap = !value;
                  });
                },
                onAddTwoMmChanged: (value) {
                  setState(() {
                    addTwoMm = value!;
                  });
                },
                onFullSizeChanged: (value) {
                  setState(() {
                    isFullSize = value!;
                    isQuarterSize = false;
                  });
                },
                onQuarterSizeChanged: (value) {
                  setState(() {
                    isQuarterSize = value!;
                    isFullSize = false;
                  });
                },
                onQuarterWidthChanged: (value) {
                  setState(() {
                    isQuarterWidth = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              // ✅ تم إزالة زر الحفظ من الـ body
              SheetSizeButtons(
                onCalculate: calculateSheet, onSave: () {},
                // لا يوجد onSave
              ),
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
          ),
        ),
      ),
    );
  }
}
