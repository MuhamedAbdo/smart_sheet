import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_sheet/models/die_cutting_form.dart';
import 'package:smart_sheet/services/sync_service.dart';

class DieCuttingFormsScreen extends StatefulWidget {
  const DieCuttingFormsScreen({super.key});

  @override
  State<DieCuttingFormsScreen> createState() => _DieCuttingFormsScreenState();
}

class _DieCuttingFormsScreenState extends State<DieCuttingFormsScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<DieCuttingForm>('die_cutting_forms');

    return Scaffold(
      appBar: AppBar(
        title: const Text("قوالب التكسير"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'ابحث برقم الفورمة أو اسم العميل أو اسم الصنف',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<DieCuttingForm> box, _) {
          if (box.values.isEmpty) {
            return const Center(
              child: Text(
                "لا توجد قوالب تكسير مسجلة",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          var forms = box.values.toList();
          
          if (_searchQuery.isNotEmpty) {
            forms = forms.where((f) {
              final formNum = f.formNumber.toLowerCase();
              final cName = (f.customerName ?? '').toLowerCase();
              final iName = (f.itemName ?? '').toLowerCase();
              return formNum.contains(_searchQuery) || 
                     cName.contains(_searchQuery) || 
                     iName.contains(_searchQuery);
            }).toList();
          }

          if (forms.isEmpty) {
            return const Center(
              child: Text(
                "لا توجد قوالب تطابق البحث",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: forms.length,
            itemBuilder: (context, index) {
              final form = forms[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                child: ListTile(
                  title: Text(
                    "رقم الفورمة: ${form.formNumber}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (form.customerName != null && form.customerName!.isNotEmpty)
                        Text("العميل: ${form.customerName} ${form.customerCode != null ? '(${form.customerCode})' : ''}"),
                      if (form.itemName != null && form.itemName!.isNotEmpty)
                        Text("الصنف: ${form.itemName} ${form.itemCode != null ? '(${form.itemCode})' : ''}"),
                      Text("المقاس: ${form.length} × ${form.width} × ${form.height}"),
                      Text("عدد العلب: ${form.numberOfBoxes.toStringAsFixed(0)}"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (form.isSheet) 
                        const Chip(label: Text('شيت', style: TextStyle(fontSize: 10))),
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        onPressed: () => _viewFormDetails(context, form),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showFormDialog(context, form: form),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, form),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFormDialog(BuildContext context, {DieCuttingForm? form}) {
    showDialog(
      context: context,
      builder: (context) => _DieCuttingFormDialog(form: form),
    );
  }

  void _viewFormDetails(BuildContext context, DieCuttingForm form) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل قالب التكسير: ${form.formNumber}'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              if (form.customerName != null && form.customerName!.isNotEmpty)
                Text("العميل: ${form.customerName} ${form.customerCode != null ? '(${form.customerCode})' : ''}"),
              if (form.itemName != null && form.itemName!.isNotEmpty)
                Text("الصنف: ${form.itemName} ${form.itemCode != null ? '(${form.itemCode})' : ''}"),
              Text("المقاس: ${form.length} × ${form.width} × ${form.height}"),
              Text("مقاس الشيت: ${form.sheetLength} × ${form.sheetWidth}"),
              Text("عدد العلب: ${form.numberOfBoxes.toStringAsFixed(0)}"),
              Text("نوع القالب: ${form.isSheet ? 'شيت' : 'عادي'}"),
              if (form.shelfLocation != null && form.shelfLocation!.isNotEmpty)
                Text("مكان الرف: ${form.shelfLocation}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('إغلاق'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DieCuttingForm form) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف قالب التكسير'),
        content: Text('هل أنت متأكد من حذف القالب رقم ${form.formNumber}؟'),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
            onPressed: () {
              SyncService.instance.pushToQueue('die_cutting_forms', {'id': form.id, 'sync_id': form.id}, operation: 'delete');
              form.delete();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _DieCuttingFormDialog extends StatefulWidget {
  final DieCuttingForm? form;
  const _DieCuttingFormDialog({this.form});

  @override
  State<_DieCuttingFormDialog> createState() => _DieCuttingFormDialogState();
}

class _DieCuttingFormDialogState extends State<_DieCuttingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _formNumberController;
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _sheetLengthController;
  late TextEditingController _sheetWidthController;
  late TextEditingController _numberOfBoxesController;
  late TextEditingController _shelfLocationController;
  late TextEditingController _customerNameController;
  late TextEditingController _customerCodeController;
  late TextEditingController _itemNameController;
  late TextEditingController _itemCodeController;
  bool _isSheet = false;

  @override
  void initState() {
    super.initState();
    _formNumberController = TextEditingController(text: widget.form?.formNumber ?? '');
    _lengthController = TextEditingController(text: widget.form?.length.toString() ?? '');
    _widthController = TextEditingController(text: widget.form?.width.toString() ?? '');
    _heightController = TextEditingController(text: widget.form?.height.toString() ?? '');
    _sheetLengthController = TextEditingController(text: widget.form?.sheetLength.toString() ?? '');
    _sheetWidthController = TextEditingController(text: widget.form?.sheetWidth.toString() ?? '');
    _numberOfBoxesController = TextEditingController(text: widget.form?.numberOfBoxes.toString() ?? '');
    _shelfLocationController = TextEditingController(text: widget.form?.shelfLocation ?? '');
    _customerNameController = TextEditingController(text: widget.form?.customerName ?? '');
    _customerCodeController = TextEditingController(text: widget.form?.customerCode ?? '');
    _itemNameController = TextEditingController(text: widget.form?.itemName ?? '');
    _itemCodeController = TextEditingController(text: widget.form?.itemCode ?? '');
    _isSheet = widget.form?.isSheet ?? false;
  }

  @override
  void dispose() {
    _formNumberController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _sheetLengthController.dispose();
    _sheetWidthController.dispose();
    _numberOfBoxesController.dispose();
    _shelfLocationController.dispose();
    _customerNameController.dispose();
    _customerCodeController.dispose();
    _itemNameController.dispose();
    _itemCodeController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final box = Hive.box<DieCuttingForm>('die_cutting_forms');
      
      final newForm = DieCuttingForm(
        id: widget.form?.id ?? const Uuid().v4(),
        formNumber: _formNumberController.text,
        length: double.tryParse(_lengthController.text) ?? 0.0,
        width: double.tryParse(_widthController.text) ?? 0.0,
        height: double.tryParse(_heightController.text) ?? 0.0,
        sheetLength: double.tryParse(_sheetLengthController.text) ?? 0.0,
        sheetWidth: double.tryParse(_sheetWidthController.text) ?? 0.0,
        numberOfBoxes: double.tryParse(_numberOfBoxesController.text) ?? 0.0,
        isSheet: _isSheet,
        shelfLocation: _shelfLocationController.text,
        customerName: _customerNameController.text,
        customerCode: _customerCodeController.text,
        itemName: _itemNameController.text,
        itemCode: _itemCodeController.text,
      );

      if (widget.form != null) {
        // Find and update
        final key = box.keys.firstWhere((k) => box.get(k)?.id == widget.form!.id, orElse: () => null);
        if (key != null) {
          box.put(key, newForm);
        }
      } else {
        box.add(newForm);
      }

      SyncService.instance.pushToQueue('die_cutting_forms', newForm.toJson(), operation: 'upsert');

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.form == null ? 'إضافة قالب تكسير' : 'تعديل قالب التكسير'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _formNumberController,
                decoration: const InputDecoration(labelText: 'رقم الفورمة'),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lengthController,
                      decoration: const InputDecoration(labelText: 'الطول'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _widthController,
                      decoration: const InputDecoration(labelText: 'العرض'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(labelText: 'الارتفاع'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sheetLengthController,
                      decoration: const InputDecoration(labelText: 'طول الشيت'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _sheetWidthController,
                      decoration: const InputDecoration(labelText: 'عرض الشيت'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(labelText: 'اسم العميل (اختياري)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _customerCodeController,
                      decoration: const InputDecoration(labelText: 'كود العميل (اختياري)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _itemNameController,
                      decoration: const InputDecoration(labelText: 'اسم الصنف (اختياري)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _itemCodeController,
                      decoration: const InputDecoration(labelText: 'كود الصنف (اختياري)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _numberOfBoxesController,
                decoration: const InputDecoration(labelText: 'عدد العلب'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _shelfLocationController,
                decoration: const InputDecoration(labelText: 'مكان الرف (اختياري)'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('هل هو شيت؟'),
                value: _isSheet,
                onChanged: (val) {
                  setState(() {
                    _isSheet = val;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
