// lib/src/widgets/maintenance/maintenance_form.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/maintenance_record_model.dart';
import '../../services/storage_service.dart';

class MaintenanceForm extends StatefulWidget {
  final MaintenanceRecord? existing;
  final Function(MaintenanceRecord record) onSave;

  const MaintenanceForm({
    super.key,
    this.existing,
    required this.onSave,
  });

  @override
  State<MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends State<MaintenanceForm> {
  // المتحكمات (Controllers) لجميع الحقول المطلوبة
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

  // إدارة الصور والكاميرا
  List<String> _imagePaths = [];
  bool _isUploading = false;
  bool _isProcessing = false;

  CameraController? _cameraController;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeCamera();
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
    final e = widget.existing;

    // تهيئة الحقول بالبيانات الموجودة (في حالة التعديل) أو بقيم فارغة
    issueDateController = TextEditingController(text: e?.issueDate ?? _today());
    machineController = TextEditingController(text: e?.machine ?? '');
    issueDescController =
        TextEditingController(text: e?.issueDescription ?? '');
    reportDateController =
        TextEditingController(text: e?.reportDate ?? _today());
    reportedToTechnicianController =
        TextEditingController(text: e?.reportedToTechnician ?? '');
    actionController = TextEditingController(text: e?.actionTaken ?? '');
    actionDateController =
        TextEditingController(text: e?.actionDate ?? _today());
    repairedByController = TextEditingController(text: e?.repairedBy ?? '');
    notesController = TextEditingController(text: e?.notes ?? '');

    isFixed = e?.isFixed ?? false;
    repairLocation = e?.repairLocation ?? 'في المصنع';

    if (e?.imagePaths != null) {
      _imagePaths = List<String>.from(e!.imagePaths);
    }
  }

  String _today() => DateTime.now().toString().split(' ')[0];

  Future<void> _initializeCamera() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _captureImage() async {
    if (!_isCameraReady || _cameraController == null) return;
    setState(() => _isProcessing = true);
    try {
      final XFile photo = await _cameraController!.takePicture();
      setState(() {
        _imagePaths.add(photo.path);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  // --- دالة الحفظ والرفع السحابي ---
  Future<void> _saveRecord() async {
    if (machineController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("يرجى إدخال اسم الماكينة")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. الرفع إلى Bucket 'images' (يتولى StorageService الضغط والرفع)
      List<String> finalCloudUrls = await StorageService.uploadMultipleImages(
        _imagePaths,
        'images',
      );

      // 2. إنشاء السجل بكافة الحقول المطلوبة (Required)
      final record = MaintenanceRecord(
        machine: machineController.text,
        isFixed: isFixed,
        issueDate: issueDateController.text,
        reportDate: reportDateController.text,
        actionDate: actionDateController.text,
        issueDescription: issueDescController.text,
        actionTaken: actionController.text,
        repairLocation: repairLocation,
        repairedBy: repairedByController.text,
        reportedToTechnician: reportedToTechnicianController.text,
        notes: notesController.text.isEmpty ? null : notesController.text,
        imagePaths: finalCloudUrls,
      );

      widget.onSave(record);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("خطأ في الرفع: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Text(
                  widget.existing == null ? "إضافة سجل صيانة" : "تعديل السجل"),
              actions: [
                if (!_isUploading)
                  IconButton(
                      onPressed: _saveRecord, icon: const Icon(Icons.check))
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTextField(
                      machineController, "اسم الماكينة", Icons.settings),
                  const SizedBox(height: 12),
                  _buildDateField(issueDateController, "تاريخ ظهور العطل"),
                  const SizedBox(height: 12),
                  _buildTextField(
                      issueDescController, "وصف العطل", Icons.warning_amber,
                      maxLines: 2),
                  const SizedBox(height: 12),
                  _buildDateField(reportDateController, "تاريخ التبليغ"),
                  const SizedBox(height: 12),
                  _buildTextField(reportedToTechnicianController,
                      "تم التبليغ إلى", Icons.person),
                  const Divider(height: 32),
                  _buildTextField(
                      actionController, "الإجراء المتخذ", Icons.build),
                  const SizedBox(height: 12),
                  _buildDateField(actionDateController, "تاريخ التنفيذ"),
                  const SizedBox(height: 12),
                  _buildTextField(repairedByController, "تم الإصلاح بواسطة",
                      Icons.engineering),
                  const SizedBox(height: 12),
                  _buildLocationDropdown(),
                  CheckboxListTile(
                    title: const Text("تم الإصلاح بالكامل؟"),
                    value: isFixed,
                    onChanged: (v) => setState(() => isFixed = v ?? false),
                  ),
                  const SizedBox(height: 20),
                  _buildCameraPreview(),
                  _buildImageGallery(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          if (_isUploading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // --- أدوات بناء الواجهة ---

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder()),
    );
  }

  Widget _buildDateField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          border: const OutlineInputBorder()),
      onTap: () async {
        DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100));
        if (picked != null)
          setState(() => controller.text = picked.toString().split(' ')[0]);
      },
    );
  }

  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: repairLocation,
      decoration: const InputDecoration(
          labelText: "مكان الإصلاح", border: OutlineInputBorder()),
      items: ['في المصنع', 'ورشة خارجية']
          .map((l) => DropdownMenuItem(value: l, child: Text(l)))
          .toList(),
      onChanged: (v) => setState(() => repairLocation = v!),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraReady) return const Text("الكاميرا قيد التحضير...");
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
              height: 200,
              width: double.infinity,
              child: CameraPreview(_cameraController!)),
        ),
        IconButton(
            onPressed: _isProcessing ? null : _captureImage,
            icon: const Icon(Icons.camera_alt, size: 40, color: Colors.blue)),
      ],
    );
  }

  Widget _buildImageGallery() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _imagePaths.length,
        itemBuilder: (context, i) {
          final path = _imagePaths[i];
          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _viewFullScreen(path),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: path.startsWith('http')
                        ? Image.network(path,
                            width: 80, height: 80, fit: BoxFit.cover)
                        : Image.file(File(path),
                            width: 80, height: 80, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                    right: 0,
                    child: GestureDetector(
                        onTap: () => setState(() => _imagePaths.removeAt(i)),
                        child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close,
                                size: 12, color: Colors.white)))),
              ],
            ),
          );
        },
      ),
    );
  }

  void _viewFullScreen(String path) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                appBar: AppBar(),
                body: PhotoView(
                    imageProvider: path.startsWith('http')
                        ? NetworkImage(path)
                        : FileImage(File(path)) as ImageProvider))));
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("جاري رفع البيانات والصور للسحابة...")
              ],
            ),
          ),
        ),
      ),
    );
  }
}
