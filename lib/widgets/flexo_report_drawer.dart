import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/utils/pdf_export_helper.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class FlexoReportDrawer extends StatelessWidget {
  const FlexoReportDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text(
                    "تقارير ماكينات الفلكسو",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<FlexoMachine>('flexo_machines').listenable(),
              builder: (context, Box<FlexoMachine> machineBox, _) {
                final machines = machineBox.values.toList();
                
                if (machines.isEmpty) {
                  return const Center(child: Text("لا توجد ماكينات مسجلة"));
                }
                
                return ListView.builder(
                  itemCount: machines.length,
                  itemBuilder: (context, index) {
                    final machine = machines[index];
                    final mName = machine.name;
                    
                    return ExpansionTile(
                      leading: const Icon(Icons.settings),
                      title: Text(mName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      children: [
                        _buildReportTile(
                          context,
                          label: "عرض تقرير الإنتاج",
                          icon: Icons.picture_as_pdf,
                          onTap: () => _handlePdfAction(context, mName, isPrinting: false, isSave: false),
                        ),
                        _buildReportTile(
                          context,
                          label: "حفظ تقرير إنتاج",
                          icon: Icons.save_alt,
                          onTap: () => _handlePdfAction(context, mName, isPrinting: false, isSave: true),
                        ),
                        _buildReportTile(
                          context,
                          label: "عرض تقرير طباعة",
                          icon: Icons.picture_as_pdf,
                          color: Colors.blueAccent,
                          onTap: () => _handlePdfAction(context, mName, isPrinting: true, isSave: false),
                        ),
                        _buildReportTile(
                          context,
                          label: "حفظ تقرير طباعة",
                          icon: Icons.save_alt,
                          color: Colors.blueAccent,
                          onTap: () => _handlePdfAction(context, mName, isPrinting: true, isSave: true),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTile(BuildContext context, {required String label, required IconData icon, required VoidCallback onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.blue, size: 18),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _handlePdfAction(BuildContext context, String machineName, {required bool isPrinting, required bool isSave}) async {
    final box = await Hive.openBox('inkReports');
    final records = box.values
        .where((r) {
          final map = Map<String, dynamic>.from(r);
          final m = (map['machineName'] ?? map['machine_name'])?.toString() ?? '';
          return m.trim() == machineName.trim();
        })
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (records.isEmpty) {
      UIUtils.showInfoSnackBar(message: "لا توجد تقارير لهذه الماكينة", backgroundColor: Colors.orange);
      return;
    }

    final title = isPrinting ? "تقرير طباعة ماكينة: $machineName" : "تقرير إنتاج ماكينة: $machineName";

    if (isSave) {
      final Uint8List? pdfBytes = isPrinting
          ? await generatePrintingReportPdfBytes({'records': records, 'title': title})
          : await generateProductionReportPdfBytes({'records': records, 'title': title});
      
      if (pdfBytes == null) return;

      await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ PDF',
        fileName: '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );
    } else {
      if (!context.mounted) return;
      if (isPrinting) {
        await exportPrintingReportsToPdf(context, records, title: title);
      } else {
        await exportProductionReportsToPdf(context, records, title: title);
      }
    }
  }
}
