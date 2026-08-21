import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/screens/job_order_dialog.dart';

class SelectClientDialog extends StatefulWidget {
  const SelectClientDialog({super.key});

  @override
  State<SelectClientDialog> createState() => _SelectClientDialogState();
}

class _SelectClientDialogState extends State<SelectClientDialog> {
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final box = await Hive.openBox('savedSheetSizes');
    final Map<String, List<Map>> clientRecords = {};
    
    // تجميع السجلات حسب اسم العميل
    for (var val in box.values) {
      if (val is Map) {
        final cName = val['clientName']?.toString().trim() ?? '';
        if (cName.isNotEmpty) {
          if (!clientRecords.containsKey(cName)) {
            clientRecords[cName] = [];
          }
          clientRecords[cName]!.add(val);
        }
      }
    }

    final List<Map<String, dynamic>> clientsData = [];
    
    for (var entry in clientRecords.entries) {
      final cName = entry.key;
      final records = entry.value;
      
      // استخراج الأصناف فقط (تجاهل سجل العميل الرئيسي)
      final rawItems = records.where((e) => e['isClientRecord'] != true);
      
      // تصفية الأصناف المكررة
      final Set<String> uniqueProductCodes = {};
      int itemCount = 0;
      
      for (var item in rawItems) {
        final productCode = item['productCode']?.toString().trim() ?? '';
        final uniqueId = productCode.isNotEmpty
            ? productCode
            : (item['sync_id'] ?? item['id'] ?? item.hashCode).toString();
            
        if (!uniqueProductCodes.contains(uniqueId)) {
          uniqueProductCodes.add(uniqueId);
          itemCount++;
        }
      }
      
      clientsData.add({
        'name': cName,
        'itemCount': itemCount,
      });
    }

    // ترتيب العملاء أبجدياً
    clientsData.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

    setState(() {
      _clients = clientsData;
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('اختر عميلاً', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _clients.isEmpty
                  ? const Center(child: Text('لا يوجد عملاء مسجلين'))
                  : Column(
                      children: [
                        // شريط إجمالي العملاء
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1a3a6e),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                '${_clients.length} عميل مسجل',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // قائمة العملاء
                        Expanded(
                          child: ListView.builder(
                            itemCount: _clients.length,
                            itemBuilder: (ctx, i) {
                              final client = _clients[i];
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _onClientSelected(client['name']),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: Color(0xFF1a3a6e),
                                          child: Icon(Icons.person, color: Colors.white),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                client['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${client['itemCount']} صنف مسجل',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_back_ios,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }
}
