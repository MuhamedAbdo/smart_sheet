import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sheet/utils/image_utils.dart';
import 'package:smart_sheet/services/storage_service.dart'; // تأكد من وجود خدمة الرفع لديك

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
  List<String> _imagePaths = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isUploading = false;

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

    if (data['imagePaths'] is List) {
      _imagePaths = List<String>.from(data['imagePaths']);
    }
  }

  Future<void> _initializeCamera() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final prefs = await SharedPreferences.getInstance();
      final String quality = prefs.getString('camera_quality') ?? 'medium';

      ResolutionPreset preset = switch (quality) {
        'low' => ResolutionPreset.low,
        'high' => ResolutionPreset.high,
        _ => ResolutionPreset.medium,
      };

      _cameraController =
          CameraController(backCamera, preset, enableAudio: false);
      await _cameraController!.initialize();

      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _captureImage() async {
    if (!_isCameraReady ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) return;

    setState(() => _isProcessing = true);
    try {
      final XFile image = await _cameraController!.takePicture();
      // حفظ محلي مؤقت لضمان عدم ضياع الصورة قبل الرفع
      final savedPath = await saveImagePermanently(File(image.path));
      setState(() {
        _imagePaths.add(savedPath);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar("فشل التقاط الصورة: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      // 1. مزامنة الصور مع السحابة (يرفع الملفات المحلية ويتجاهل الروابط الموجودة مسبقاً)
      List<String> finalUrls = await StorageService.uploadMultipleImages(
        _imagePaths,
        'ink_reports',
      );

      // 2. بناء الكائن النهائي
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
        'imagePaths': finalUrls,
      };

      widget.onSave(report);
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء المزامنة: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
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

  // أدوات المساعدة للعرض (UI Helpers)
  Widget _buildImageProviderWidget(String path) {
    bool isNetwork = path.startsWith('http');
    return isNetwork
        ? Image.network(path,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
        : Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover);
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
                    _buildCameraSection(),
                    const SizedBox(height: 20),
                    _buildColorsSection(),
                    const SizedBox(height: 12),
                    _buildTextField(quantityController, "🔢 عدد الشيتات",
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _buildTextField(notesController, "📝 ملاحظات", maxLines: 3),
                    const SizedBox(height: 30),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
          if (_isUploading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // مكونات الواجهة الصغيرة (Sub-Widgets)
  Widget _buildCameraSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("📸 صور العينة",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_isCameraReady && _cameraController != null)
          Container(
            height: 180,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12), color: Colors.black12),
            clipBehavior: Clip.antiAlias,
            child: CameraPreview(_cameraController!),
          ),
        IconButton(
          onPressed: _isProcessing ? null : _captureImage,
          icon: _isProcessing
              ? const CircularProgressIndicator()
              : const Icon(Icons.camera_alt, size: 30),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _imagePaths.length,
            itemBuilder: (context, i) => _buildThumbnail(i),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(int i) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Stack(
        children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImageProviderWidget(_imagePaths[i])),
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: () => setState(() => _imagePaths.removeAt(i)),
              child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.close, size: 12, color: Colors.white)),
            ),
          ),
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

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 15),
              Text("جاري مزامنة البيانات والحرص على جودتها...")
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool readOnly = false,
      VoidCallback? onTap,
      TextInputType? keyboardType,
      int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (v) => v == null || v.isEmpty ? "مطلوب" : null,
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
