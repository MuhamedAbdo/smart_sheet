// lib/widgets/start_session_dialog.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/services/sync_service.dart'; // استيراد خدمة المزامنة
import 'package:smart_sheet/services/supabase_manager.dart'; // استيراد مدير سوبابيز
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/utils/device_manager.dart'; // استيراد DeviceManager
import 'package:uuid/uuid.dart'; // استيراد مكتبة الـ UUID

class StartSessionDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const StartSessionDialog({super.key, this.initialData});

  @override
  State<StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends State<StartSessionDialog> {
  final clientController = TextEditingController();
  final productController = TextEditingController();
  final productCodeController = TextEditingController();
  final orderNumberController = TextEditingController();
  final techController = TextEditingController();
  String? selectedMachine;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      clientController.text =
          widget.initialData!['clientName']?.toString() ?? '';
      productController.text = widget.initialData!['productName']?.toString() ??
          widget.initialData!['product']?.toString() ??
          '';
      productCodeController.text =
          widget.initialData!['productCode']?.toString() ?? '';
      orderNumberController.text =
          widget.initialData!['orderNumber']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    clientController.dispose();
    productController.dispose();
    productCodeController.dispose();
    orderNumberController.dispose();
    techController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🚀 بدء أوردر جديد (جلسة حية)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Divider(),
            const SizedBox(height: 10),
            ValueListenableBuilder(
              valueListenable:
                  Hive.box<FlexoMachine>('flexo_machines').listenable(),
              builder: (context, Box<FlexoMachine> box, _) {
                final machines = box.values.toList();
                return DropdownButtonFormField<String>(
                  initialValue: selectedMachine,
                  decoration: const InputDecoration(
                      labelText: 'اختر الماكينة', border: OutlineInputBorder()),
                  items: [
                    ...machines.map((m) =>
                        DropdownMenuItem(value: m.name, child: Text(m.name))),
                    const DropdownMenuItem(
                        value: 'MANUAL', child: Text('➕ إضافة يدوي')),
                  ],
                  onChanged: (val) async {
                    if (val == 'MANUAL') {
                      final name =
                          await _showSimplePrompt('اسم الماكينة الجديدة');
                      if (name != null && name.isNotEmpty) {
                        box.add(
                            FlexoMachine(id: const Uuid().v4(), name: name));
                        setState(() => selectedMachine = name);
                      }
                    } else {
                      setState(() => selectedMachine = val);
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            _buildSimpleField(clientController, 'اسم العميل', Icons.person),
            const SizedBox(height: 12),
            _buildSimpleField(productController, 'الصنف', Icons.inventory),
            const SizedBox(height: 12),
            _buildSimpleField(productCodeController, 'كود الصنف', Icons.qr_code,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _buildSimpleField(
                orderNumberController, 'رقم أمر التشغيل', Icons.numbers,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _buildWorkerSuggestField(techController),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (selectedMachine == null || clientController.text.isEmpty) {
                  UIUtils.showInfoSnackBar(
                      message: 'يرجى ملء البيانات الأساسية',
                      backgroundColor: Colors.orange);
                  return;
                }

                // 1. توليد ID فريد للمزامنة
                final sessionId = const Uuid().v4();
                final fId = await SupabaseManager.getFactoryId();
                final deviceId = await DeviceManager.getDeviceId();

                // 2. إنشاء كائن الجلسة الحية
                final session = LiveSession(
                  id: sessionId,
                  machineName: selectedMachine!,
                  clientName: clientController.text.trim(),
                  productName: productController.text.trim(),
                  productCode: productCodeController.text.trim(),
                  orderNumber: orderNumberController.text.trim(),
                  technicianName: techController.text.trim(),
                  startTime: DateTime.now(),
                  downtimeIntervals: [],
                  lastStateChange: DateTime.now(),
                  dimensions: widget.initialData?['dimensions'],
                  isSheet: widget.initialData?['isSheet'] ?? false,
                  imagePaths: List<String>.from(
                      widget.initialData?['imagePaths'] ?? []),
                  factoryId: fId, // استخدام معرف المصنع الحقيقي
                  createdByDeviceId: deviceId,
                );

                // 3. الحفظ المحلي في Hive (لتحديث الواجهة فوراً)
                final liveBox = Hive.box<LiveSession>('flexo_live_sessions');
                await liveBox.put(sessionId, session);

                // 4. الإرسال لقائمة المزامنة (ليرسل للسحابة والديسك توب)
                await SyncService.instance.pushToQueue(
                  'live_sessions',
                  session.toJson(),
                  operation: 'upsert',
                );

                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('ابدأ التشغيل الآن ⚡'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerSuggestField(TextEditingController controller) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Worker>('workers_flexo').listenable(),
      builder: (context, Box<Worker> box, _) {
        final workerNames = box.values.map((w) => w.name).toList();
        return Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') {
              return workerNames;
            }
            return workerNames.where((String option) {
              return option.contains(textEditingValue.text);
            });
          },
          onSelected: (String selection) {
            controller.text = selection;
            FocusScope.of(context).unfocus();
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
            if (textController.text.isEmpty && controller.text.isNotEmpty) {
              textController.text = controller.text;
            }
            textController
                .addListener(() => controller.text = textController.text);
            return _buildSimpleField(
                textController, 'الفني (رئيسي)', Icons.engineering,
                focusNode: focusNode);
          },
        );
      },
    );
  }

  Widget _buildSimpleField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType, FocusNode? focusNode}) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<String?> _showSimplePrompt(String title) async {
    String? result;
    await showDialog(
      context: context,
      builder: (context) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: c, autofocus: true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            TextButton(
              onPressed: () {
                result = c.text;
                Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
    return result;
  }
}
