import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/utils/ui_utils.dart';

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
      clientController.text = widget.initialData!['clientName']?.toString() ?? '';
      productController.text = widget.initialData!['productName']?.toString() ?? widget.initialData!['product']?.toString() ?? '';
      productCodeController.text = widget.initialData!['productCode']?.toString() ?? '';
      orderNumberController.text = widget.initialData!['orderNumber']?.toString() ?? '';
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Handle
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
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
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
                    valueListenable: Hive.box<FlexoMachine>('flexo_machines')
                        .listenable(),
                    builder: (context, Box<FlexoMachine> box, _) {
                      final machines = box.values.toList();
                      return DropdownButtonFormField<String>(
                        initialValue: selectedMachine,
                        decoration: const InputDecoration(
                            labelText: 'اختر الماكينة',
                            border: OutlineInputBorder()),
                        items: [
                          ...machines.map((m) => DropdownMenuItem(
                              value: m.name, child: Text(m.name))),
                          const DropdownMenuItem(
                              value: 'MANUAL', child: Text('➕ إضافة يدوي')),
                        ],
                        onChanged: (val) async {
                          if (val == 'MANUAL') {
                            final name = await _showSimplePrompt(
                                'اسم الماكينة الجديدة');
                            if (name != null && name.isNotEmpty) {
                              box.add(FlexoMachine(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  name: name));
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
                  _buildSimpleField(
                      clientController, 'اسم العميل', Icons.person),
                  const SizedBox(height: 12),
                  _buildSimpleField(
                      productController, 'الصنف', Icons.inventory),
                  const SizedBox(height: 12),
                  _buildSimpleField(
                      productCodeController, 'كود الصنف', Icons.qr_code,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _buildSimpleField(orderNumberController, 'رقم أمر التشغيل',
                      Icons.numbers,
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
                    onPressed: () {
                      if (selectedMachine == null ||
                          clientController.text.isEmpty) {
                        UIUtils.showInfoSnackBar(
                            message: 'يرجى ملء البيانات الأساسية',
                            backgroundColor: Colors.orange);
                        return;
                      }

                      final newSession = LiveSession(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        machineName: selectedMachine!,
                        clientName: clientController.text,
                        productName: productController.text,
                        productCode: productCodeController.text,
                        orderNumber: orderNumberController.text,
                        technicianName: techController.text,
                        startTime: DateTime.now(),
                        downtimeIntervals: [],
                        lastStateChange: DateTime.now(),
                        isRunning: true,
                        dimensions: widget.initialData?['dimensions'],
                        isSheet: widget.initialData?['isSheet'],
                        imagePaths: widget.initialData?['imagePaths'] != null
                            ? List<String>.from(widget.initialData!['imagePaths'])
                            : null,
                      );

                      Hive.box<LiveSession>('live_sessions').add(newSession);
                      Navigator.pop(context, true);
                    },
                    child: const Text('✅ ابدأ الجلسة الآن'),
                  ),
                ],
              ),
            ),
          ),
        ],
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
            // Force unfocus to dismiss the suggestions overlay and keyboard immediately
            FocusScope.of(context).unfocus();
          },
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            if (textController.text.isEmpty && controller.text.isNotEmpty) {
              textController.text = controller.text;
            }
            textController.addListener(() => controller.text = textController.text);
            return _buildSimpleField(textController, 'الفني (رئيسي)', Icons.engineering, focusNode: focusNode);
          },
        );
      },
    );
  }

  Widget _buildSimpleField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, FocusNode? focusNode}) {
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
    final c = TextEditingController();
    String? result;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: c,
              autofocus: true,
              onSubmitted: (val) {
                result = val;
                Navigator.pop(context);
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'الاسم',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () {
                    result = c.text;
                    Navigator.pop(context);
                  },
                  child: const Text('إضافة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result;
  }
}
