import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/screens/job_order_dialog.dart';

class SelectClientDialog extends StatefulWidget {
  const SelectClientDialog({super.key});

  @override
  State<SelectClientDialog> createState() => _SelectClientDialogState();
}

class _SelectClientDialogState extends State<SelectClientDialog> {
  List<String> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final box = await Hive.openBox('savedSheetSizes');
    final Set<String> uniqueClients = {};
    for (var val in box.values) {
      if (val is Map) {
        final cName = val['clientName']?.toString().trim() ?? '';
        if (cName.isNotEmpty) {
          uniqueClients.add(cName);
        }
      }
    }
    setState(() {
      _clients = uniqueClients.toList()..sort();
      _isLoading = false;
    });
  }

  void _onClientSelected(String clientName) async {
    Navigator.of(context).pop(); // إغلاق نافذة الاختيار
    final box = await Hive.openBox('savedSheetSizes');
    
    // جلب بيانات العميل والأصناف
    final allClientRecords = box.values
        .where((e) => e is Map && (e['clientName']?.toString().trim() ?? '') == clientName)
        .toList();
        
    final rawItems = allClientRecords
        .where((e) => e is Map && e['isClientRecord'] != true);
    
    final Map<String, Map<String, dynamic>> uniqueItemsMap = {};
    for (var entry in rawItems) {
      final val = Map<String, dynamic>.from(entry as Map);
      final productCode = val['productCode']?.toString().trim() ?? '';
      final uniqueId = productCode.isNotEmpty
          ? productCode
          : (val['sync_id'] ?? val['id'] ?? val.hashCode).toString();
      uniqueItemsMap[uniqueId] = val;
    }
    
    final items = uniqueItemsMap.values.toList();
    items.sort((a, b) {
      final codeA = int.tryParse(a['productCode']?.toString() ?? '') ?? 0;
      final codeB = int.tryParse(b['productCode']?.toString() ?? '') ?? 0;
      return codeA.compareTo(codeB);
    });

    String clientAddress = '';
    String clientSupervisor = '';
    String clientPhone = '';
    String clientCode = '';

    try {
      final clientRecord = allClientRecords.firstWhere(
        (e) => e is Map && e['isClientRecord'] == true,
      );
      final data = clientRecord as Map;
      clientAddress = data['address']?.toString() ?? '';
      clientSupervisor = data['supervisor']?.toString() ?? '';
      clientPhone = data['phone']?.toString() ?? '';
      clientCode = data['productCode']?.toString() ?? data['clientCode']?.toString() ?? '';
    } catch (_) {}

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => JobOrderDialog(
          clientName: clientName,
          clientCode: clientCode,
          clientAddress: clientAddress,
          clientSupervisor: clientSupervisor,
          clientPhone: clientPhone,
          clientItems: items,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختر عميلاً', textDirection: TextDirection.rtl),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _clients.isEmpty
                ? const Center(child: Text('لا يوجد عملاء مسجلين', textDirection: TextDirection.rtl))
                : ListView.builder(
                    itemCount: _clients.length,
                    itemBuilder: (ctx, i) {
                      return ListTile(
                        leading: const Icon(Icons.person, color: Color(0xFF1a3a6e)),
                        title: Text(_clients[i], textDirection: TextDirection.rtl),
                        onTap: () => _onClientSelected(_clients[i]),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
