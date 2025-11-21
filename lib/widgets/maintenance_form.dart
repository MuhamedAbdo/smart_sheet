// lib/src/widgets/maintenance/maintenance_form.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:permission_handler/permission_handler.dart'; // ✅ أضف هذا

class MaintenanceForm extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final void Function(Map<String, dynamic>) onSave;

  const MaintenanceForm({
    super.key,
    this.existingData,
    required this.onSave,
  });

  @override
  State<MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends State<MaintenanceForm> {
  late TextEditingController issueDateController;
  late TextEditingController machineController;
  late TextEditingController issueDescController;
  late TextEditingController reportDateController;
  late TextEditingController reportedToTechnicianController;
  late TextEditingController actionController;
  late TextEditingController actionDateController;
  late TextEditingController repairedByController;
  late TextEditingController notesController;

  bool isFixed = false;
  String repairLocation = 'في المصنع';

  final ImagePicker _imagePicker = ImagePicker();
  List<File> _capturedImages = [];
  bool _isProcessing = false;

  // ✅ إضافة نفس حقول الكاميرا مثل ink_report_form
  CameraController? _cameraController;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeCamera(); // ✅ نفس دالة ink_report_form
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    issueDateController.dispose();
    machineController.dispose();
    issueDescController.dispose();
    reportDateController.dispose();
    reportedToTechnicianController.dispose();
    actionController.dispose();
    actionDateController.dispose();
    repairedByController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    issueDateController =
        TextEditingController(text: widget.existingData?['issueDate'] ?? '');
    machineController =
        TextEditingController(text: widget.existingData?['machine'] ?? '');
    issueDescController = TextEditingController(
        text: widget.existingData?['issueDescription'] ?? '');
    reportDateController =
        TextEditingController(text: widget.existingData?['reportDate'] ?? '');
    reportedToTechnicianController = TextEditingController(
        text: widget.existingData?['reportedToTechnician'] ?? '');
    actionController =
        TextEditingController(text: widget.existingData?['actionTaken'] ?? '');
    actionDateController =
        TextEditingController(text: widget.existingData?['actionDate'] ?? '');
    repairedByController =
        TextEditingController(text: widget.existingData?['repairedBy'] ?? '');
    notesController =
        TextEditingController(text: widget.existingData?['notes'] ?? '');

    isFixed = widget.existingData?['isFixed'] ?? false;
    repairLocation = widget.existingData?['repairLocation'] ?? 'في المصنع';

    final existingImagePaths = widget.existingData?['imagePaths'] as List?;
    _capturedImages = existingImagePaths
            ?.map((path) => File(path.toString()))
            .where((file) => file.existsSync())
            .toList() ??
        [];
  }

  // ✅ نفس دالة ink_report_form بالضبط
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

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium, // ✅ نفس الإعدادات
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  // ✅ نفس دالة ink_report_form بالضبط
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ تم حفظ الصورة بنجاح"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل في التقاط الصورة: $e")),
        );
      }
    }
  }

  // ✅ دالة اختيار صورة من المعرض
  Future<void> _pickImageFromGallery() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final String newPath =
            '${directory.path}/maintenance_gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final File savedImage = await File(pickedFile.path).copy(newPath);

        if (mounted) {
          setState(() {
            _capturedImages.add(savedImage);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ تم إضافة الصورة من المعرض"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error in gallery pick: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ فشل في اختيار الصورة: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _removeImage(int index) {
    if (index >= 0 && index < _capturedImages.length) {
      setState(() {
        _capturedImages.removeAt(index);
      });
    }
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.tryParse(controller.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = "${picked.year}-${picked.month}-${picked.day}";
    }
  }

  void _saveRecord() {
    final record = {
      'issueDate': issueDateController.text,
      'machine': machineController.text,
      'issueDescription': issueDescController.text,
      'reportDate': reportDateController.text,
      'reportedToTechnician': reportedToTechnicianController.text,
      'actionTaken': actionController.text,
      'actionDate': actionDateController.text,
      'isFixed': isFixed,
      'repairLocation': repairLocation,
      'repairedBy': repairedByController.text,
      'notes': notesController.text,
      'imagePaths': _capturedImages.map((file) => file.path).toList(),
    };

    widget.onSave(record);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingData == null
                    ? "➕ إضافة سجل صيانة"
                    : "✏️ تعديل سجل صيانة",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // ✅ الحقول النصية
              TextField(
                controller: issueDateController,
                readOnly: true,
                onTap: () => _selectDate(context, issueDateController),
                decoration: const InputDecoration(
                    labelText: "📅 تاريخ ظهور العطل",
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: machineController,
                decoration: const InputDecoration(
                    labelText: "🏭 اسم الماكينة", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: issueDescController,
                decoration: const InputDecoration(
                    labelText: "⚠️ وصف العطل", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reportDateController,
                readOnly: true,
                onTap: () => _selectDate(context, reportDateController),
                decoration: const InputDecoration(
                    labelText: "🗓️ تاريخ التبليغ",
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reportedToTechnicianController,
                decoration: const InputDecoration(
                    labelText: "👷‍♂️ تم التبليغ إلى",
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: actionController,
                decoration: const InputDecoration(
                    labelText: "🔧 الإجراء المتخذ",
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: actionDateController,
                readOnly: true,
                onTap: () => _selectDate(context, actionDateController),
                decoration: const InputDecoration(
                    labelText: "📆 تاريخ التنفيذ",
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              Row(children: [
                const Text("✅ تم الإصلاح؟"),
                Checkbox(
                  value: isFixed,
                  onChanged: (v) => setState(() => isFixed = v ?? false),
                ),
              ]),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: repairLocation,
                items: const [
                  DropdownMenuItem(
                      value: 'في المصنع', child: Text('في المصنع')),
                  DropdownMenuItem(
                      value: 'ورشة خارجية', child: Text('ورشة خارجية')),
                ],
                onChanged: (v) =>
                    setState(() => repairLocation = v ?? 'في المصنع'),
                decoration: const InputDecoration(
                    labelText: "🏠 مكان الإصلاح", border: OutlineInputBorder()),
              ),

              const SizedBox(height: 12),
              TextField(
                controller: repairedByController,
                decoration: const InputDecoration(
                    labelText: "🛠 تم الإصلاح بواسطة",
                    border: OutlineInputBorder()),
              ),

              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: "📝 ملاحظات", border: OutlineInputBorder()),
              ),

              const SizedBox(height: 20),

              // --- قسم الصور - بنفس طريقة ink_report_form ---
              if (_isCameraReady && _cameraController != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("📸 الصور",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: CameraPreview(_cameraController!),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _captureImage,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.camera_alt),
                            label: const Text("التقط صورة"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isProcessing ? null : _pickImageFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text("المعرض"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_capturedImages.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text("الصور الملتقطة:",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _capturedImages.length,
                          itemBuilder: (context, index) => Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                GestureDetector(
                                  onTap: () => _showFullScreenImage(
                                      context, _capturedImages, index),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _capturedImages[index],
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.error,
                                                color: Colors.red),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 12, color: Colors.white),
                                    onPressed: () => _removeImage(index),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "عدد الصور: ${_capturedImages.length}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                )
              else if (!_isCameraReady)
                const Column(
                  children: [
                    SizedBox(height: 16),
                    Text("جاري تحميل الكاميرا..."),
                    SizedBox(height: 8),
                    CircularProgressIndicator(),
                  ],
                ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("❌ إلغاء"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _saveRecord,
                      child: const Text("💾 حفظ السجل"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(
      BuildContext context, List<File> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('الصورة (${initialIndex + 1} من ${images.length})'),
            centerTitle: true,
          ),
          body: PhotoView(
            imageProvider: FileImage(images[initialIndex]),
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2.5,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorBuilder: (context, error, stackTrace) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 50, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text("تعذر تحميل الصورة"),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("العودة"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
