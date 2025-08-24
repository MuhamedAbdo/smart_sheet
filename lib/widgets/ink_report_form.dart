// lib/src/widgets/flexo/ink_report_form.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';

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
          "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    }
  }

  void _loadInitialData(Map<String, dynamic> data) {
    dateController.text = data['date']?.toString() ?? '';
    clientNameController.text = data['clientName']?.toString() ?? '';
    productController.text = data['product']?.toString() ?? '';
    productCodeController.text = data['productCode']?.toString() ?? '';

    final dimensions = data['dimensions'] as Map<String, dynamic>? ?? {};
    lengthController.text = dimensions['length']?.toString() ?? '';
    widthController.text = dimensions['width']?.toString() ?? '';
    heightController.text = dimensions['height']?.toString() ?? '';

    quantityController.text = data['quantity']?.toString() ?? '';
    notesController.text = data['notes']?.toString() ?? '';

    colors.clear();
    final colorsList = data['colors'] as List? ?? [];
    colors = colorsList.map((c) {
      return ColorField(
        colorController:
            TextEditingController(text: c['color']?.toString() ?? ''),
        quantityController:
            TextEditingController(text: (c['quantity'] ?? 0).toString()),
      );
    }).toList();

    final imagePaths = data['imagePaths'] as List? ?? [];
    _capturedImages = imagePaths.map((p) => File(p.toString())).toList();
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

      _cameraController = CameraController(backCamera, ResolutionPreset.medium);
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
      final dir = await getTemporaryDirectory();
      final String path =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File savedImage = await File(image.path).copy(path);

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
      dateController.text = "${picked.year}-${picked.month}-${picked.day}";
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
        'length': double.tryParse(lengthController.text.trim()) ?? 0.0,
        'width': double.tryParse(widthController.text.trim()) ?? 0.0,
        'height': double.tryParse(heightController.text.trim()) ?? 0.0,
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
      'image_urls': [], // سيتم ملؤه عند الرفع لاحقًا
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
    return Padding(
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
                      labelText: "👤 اسم العميل", border: OutlineInputBorder()),
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
                      labelText: "🔢 كود الصنف", border: OutlineInputBorder()),
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
                              icon: const Icon(Icons.delete, color: Colors.red),
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
    );
  }

  void _showFullScreenImage(int index) {
    final PageController controller = PageController(initialPage: index);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Stack(
        alignment: Alignment.topRight,
        children: [
          PageView.builder(
            controller: controller,
            itemCount: _capturedImages.length,
            itemBuilder: (context, i) => Center(
                child: PhotoView(
              imageProvider: FileImage(_capturedImages[i]),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained * 1,
              maxScale: PhotoViewComputedScale.covered * 2,
            )),
          ),
          IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                controller.dispose();
                Navigator.pop(context);
              }),
        ],
      ),
    );
  }
}
