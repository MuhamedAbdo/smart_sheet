import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/maintenance_record_model.dart';
import '../../services/storage_service.dart';
import '../../utils/ui_utils.dart';
import 'package:smart_sheet/widgets/desktop_image_picker.dart';

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
  List<String> _imagePaths = [];
  bool _isUploading = false;
  bool _isProcessing = false;



  @override
  void initState() {
    super.initState();
    _initializeControllers();

  }

  @override
  void dispose() {

    _disposeControllers();
    super.dispose();
  }

  void _initializeControllers() {
    final e = widget.existing;
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

  void _disposeControllers() {
    issueDateController.dispose();
    machineController.dispose();
    issueDescController.dispose();
    reportDateController.dispose();
    reportedToTechnicianController.dispose();
    actionController.dispose();
    actionDateController.dispose();
    repairedByController.dispose();
    notesController.dispose();
  }

  String _today() => DateTime.now().toString().split(' ')[0];

  Future<void> _pickImages() async {
    setState(() => _isProcessing = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final imageDir = Directory('${appDir.path}/images');
        if (!await imageDir.exists()) {
          await imageDir.create(recursive: true);
        }

        for (var file in result.files) {
          if (file.path != null) {
            final String fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            final targetPath = '${imageDir.path}/$fileName';
            final savedFile = await File(file.path!).copy(targetPath);
            setState(() => _imagePaths.add(savedFile.path));
          }
        }
      }
    } catch (e) {
      debugPrint("Error picking files: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveRecord() async {
    if (machineController.text.trim().isEmpty) {
      UIUtils.showInfoSnackBar(
        message: "يرجى إدخال اسم الماكينة",
        backgroundColor: Colors.orange,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // تم التعديل هنا لاستخدام الـ Bucket الموجود في حسابك وهو 'images'
      List<String> finalCloudUrls = await StorageService.uploadMultipleImages(
        _imagePaths,
        'images',
      );

      final record = MaintenanceRecord(
        id: widget.existing?.id,
        machine: machineController.text.trim(),
        isFixed: isFixed,
        issueDate: issueDateController.text,
        reportDate: reportDateController.text,
        actionDate: actionDateController.text,
        issueDescription: issueDescController.text.trim(),
        actionTaken: actionController.text.trim(),
        repairLocation: repairLocation,
        repairedBy: repairedByController.text.trim(),
        reportedToTechnician: reportedToTechnicianController.text.trim(),
        notes:
            notesController.text.isEmpty ? null : notesController.text.trim(),
        imagePaths: finalCloudUrls,
      );

      widget.onSave(record);
    } catch (e) {
      UIUtils.showInfoSnackBar(
        message: "حدث خطأ أثناء الحفظ",
        backgroundColor: Colors.redAccent,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.existing == null
                                  ? "🆕 إضافة سجل صيانة"
                                  : "✏️ تعديل السجل",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 10),
                        _buildTextField(
                            machineController, "اسم الماكينة", Icons.settings),
                        const SizedBox(height: 12),
                        _buildDateField(
                            issueDateController, "تاريخ ظهور العطل"),
                        const SizedBox(height: 12),
                        _buildTextField(issueDescController, "وصف العطل",
                            Icons.warning_amber,
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
                        _buildTextField(repairedByController,
                            "تم الإصلاح بواسطة", Icons.engineering),
                        const SizedBox(height: 12),
                        _buildLocationDropdown(),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isFixed
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CheckboxListTile(
                            title: const Text("تم الإصلاح بالكامل؟"),
                            value: isFixed,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onChanged: (v) =>
                                setState(() => isFixed = v ?? false),
                          ),
                        ),
                        const SizedBox(height: 20),
                        DesktopImagePicker(
                          isProcessing: _isProcessing,
                          capturedImages: _imagePaths
                              .map((p) => p.startsWith('http') ? p : File(p))
                              .toList(),
                          onPickImages: _pickImages,
                          onRemoveImage: (index) =>
                              setState(() => _imagePaths.removeAt(index)),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("إلغاء"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: _saveRecord,
                                child: const Text("حفظ السجل"),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isUploading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

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
                Text("جاري حفظ البيانات ورفع الصور..."),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
