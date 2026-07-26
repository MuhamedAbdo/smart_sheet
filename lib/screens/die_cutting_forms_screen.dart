// lib/screens/die_cutting_forms_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_sheet/models/die_cutting_form.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/widgets/qr_scanner_modal.dart';
import 'package:smart_sheet/services/qr_print_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
        actions: [
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'مسح باركود القالب',
              onPressed: () => _scanQR(context, box),
            ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'طباعة ملصقات الباركود',
            onPressed: () => _printCurrentForms(box),
          ),
        ],
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
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<DieCuttingForm> box, _) {
                if (box.values.isEmpty) {
                  return const Center(
                      child: Text("لا توجد قوالب تكسير مسجلة",
                          style: TextStyle(fontSize: 18)));
                }
                var forms = box.values.toList();
                if (_searchQuery.isNotEmpty) {
                  forms = forms.where((f) {
                    return f.formNumber.toLowerCase().contains(_searchQuery) ||
                        (f.customerName ?? '')
                            .toLowerCase()
                            .contains(_searchQuery) ||
                        (f.itemName ?? '').toLowerCase().contains(_searchQuery);
                  }).toList();
                }
                if (forms.isEmpty) {
                  return const Center(
                      child: Text("لا توجد قوالب تطابق البحث",
                          style: TextStyle(fontSize: 18)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: forms.length,
                  itemBuilder: (context, index) {
                    final form = forms[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _viewFormDetails(context, form),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("رقم الفورمة: ${form.formNumber}",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        const SizedBox(height: 4),
                                        if (form.customerName != null &&
                                            form.customerName!.isNotEmpty)
                                          Text(
                                              "العميل: ${form.customerName}${form.customerCode != null ? ' (${form.customerCode})' : ''}"),
                                        if (form.itemName != null &&
                                            form.itemName!.isNotEmpty)
                                          Text(
                                              "الصنف: ${form.itemName}${form.itemCode != null ? ' (${form.itemCode})' : ''}"),
                                        Text(
                                            "المقاس: ${form.length} x ${form.width} x ${form.height}"),
                                        Text(
                                            "عدد العلب: ${form.numberOfBoxes.toStringAsFixed(0)}"),
                                      ],
                                    ),
                                  ),
                                  if (form.isSheet)
                                    const Chip(
                                        label: Text('شيت',
                                            style: TextStyle(fontSize: 10))),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.orange),
                                      onPressed: () =>
                                          _showFormDialog(context, form: form)),
                                  IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _confirmDelete(context, form)),
                                ],
                              ),
                            ],
                          ),
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
        builder: (context) => _DieCuttingFormDialog(form: form));
  }

  void _viewFormDetails(BuildContext context, DieCuttingForm form) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل قالب التكسير: ${form.formNumber}'),
        content: SingleChildScrollView(
          child: ListBody(children: [
            if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SizedBox(
                    width: 150.0,
                    height: 150.0,
                    child: QrImageView(
                      data: 'dc_form:${form.formNumber}',
                      version: QrVersions.auto,
                      size: 150.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (form.customerName != null && form.customerName!.isNotEmpty)
              Text(
                  "العميل: ${form.customerName}${form.customerCode != null ? ' (${form.customerCode})' : ''}"),
            if (form.itemName != null && form.itemName!.isNotEmpty)
              Text(
                  "الصنف: ${form.itemName}${form.itemCode != null ? ' (${form.itemCode})' : ''}"),
            Text("المقاس: ${form.length} x ${form.width} x ${form.height}"),
            Text("مقاس الشيت: ${form.sheetLength} x ${form.sheetWidth}"),
            Text("عدد العلب: ${form.numberOfBoxes.toStringAsFixed(0)}"),
            Text("نوع القالب: ${form.isSheet ? 'شيت' : 'عادي'}"),
            if (form.shelfLocation != null && form.shelfLocation!.isNotEmpty)
              Text("مكان الرف: ${form.shelfLocation}"),
          ]),
        ),
        actions: [
          TextButton(
              child: const Text('إغلاق'),
              onPressed: () => Navigator.of(context).pop())
        ],
      ),
    );
  }

  Future<void> _scanQR(BuildContext context, Box<DieCuttingForm> box) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const QRScannerModal(
        title: 'مسح باركود القالب',
        subtitle: 'قم بتوجيه الكاميرا لباركود قالب التكسير',
      ),
    );

    if (result == null || result == 'MANUAL_ENTRY') return;

    String scannedNumber = result;
    if (result.startsWith('dc_form:')) {
      scannedNumber = result.replaceFirst('dc_form:', '').trim();
    }

    final form = box.values.cast<DieCuttingForm?>().firstWhere(
          (f) => f?.formNumber == scannedNumber,
          orElse: () => null,
        );

    if (form != null) {
      if (context.mounted) _viewFormDetails(context, form);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('لم يتم العثور على قالب برقم: $scannedNumber'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _printCurrentForms(Box<DieCuttingForm> box) {
    var forms = box.values.toList();
    if (_searchQuery.isNotEmpty) {
      forms = forms.where((f) {
        return f.formNumber.toLowerCase().contains(_searchQuery) ||
            (f.customerName ?? '').toLowerCase().contains(_searchQuery) ||
            (f.itemName ?? '').toLowerCase().contains(_searchQuery);
      }).toList();
    }
    if (forms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد قوالب لطباعتها')));
      return;
    }
    _showPrintSelectionSheet(forms);
  }

  // ─── BottomSheet اختيار القوالب للطباعة ────────────────────────────────────
  void _showPrintSelectionSheet(List<DieCuttingForm> forms) {
    // الحالة الافتراضية: جميع القوالب محددة
    final selected = List<bool>.filled(forms.length, true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final selectedCount = selected.where((v) => v).length;
            final theme = Theme.of(sheetCtx);
            final isDark = theme.brightness == Brightness.dark;
            final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;

            return Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              // احتلال 85% من ارتفاع الشاشة كحد أقصى
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── مقبض الـ BottomSheet ──────────────────────────────
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // ─── العنوان ──────────────────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.print,
                            color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'تحديد القوالب للطباعة',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          '${forms.length} قالب',
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  // ─── أزرار تحديد الكل / إلغاء التحديد ────────────────
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.select_all, size: 18),
                            label: const Text('تحديد الكل'),
                            onPressed: () => setSheetState(() {
                              for (int i = 0; i < selected.length; i++) {
                                selected[i] = true;
                              }
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.deselect, size: 18),
                            label: const Text('إلغاء التحديد'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                              side: BorderSide(
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400),
                            ),
                            onPressed: () => setSheetState(() {
                              for (int i = 0; i < selected.length; i++) {
                                selected[i] = false;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // ─── قائمة القوالب ─────────────────────────────────────
                  Flexible(
                    child: ListView.builder(
                      itemCount: forms.length,
                      itemBuilder: (ctx, index) {
                        final form = forms[index];
                        final subtitle = [
                          if (form.customerName != null &&
                              form.customerName!.isNotEmpty)
                            form.customerName!,
                          if (form.itemName != null &&
                              form.itemName!.isNotEmpty)
                            form.itemName!,
                        ].join(' • ');

                        return CheckboxListTile(
                          value: selected[index],
                          title: Text(
                            'رقم الفورمة: ${form.formNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                          secondary: form.isSheet
                              ? const Chip(
                                  label: Text('شيت',
                                      style: TextStyle(fontSize: 10)),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                )
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (val) => setSheetState(
                              () => selected[index] = val ?? false),
                        );
                      },
                    ),
                  ),

                  const Divider(height: 1),

                  // ─── زر الطباعة الثابت ────────────────────────────────
                  Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: Text(
                          selectedCount == 0
                              ? 'لم يتم تحديد أي قالب'
                              : 'طباعة المحددة ($selectedCount)',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: selectedCount == 0
                              ? Colors.grey
                              : theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: selectedCount == 0
                            ? null
                            : () {
                                Navigator.pop(sheetCtx);
                                final toPrint = [
                                  for (int i = 0; i < forms.length; i++)
                                    if (selected[i]) forms[i],
                                ];
                                QRPrintService.printDieCuttingQRLabels(toPrint);
                              },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
              onPressed: () => Navigator.of(context).pop()),
          TextButton(
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
            onPressed: () {
              SyncService.instance.pushToQueue(
                  'die_cutting_forms', {'id': form.id, 'sync_id': form.id},
                  operation: 'delete');
              form.delete();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// نافذة إضافة / تعديل قالب التكسير
// ══════════════════════════════════════════════════════════════════
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

  // ─── قسم استدعاء سجل العملاء ────────────────────────────────────
  bool _showCustomerLookup = false;
  List<String> _allCustomerNames = [];
  List<Map<String, dynamic>> _customerItems = [];
  String? _selectedCustomerName;
  Map<String, dynamic>? _selectedItem;
  dynamic _selectedItemHiveKey;
  bool _itemHasNoFormNumber = false;

  @override
  void initState() {
    super.initState();
    _formNumberController =
        TextEditingController(text: widget.form?.formNumber ?? '');
    _lengthController = TextEditingController(
        text:
            widget.form?.length != null ? widget.form!.length.toString() : '');
    _widthController = TextEditingController(
        text: widget.form?.width != null ? widget.form!.width.toString() : '');
    _heightController = TextEditingController(
        text:
            widget.form?.height != null ? widget.form!.height.toString() : '');
    _sheetLengthController = TextEditingController(
        text: widget.form?.sheetLength != null
            ? widget.form!.sheetLength.toString()
            : '');
    _sheetWidthController = TextEditingController(
        text: widget.form?.sheetWidth != null
            ? widget.form!.sheetWidth.toString()
            : '');
    _numberOfBoxesController = TextEditingController(
        text: widget.form?.numberOfBoxes != null
            ? widget.form!.numberOfBoxes.toString()
            : '');
    _shelfLocationController =
        TextEditingController(text: widget.form?.shelfLocation ?? '');
    _customerNameController =
        TextEditingController(text: widget.form?.customerName ?? '');
    _customerCodeController =
        TextEditingController(text: widget.form?.customerCode ?? '');
    _itemNameController =
        TextEditingController(text: widget.form?.itemName ?? '');
    _itemCodeController =
        TextEditingController(text: widget.form?.itemCode ?? '');
    _isSheet = widget.form?.isSheet ?? false;

    if (widget.form == null) _loadCustomerNames();
  }

  @override
  void dispose() {
    for (final c in [
      _formNumberController,
      _lengthController,
      _widthController,
      _heightController,
      _sheetLengthController,
      _sheetWidthController,
      _numberOfBoxesController,
      _shelfLocationController,
      _customerNameController,
      _customerCodeController,
      _itemNameController,
      _itemCodeController
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── جلب أسماء العملاء (أصناف التكسير فقط) ─────────────────────────
  void _loadCustomerNames() {
    if (!Hive.isBoxOpen('savedSheetSizes')) return;
    final box = Hive.box('savedSheetSizes');
    final names = <String>{};
    for (final val in box.values) {
      if (val is! Map) continue;
      if (val['processType']?.toString() != 'تكسير') continue;
      if (val['isClientRecord'] == true) continue;
      final name = val['clientName']?.toString().trim() ?? '';
      if (name.isNotEmpty) names.add(name);
    }
    setState(() => _allCustomerNames = names.toList()..sort());
  }

  // ── عند اختيار عميل ─────────────────────────────────────────────────
  void _onCustomerSelected(String? customerName) {
    setState(() {
      _selectedCustomerName = customerName;
      _selectedItem = null;
      _selectedItemHiveKey = null;
      _itemHasNoFormNumber = false;
      _customerItems = [];
    });
    if (customerName == null || !Hive.isBoxOpen('savedSheetSizes')) return;
    final box = Hive.box('savedSheetSizes');
    final uniqueItems = <String, Map<String, dynamic>>{};
    for (final entry in box.toMap().entries) {
      final val = entry.value;
      if (val is! Map) continue;
      if ((val['clientName']?.toString().trim() ?? '') != customerName) {
        continue;
      }
      if (val['processType']?.toString() != 'تكسير') continue;
      if (val['isClientRecord'] == true) continue;

      final identifier = val['id']?.toString() ??
          val['productCode']?.toString() ??
          entry.key.toString();
      uniqueItems[identifier] = {
        ...Map<String, dynamic>.from(val),
        '__hiveKey': entry.key
      };
    }
    final items = uniqueItems.values.toList();
    items.sort((a, b) {
      final ca = int.tryParse(a['productCode']?.toString() ?? '') ?? 0;
      final cb = int.tryParse(b['productCode']?.toString() ?? '') ?? 0;
      return ca.compareTo(cb);
    });
    setState(() => _customerItems = items);
  }

  // ── عند اختيار صنف → Auto-fill ──────────────────────────────────────
  void _onItemSelected(Map<String, dynamic>? item) {
    setState(() {
      _selectedItem = item;
      _itemHasNoFormNumber = false;
    });
    if (item == null) return;

    _customerNameController.text = item['clientName']?.toString() ?? '';
    _customerCodeController.text = item['productCode']?.toString() ?? '';
    _itemNameController.text = item['productName']?.toString() ?? '';
    _itemCodeController.text = item['productCode']?.toString() ?? '';
    _lengthController.text = item['length']?.toString() ?? '';
    _widthController.text = item['width']?.toString() ?? '';
    _heightController.text = item['height']?.toString() ?? '';
    _sheetLengthController.text = item['sheetLengthManual']?.toString() ?? '';
    _sheetWidthController.text = item['sheetWidthManual']?.toString() ?? '';
    _numberOfBoxesController.text = item['numberOfBoxes']?.toString() ?? '';
    _isSheet = item['isSheet'] == true;
    _selectedItemHiveKey = item['__hiveKey'];

    final formNum = item['formNumber']?.toString().trim().isNotEmpty == true
        ? item['formNumber'].toString().trim()
        : item['form_number']?.toString().trim() ?? '';

    if (formNum.isNotEmpty) {
      _formNumberController.text = formNum;
      setState(() => _itemHasNoFormNumber = false);
    } else {
      _formNumberController.text = '';
      setState(() => _itemHasNoFormNumber = true);
    }
  }

  // ── الحفظ (Two-Way Save) ─────────────────────────────────────────────
  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final box = Hive.box<DieCuttingForm>('die_cutting_forms');
    final enteredFormNumber = _formNumberController.text.trim();

    // التحقق من تكرار رقم الفورمة
    final bool isDuplicate = box.values.any((form) =>
        form.formNumber == enteredFormNumber && form.id != widget.form?.id);

    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("عفواً، رقم الفورمة هذا مسجل مسبقاً لقالب آخر!"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final formId = widget.form?.id ?? const Uuid().v4();

    final newForm = DieCuttingForm(
      id: formId,
      formNumber: _formNumberController.text.trim(),
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

    // 1. حفظ القالب محلياً
    if (widget.form != null) {
      final key = box.keys.firstWhere((k) => box.get(k)?.id == widget.form!.id,
          orElse: () => null);
      if (key != null) box.put(key, newForm);
    } else {
      box.put(formId, newForm);
    }

    // 2. رفع القالب لطابور المزامنة
    SyncService.instance.pushToQueue('die_cutting_forms', newForm.toJson(),
        operation: 'upsert');

    // 3. Two-Way Save: تحديث رقم الفورمة في سجل العميل
    if (widget.form == null &&
        _selectedItemHiveKey != null &&
        Hive.isBoxOpen('savedSheetSizes')) {
      final savedBox = Hive.box('savedSheetSizes');
      final existing = savedBox.get(_selectedItemHiveKey);
      if (existing is Map) {
        final updatedItem = Map<String, dynamic>.from(existing)
          ..['formNumber'] = newForm.formNumber
          ..['form_number'] = newForm.formNumber;
        savedBox.put(_selectedItemHiveKey, updatedItem);
        SyncService.instance
            .pushToQueue('customers', updatedItem, operation: 'upsert');
        debugPrint(
            '✅ [DieCuttingForms] Two-Way Save: تحديث formNumber في سجل العميل'
            ' (${updatedItem['clientName']} / ${updatedItem['productName']}) -> ${newForm.formNumber}');
      }
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.form != null;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(isEditing ? 'تعديل قالب التكسير' : 'إضافة قالب تكسير'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── قسم استدعاء سجل العملاء (إضافة جديدة فقط) ──────────
                if (!isEditing) ...[
                  OutlinedButton.icon(
                    icon: Icon(
                        _showCustomerLookup
                            ? Icons.expand_less
                            : Icons.manage_search,
                        size: 18),
                    label: Text(_showCustomerLookup
                        ? 'إخفاء استدعاء سجل العملاء'
                        : 'استدعاء بيانات من سجل العملاء'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      setState(() {
                        _showCustomerLookup = !_showCustomerLookup;
                        if (_showCustomerLookup) _loadCustomerNames();
                      });
                    },
                  ),
                  if (_showCustomerLookup) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dropdown 1: العميل
                          // ignore: deprecated_member_use
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'اسم العميل',
                              prefixIcon: Icon(Icons.person_search_outlined),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            isExpanded: true,
                            // ignore: deprecated_member_use
                            value: _selectedCustomerName,
                            hint: const Text('اختر عميلاً...'),
                            items: _allCustomerNames
                                .map((name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(name,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: _onCustomerSelected,
                          ),
                          if (_selectedCustomerName != null) ...[
                            const SizedBox(height: 10),
                            // Dropdown 2: الصنف
                            // ignore: deprecated_member_use
                            DropdownButtonFormField<Map<String, dynamic>>(
                              key: ValueKey(_selectedCustomerName),
                              decoration: const InputDecoration(
                                labelText: 'صنف العميل (تكسير)',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              isExpanded: true,
                              // ignore: deprecated_member_use
                              value: _selectedItem,
                              hint: _customerItems.isEmpty
                                  ? const Text(
                                      'لا توجد أصناف تكسير لهذا العميل',
                                      style: TextStyle(fontSize: 13))
                                  : const Text('اختر صنفاً...'),
                              items: _customerItems
                                  .map((item) => DropdownMenuItem(
                                        value: item,
                                        child: Text(
                                            '${item['productName'] ?? '—'}  (${item['productCode'] ?? ''})',
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: _customerItems.isEmpty
                                  ? null
                                  : _onItemSelected,
                            ),
                          ],
                          // تحذير رقم الفورمة مفقود
                          if (_itemHasNoFormNumber) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.amber.shade700),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.amber.shade800, size: 18),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'هذا الصنف لا يمتلك رقم فورمة مسجل.\nأدخل رقم الفورمة وسيُحفظ في بيانات الصنف تلقائياً.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                          color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Divider(),
                  ],
                  const SizedBox(height: 4),
                ],

                // ── رقم الفورمة ──────────────────────────────────────────
                TextFormField(
                  controller: _formNumberController,
                  decoration: InputDecoration(
                    labelText: 'رقم الفورمة',
                    border: const OutlineInputBorder(),
                    suffixIcon: _itemHasNoFormNumber
                        ? const Icon(Icons.edit_note, color: Colors.orange)
                        : null,
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'رقم الفورمة مطلوب' : null,
                ),
                const SizedBox(height: 10),

                // ── الأبعاد ──────────────────────────────────────────────
                Row(children: [
                  _buildNumField(_lengthController, 'الطول'),
                  const SizedBox(width: 8),
                  _buildNumField(_widthController, 'العرض'),
                  const SizedBox(width: 8),
                  _buildNumField(_heightController, 'الارتفاع'),
                ]),
                const SizedBox(height: 10),

                // ── مقاس الشيت ───────────────────────────────────────────
                Row(children: [
                  _buildNumField(_sheetLengthController, 'طول الشيت'),
                  const SizedBox(width: 8),
                  _buildNumField(_sheetWidthController, 'عرض الشيت'),
                ]),
                const SizedBox(height: 10),

                // ── بيانات العميل والصنف ──────────────────────────────────
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(
                              labelText: 'اسم العميل (اختياري)',
                              border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextFormField(
                          controller: _customerCodeController,
                          decoration: const InputDecoration(
                              labelText: 'كود العميل (اختياري)',
                              border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _itemNameController,
                          decoration: const InputDecoration(
                              labelText: 'اسم الصنف (اختياري)',
                              border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextFormField(
                          controller: _itemCodeController,
                          decoration: const InputDecoration(
                              labelText: 'كود الصنف (اختياري)',
                              border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _numberOfBoxesController,
                  decoration: const InputDecoration(
                      labelText: 'عدد العلب', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _shelfLocationController,
                  decoration: const InputDecoration(
                      labelText: 'مكان الرف (اختياري)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 4),

                SwitchListTile(
                  title: const Text('هل هو شيت؟'),
                  value: _isSheet,
                  onChanged: (val) => setState(() => _isSheet = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء')),
        ElevatedButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }

  Widget _buildNumField(TextEditingController ctrl, String label) {
    return Expanded(
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}
