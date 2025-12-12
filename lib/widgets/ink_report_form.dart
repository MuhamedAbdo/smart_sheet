// lib/src/widgets/flexo/ink_report_form.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sheet/utils/image_utils.dart'; // ← إضافة استيراد دالة الحفظ

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
  List<File> _capturedImages = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeCamera();
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
      dateController.text =
          "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    }
  }

  void _loadInitialData(Map<String, dynamic> data) {
    dateController.text = data['date'] ?? '';
    clientNameController.text = data['clientName'] ?? '';
    productController.text = data['product'] ?? '';
    productCodeController.text = data['productCode']?.toString() ?? '';

    final dimensions = Map<String, dynamic>.from(data['dimensions'] ?? {});
    lengthController.text = dimensions['length']?.toString() ?? '';
    widthController.text = dimensions['width']?.toString() ?? '';
    heightController.text = dimensions['height']?.toString() ?? '';

    quantityController.text = data['quantity']?.toString() ?? '';
    notesController.text = data['notes'] ?? '';

    colors.clear();
    if (data.containsKey('colors') && data['colors'] is List) {
      colors = (data['colors'] as List).map((c) {
        return ColorField(
          colorController: TextEditingController(text: c['color']),
          quantityController:
              TextEditingController(text: (c['quantity'] ?? 0).toString()),
        );
      }).toList();
    }

    // ✅ تحميل الصور مع تجاهل الملفات المفقودة
    if (data.containsKey('imagePaths') && data['imagePaths'] is List) {
      final List<String> paths = List<String>.from(data['imagePaths']);
      _capturedImages =
          paths.where((p) => File(p).existsSync()).map((p) => File(p)).toList();
    }
  }

  Future<void> _initializeCamera() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("الرجاء منح صلاحية الكاميرا")),
        );
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final prefs = await SharedPreferences.getInstance();
      final String quality = prefs.getString('camera_quality') ?? 'medium';

      ResolutionPreset preset = switch (quality) {
        'low' => ResolutionPreset.low,
        'high' => ResolutionPreset.high,
        'medium' || _ => ResolutionPreset.medium,
      };

      _cameraController = CameraController(backCamera, preset);
      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  Future<void> _captureImage() async {
    if (!_isCameraReady ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final XFile image = await _cameraController!.takePicture();

      // ✅ استخدام الدالة الجديدة لحفظ الصورة (تعيد المسار الكامل)
      final imagePath = await saveImagePermanently(File(image.path));
      final savedImage = File(imagePath);

      setState(() {
        _capturedImages.add(savedImage);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("فشل في التقاط الصورة: $e")),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
  }

  void _addColorField() {
    setState(() {
      colors.add(ColorField(
        colorController: TextEditingController(),
        quantityController: TextEditingController(),
      ));
    });
  }

  void _removeColorField(int index) {
    if (index < 0 || index >= colors.length) return;
    setState(() {
      colors[index].colorController.dispose();
      colors[index].quantityController.dispose();
      colors.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      dateController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  void _saveReport() {
    if (!_formKey.currentState!.validate()) return;

    final report = <String, dynamic>{
      'date': dateController.text,
      'clientName': clientNameController.text,
      'product': productController.text,
      'productCode': productCodeController.text,
      'dimensions': {
        'length': lengthController.text,
        'width': widthController.text,
        'height': heightController.text,
      },
      'colors': colors
          .map((c) => {
                'color': c.colorController.text.trim(),
                'quantity':
                    double.tryParse(c.quantityController.text.trim()) ?? 0.0,
              })
          .toList(),
      'quantity': int.tryParse(quantityController.text.trim()) ?? 0,
      'notes': notesController.text.trim(),
      'imagePaths': _capturedImages.map((f) => f.path).toList(),
    };

    widget.onSave(report);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.reportKey == null
                        ? "🆕 إضافة تقرير"
                        : "✏️ تعديل تقرير",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: dateController,
                    readOnly: true,
                    onTap: _selectDate,
                    decoration: const InputDecoration(
                        labelText: "📅 التاريخ", border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? "مطلوب" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: clientNameController,
                    decoration: const InputDecoration(
                        labelText: "👤 اسم العميل",
                        border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? "مطلوب" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: productController,
                    decoration: const InputDecoration(
                        labelText: "📦 الصنف", border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? "مطلوب" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: productCodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "🔢 كود الصنف",
                        border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? "مطلوب" : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: lengthController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: "📏 الطول",
                              border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? "مطلوب" : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: widthController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: "📏 العرض",
                              border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? "مطلوب" : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: heightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: "📏 الارتفاع",
                              border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? "مطلوب" : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ✅ الكاميرا
                  if (_isCameraReady && _cameraController != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("📸 الصور",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                            height: 200,
                            child: CameraPreview(_cameraController!)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _captureImage,
                          icon: const Icon(Icons.camera),
                          label: const Text("التقط صورة"),
                        ),
                        if (_capturedImages.isNotEmpty)
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _capturedImages.length,
                              itemBuilder: (context, i) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showFullScreenImage(i),
                                        child: Image.file(_capturedImages[i],
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 18, color: Colors.red),
                                        onPressed: () => _removeImage(i),
                                      ),
                                    ]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  const Text("🎨 الألوان",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...colors.map((c) {
                    final index = colors.indexOf(c);
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: TextFormField(
                                    controller: c.colorController,
                                    decoration: const InputDecoration(
                                        labelText: "اللون",
                                        border: OutlineInputBorder()))),
                            const SizedBox(width: 8),
                            Expanded(
                                flex: 2,
                                child: TextFormField(
                                    controller: c.quantityController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: "الكمية (لتر)",
                                        border: OutlineInputBorder()))),
                            IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeColorField(index)),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                  ElevatedButton.icon(
                      onPressed: _addColorField,
                      icon: const Icon(Icons.add),
                      label: const Text("إضافة لون")),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "🔢 عدد الشيتات",
                        border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? "مطلوب" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: "📝 ملاحظات", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("❌ إلغاء"))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: ElevatedButton(
                              onPressed: _saveReport,
                              child: const Text("💾 حفظ التقرير"))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Stack(
        alignment: Alignment.topRight,
        children: [
          PageView.builder(
            itemCount: _capturedImages.length,
            itemBuilder: (context, i) => Center(
                child: PhotoView(imageProvider: FileImage(_capturedImages[i]))),
          ),
          IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
