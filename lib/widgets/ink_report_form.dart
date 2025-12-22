// lib/src/widgets/flexo/ink_report_form.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sheet/utils/image_utils.dart';
import 'package:smart_sheet/services/storage_service.dart'; // ← استيراد خدمة الرفع

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
  // تم تغيير النوع إلى String للتعامل مع المسارات المحلية وروابط URL معاً
  List<String> _imagePaths = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isUploading = false; // ← حالة جديدة لعملية الرفع للسحابة

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

    // تحميل الصور (سواء كانت روابط URL أو مسارات ملفات)
    if (data.containsKey('imagePaths') && data['imagePaths'] is List) {
      _imagePaths = List<String>.from(data['imagePaths']);
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
      final imagePath = await saveImagePermanently(File(image.path));

      setState(() {
        _imagePaths.add(imagePath);
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
      _imagePaths.removeAt(index);
    });
  }

  // دالة مساعدة لعرض الصور سواء كانت محليا أو من الإنترنت
  Widget _buildImageWidget(String path) {
    if (path.startsWith('http')) {
      return Image.network(path, width: 80, height: 80, fit: BoxFit.cover);
    } else {
      return Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover);
    }
  }

  // دالة مساعدة لمزود الصور (PhotoView)
  ImageProvider _buildImageProvider(String path) {
    if (path.startsWith('http')) {
      return NetworkImage(path);
    } else {
      return FileImage(File(path));
    }
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

  // التعديل الجوهري: رفع الصور للسحابة قبل الحفظ النهائي
  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      // 1. رفع الصور الجديدة للسحابة والحصول على الروابط
      // الدالة في StorageService مبرمجة لتجاهل الروابط التي تبدأ بـ http (المرفوعة مسبقاً)
      List<String> finalCloudUrls = await StorageService.uploadMultipleImages(
        _imagePaths,
        'images', // تأكد أن هذا هو اسم الـ Bucket في Supabase
      );

      // 2. تجميع البيانات مع الروابط الجديدة
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
        'imagePaths': finalCloudUrls, // الحفظ بروابط السحابة
      };

      // 3. استدعاء دالة الحفظ الأصلية (التي تحفظ في Hive)
      widget.onSave(report);

      if (mounted) {
        setState(() => _isUploading = false);
        // التنبيه بالنجاح يتم عادة في الشاشة الأب، لكن للتأكيد:
        debugPrint("Report saved and images uploaded successfully.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("حدث خطأ أثناء رفع الصور: $e")),
        );
      }
    }
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
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
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
                            labelText: "📅 التاريخ",
                            border: OutlineInputBorder()),
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
                            labelText: "📦 الصنف",
                            border: OutlineInputBorder()),
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
                      // ✅ قسم الكاميرا والصور المعروضة
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
                            if (_imagePaths.isNotEmpty)
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _imagePaths.length,
                                  itemBuilder: (context, i) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0),
                                    child: Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                          GestureDetector(
                                            onTap: () =>
                                                _showFullScreenImage(i),
                                            child: _buildImageWidget(
                                                _imagePaths[i]),
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
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
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
                            labelText: "📝 ملاحظات",
                            border: OutlineInputBorder()),
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
                                  onPressed: _isUploading ? null : _saveReport,
                                  child: _isUploading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Text("💾 حفظ التقرير"))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // غطاء شفاف يظهر أثناء الرفع لمنع أي إدخالات أخرى
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("جاري رفع الصور ومزامنة البيانات..."),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            controller: PageController(initialPage: index),
            itemCount: _imagePaths.length,
            itemBuilder: (context, i) => Center(
                child: PhotoView(
              imageProvider: _buildImageProvider(_imagePaths[i]),
            )),
          ),
          IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
