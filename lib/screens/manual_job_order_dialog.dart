import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:smart_sheet/services/job_order_service.dart';
import 'package:smart_sheet/screens/pdf_preview_screen.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:uuid/uuid.dart';

/// Dialog إصدار أمر التشغيل — حصرياً لسطح المكتب (Windows)
class ManualJobOrderDialog extends StatefulWidget {
  const ManualJobOrderDialog({super.key});

  @override
  State<ManualJobOrderDialog> createState() => _ManualJobOrderDialogState();
}

class _ManualJobOrderDialogState extends State<ManualJobOrderDialog> {
  // ── Controllers ──────────────────────────────────────────────────────────────
  final _orderNumberCtrl = TextEditingController();
  final _jobNumberCtrl = TextEditingController();
  final _createdByCtrl = TextEditingController();
  final _clientCodeCtrl = TextEditingController();
  final _issueDateCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _deliveryDateCtrl = TextEditingController();
  final _receivedDateCtrl = TextEditingController();
  final _generalNotesCtrl = TextEditingController();

  final _clientNameCtrl = TextEditingController();
  final Map<int, TextEditingController> _itemNameCtrl = {};
  final Map<int, TextEditingController> _itemCodeCtrl = {};
  final Map<int, TextEditingController> _itemDimLCtrl = {};
  final Map<int, TextEditingController> _itemDimWCtrl = {};
  final Map<int, TextEditingController> _itemDimHCtrl = {};
  int _itemCounter = 0;

  // Per-item controllers keyed by item index
  final Map<int, TextEditingController> _qtyCtrl = {};
  final Map<int, TextEditingController> _itemNotesCtrl = {};

  // Corrugation controllers keyed by item index
  final Map<int, List<String>> _itemSelectedCorrugations = {};
  final Map<int, TextEditingController> _itemCustomCorrugationCtrl = {};
  final Map<int, TextEditingController> _itemSamplesCtrl = {};
  final Map<int, TextEditingController> _itemSheetLenCtrl = {};  // طول الشريحة
  final Map<int, TextEditingController> _itemSheetWidCtrl = {};  // عرض الشريحة
  final Map<int, TextEditingController> _itemSheetCountCtrl = {};

  // عرض البكر وطبقات الورق
  final Map<int, TextEditingController> _itemRollWidthCtrl = {};
  final Map<int, List<TextEditingController>> _itemPaperLayerCtrls = {};

  // Selected items list (ordered)
  final List<int> _selectedIndices = [];

  bool _isGenerating = false;
  bool _saveToDatabase = false;

  void _addItem() {
    if (_selectedIndices.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحد الأقصى 3 أصناف')));
      return;
    }
    setState(() {
      final idx = _itemCounter++;
      _selectedIndices.add(idx);
      _itemNameCtrl[idx] = TextEditingController();
      _itemCodeCtrl[idx] = TextEditingController();
      _itemDimLCtrl[idx] = TextEditingController();
      _itemDimWCtrl[idx] = TextEditingController();
      _itemDimHCtrl[idx] = TextEditingController();
      _qtyCtrl[idx] = TextEditingController();
      _itemNotesCtrl[idx] = TextEditingController();
      _itemSelectedCorrugations[idx] = [];
      _itemCustomCorrugationCtrl[idx] = TextEditingController();
      _itemSamplesCtrl[idx] = TextEditingController();
      _itemSheetLenCtrl[idx] = TextEditingController();
      _itemSheetWidCtrl[idx] = TextEditingController();
      _itemSheetCountCtrl[idx] = TextEditingController();
      _itemRollWidthCtrl[idx] = TextEditingController();
      _itemPaperLayerCtrls[idx] = [];
    });
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final dateStr =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    
    _orderNumberCtrl.clear();
    _jobNumberCtrl.clear();
    _issueDateCtrl.text = dateStr;
    _clientCodeCtrl.text = '';
    _addItem();
  }

  @override
  void dispose() {
    _orderNumberCtrl.dispose();
    _jobNumberCtrl.dispose();
    _createdByCtrl.dispose();
    _clientCodeCtrl.dispose();
    _clientNameCtrl.dispose();
    _issueDateCtrl.dispose();
    _startDateCtrl.dispose();
    _deliveryDateCtrl.dispose();
    _receivedDateCtrl.dispose();
    _generalNotesCtrl.dispose();
    for (final c in _qtyCtrl.values) {
      c.dispose();
    }
    for (final c in _itemNotesCtrl.values) {
      c.dispose();
    }
    for (final c in _itemCustomCorrugationCtrl.values) {
      c.dispose();
    }
    for (final c in _itemSamplesCtrl.values) {
      c.dispose();
    }
    for (final c in _itemSheetLenCtrl.values) {
      c.dispose();
    }
    for (final c in _itemSheetWidCtrl.values) {
      c.dispose();
    }
    for (final c in _itemSheetCountCtrl.values) {
      c.dispose();
    }
    for (final c in _itemRollWidthCtrl.values) {
      c.dispose();
    }
    for (final layers in _itemPaperLayerCtrls.values) {
      for (final c in layers) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // ── Item Selection ───────────────────────────────────────────────────────────
  void _toggleItem(int index) {
    if (_selectedIndices.length <= 1) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إضافة صنف واحد على الأقل')));
       return;
    }
    setState(() {
      _selectedIndices.remove(index);
    });
  }

  // ── Layer Count Logic ─────────────────────────────────────────────────────────
  /// يُحدِّد عدد حقول طبقات الورق بناءً على نوع التضليع المختار
  int _getDefaultLayerCount(int idx) {
    final types = _itemSelectedCorrugations[idx] ?? [];
    if (types.isEmpty) return 0;
    final t = types.first;
    if (t == 'E' || t == 'C') return 3;
    if (t == 'C/E' || t == 'C/C' || t == 'E/E') return 5;
    // للتضليع المخصص: نفترض 3 طبقات كافتراضي
    return 3;
  }

  /// يُحدِّث قائمة controllers الطبقات ليوافق العدد المطلوب
  void _syncLayerControllers(int idx, int requiredCount) {
    final current = _itemPaperLayerCtrls[idx] ?? [];
    if (current.length < requiredCount) {
      for (int i = current.length; i < requiredCount; i++) {
        current.add(TextEditingController());
      }
    } else if (current.length > requiredCount) {
      final excess = current.sublist(requiredCount);
      for (final c in excess) {
        c.dispose();
      }
      current.removeRange(requiredCount, current.length);
    }
    _itemPaperLayerCtrls[idx] = current;
  }



  // ── Save to Hive ──────────────────────────────────────────────────────────────
  /// يحفظ بيانات العميل وأصنافه في Hive كعميل دائم
  Future<void> _saveClientToHive() async {
    final clientName = _clientNameCtrl.text.trim();
    final clientCode = _clientCodeCtrl.text.trim();

    if (clientName.isEmpty) {
      _showSnack('⚠️ لا يمكن الحفظ: اسم العميل فارغ.');
      return;
    }

    final box = await Hive.openBox('savedSheetSizes');
    const uuid = Uuid();
    final now = DateTime.now().toIso8601String();

    // ① تسجيل سجل العميل الرئيسي (isClientRecord: true)
    // نتحقق أولاً هل يوجد عميل بنفس الاسم لتفادي التكرار
    bool clientExists = false;
    for (var i = 0; i < box.length; i++) {
      final record = box.getAt(i);
      if (record is Map) {
        final existingName = (record['clientName'] ?? '').toString().trim().toLowerCase();
        final isClientRec = record['isClientRecord'] == true;
        if (isClientRec && existingName == clientName.toLowerCase()) {
          clientExists = true;
          break;
        }
      }
    }

    if (!clientExists) {
      final clientRecord = <String, dynamic>{
        'sync_id': uuid.v4(),
        'clientName': clientName,
        'productName': '',
        'productCode': clientCode,
        'isClientRecord': true,
        'processType': 'تفصيل',
        'length': '',
        'width': '',
        'height': '',
        'imagePaths': <String>[],
        'date': now,
        'isSheet': false,
        'factoryId': '',
        // إعدادات تفصيل افتراضية
        'isOverFlap': false,
        'isFlap': true,
        'isOneFlap': false,
        'isTwoFlap': true,
        'addTwoMm': false,
        'isFullSize': false,
        'isQuarterSize': false,
        'isQuarterWidth': false,
        'sheetLengthResult': '',
        'sheetWidthResult': '',
        'productionWidth1': '',
        'productionHeight': '',
        'productionWidth2': '',
      };
      await box.add(clientRecord);
      // دفع سجل العميل للمزامنة السحابية فوراً
      SyncService.instance.pushToQueue('customers', _buildCustomerSyncPayload(clientRecord));
    }

    // ② تسجيل كل صنف من الأصناف المُدخلة
    for (final idx in _selectedIndices) {
      final productName = _itemNameCtrl[idx]?.text.trim() ?? '';
      final productCode = _itemCodeCtrl[idx]?.text.trim() ?? '';
      final length = _itemDimLCtrl[idx]?.text.trim() ?? '';
      final width = _itemDimWCtrl[idx]?.text.trim() ?? '';
      final height = _itemDimHCtrl[idx]?.text.trim() ?? '';

      if (productName.isEmpty) continue; // تجاهل الأصناف الفارغة

      final itemRecord = <String, dynamic>{
        'sync_id': uuid.v4(),
        'clientName': clientName,
        'productName': productName,
        'productCode': productCode.isNotEmpty ? productCode : clientCode,
        'isClientRecord': false,
        'processType': 'تفصيل',
        'length': length,
        'width': width,
        'height': height,
        'imagePaths': <String>[],
        'date': now,
        'isSheet': false,
        'factoryId': '',
        // إعدادات تفصيل افتراضية
        'isOverFlap': false,
        'isFlap': true,
        'isOneFlap': false,
        'isTwoFlap': true,
        'addTwoMm': false,
        'isFullSize': false,
        'isQuarterSize': false,
        'isQuarterWidth': false,
        'sheetLengthResult': '',
        'sheetWidthResult': '',
        'productionWidth1': '',
        'productionHeight': '',
        'productionWidth2': '',
      };
      await box.add(itemRecord);
      // دفع سجل الصنف للمزامنة السحابية فوراً
      SyncService.instance.pushToQueue('customers', _buildCustomerSyncPayload(itemRecord));
    }

    _showSnack('✅ تم حفظ العميل والأصناف في سجل العملاء بنجاح.');
  }

  /// تحويل سجل Hive إلى تنسيق جدول customers في Supabase
  Map<String, dynamic> _buildCustomerSyncPayload(Map<String, dynamic> r) {
    return {
      'sync_id': r['sync_id'],
      'client_name': r['clientName'],
      'product_name': r['productName'],
      'product_code': r['productCode'],
      'process_type': r['processType'],
      'length': r['length'],
      'width': r['width'],
      'height': r['height'],
      'is_sheet': r['isSheet'],
      'date': r['date'],
      'is_client_record': r['isClientRecord'],
      'image_paths': r['imagePaths'] ?? [],
      'form_number': null,
      'number_of_boxes': null,
      'sheet_details': {
        'isOverFlap': r['isOverFlap'],
        'isFlap': r['isFlap'],
        'isOneFlap': r['isOneFlap'],
        'isTwoFlap': r['isTwoFlap'],
        'addTwoMm': r['addTwoMm'],
        'isFullSize': r['isFullSize'],
        'isQuarterSize': r['isQuarterSize'],
        'isQuarterWidth': r['isQuarterWidth'],
        'sheetLengthResult': r['sheetLengthResult'],
        'sheetWidthResult': r['sheetWidthResult'],
        'productionWidth1': r['productionWidth1'],
        'productionHeight': r['productionHeight'],
        'productionWidth2': r['productionWidth2'],
        'sheetLengthManual': null,
        'sheetWidthManual': null,
        'cuttingType': null,
        'formNumber': null,
        'form_number': null,
        'numberOfBoxes': null,
        'number_of_boxes': null,
      },
    };
  }

  // ── PDF Generation ───────────────────────────────────────────────────────────
  Future<void> _generate() async {
    if (_selectedIndices.isEmpty) {
      _showSnack('يرجى اختيار صنف واحد على الأقل');
      return;
    }

    // بناء قائمة الأصناف المُختارة بترتيب الاختيار
    final items = _selectedIndices.map((idx) {
      final l = _itemDimLCtrl[idx]?.text ?? '';
      final w = _itemDimWCtrl[idx]?.text ?? '';
      final h = _itemDimHCtrl[idx]?.text ?? '';
      final boxSize = [l, w, h].where((x) => x.isNotEmpty).join(' / ');

      // مقاس الشريحة من الخانتين المنفصلتين
      final sheetLen = _itemSheetLenCtrl[idx]?.text.trim() ?? '';
      final sheetWid = _itemSheetWidCtrl[idx]?.text.trim() ?? '';
      final sheetSize = [sheetLen, sheetWid].where((x) => x.isNotEmpty).join(' / ');

      return JobOrderItem(
        productName: _itemNameCtrl[idx]?.text ?? '',
        productCode: _itemCodeCtrl[idx]?.text ?? '',
        length: l,
        width: w,
        height: h,
        quantity: _qtyCtrl[idx]?.text ?? '',
        itemNotes: _itemNotesCtrl[idx]?.text ?? '',
        corrugationTypes: List.from(_itemSelectedCorrugations[idx] ?? []),
        customCorrugation: _itemCustomCorrugationCtrl[idx]?.text ?? '',
        corrugationSamples: _itemSamplesCtrl[idx]?.text ?? '',
        corrugationBoxSize: boxSize,
        corrugationSheetSize: sheetSize,
        corrugationSheetCount: _itemSheetCountCtrl[idx]?.text ?? '',
        rollWidth: _itemRollWidthCtrl[idx]?.text ?? '',
        paperLayers: (_itemPaperLayerCtrls[idx] ?? [])
            .map((c) => c.text)
            .where((t) => t.isNotEmpty)
            .toList(),
      );
    }).toList();

    // نقرأ auth قبل أي await لتجنب استخدام BuildContext بعد فجوة async
    final auth = Provider.of<AuthService>(context, listen: false);

    setState(() => _isGenerating = true);
    try {
      // حفظ في Hive إذا طلب المستخدم ذلك
      if (_saveToDatabase) {
        await _saveClientToHive();
      }
      final data = JobOrderData(
        orderNumber: _orderNumberCtrl.text,
        jobNumber: _jobNumberCtrl.text,
        orderDate: _issueDateCtrl.text,
        createdBy: _createdByCtrl.text,
        customerName: _clientNameCtrl.text,
        clientCode: _clientCodeCtrl.text,
        address: '',
        startDate: _startDateCtrl.text,
        supervisor: '',
        deliveryDate: _deliveryDateCtrl.text,
        phone: '',
        receivedDate: _receivedDateCtrl.text,
        generalNotes: _generalNotesCtrl.text,
        creatorEmail: auth.currentUserEmail ?? '',
        items: items,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              title: 'معاينة أمر التشغيل',
              jobOrderData: data,
              buildPdf: (format) =>
                  JobOrderService.generateNativePdf(data, format: format),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showSnack('خطأ في إنشاء أمر التشغيل: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      locale: const Locale('ar', 'AE'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1a3a6e),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final dateStr =
          '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = dateStr;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 900,
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Right side (in RTL) — form fields
                      Expanded(
                        flex: 5,
                        child: FocusTraversalOrder(
                          order: const NumericFocusOrder(1),
                          child: FocusTraversalGroup(
                            policy: WidgetOrderTraversalPolicy(),
                            child: _buildFormPanel(isDark),
                          ),
                        ),
                      ),
                      // Divider
                      VerticalDivider(
                        width: 1,
                        color: isDark
                            ? Colors.white12
                            : Colors.grey.shade200,
                      ),
                      // Left side (in RTL) — item selection & specifications
                      Expanded(
                        flex: 4,
                        child: FocusTraversalOrder(
                          order: const NumericFocusOrder(2),
                          child: FocusTraversalGroup(
                            policy: WidgetOrderTraversalPolicy(),
                            child: _buildItemsPanel(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildFooter(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A5F), const Color(0xFF0D2137)]
              : [const Color(0xFF1a3a6e), const Color(0xFF0f2347)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.print_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إصدار أمر تشغيل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'إدخال يدوي - طلب حر',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'إغلاق',
          ),
        ],
      ),
    );
  }

  // ── Left Form Panel ───────────────────────────────────────────────────────────
  Widget _buildFormPanel(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('بيانات أمر التشغيل', Icons.article_outlined, isDark),
          const SizedBox(height: 12),
          _field('اسم العميل', _clientNameCtrl, isDark, hint: 'أدخل اسم العميل'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  'رقم أمر التشغيل',
                  _orderNumberCtrl,
                  isDark,
                  hint: 'أرقام فقط',
                  keyboard: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'طلبية رقم',
                  _jobNumberCtrl,
                  isDark,
                  hint: 'أرقام فقط',
                  keyboard: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field(
            'محرر أمر التشغيل',
            _createdByCtrl,
            isDark,
            hint: 'اسم الشخص المُصدِر',
          ),
          const SizedBox(height: 12),
          _field(
            'كود العميل',
            _clientCodeCtrl,
            isDark,
            hint: 'أدخل كود العميل يدوياً',
          ),
          const SizedBox(height: 20),
          // "Client Info" section removed as requested.

          _sectionTitle('المواعيد', Icons.event_outlined, isDark),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  'تاريخ إصدار أمر التشغيل',
                  _issueDateCtrl,
                  isDark,
                  hint: 'yyyy/mm/dd',
                  readOnly: true,
                  onTap: () => _selectDate(context, _issueDateCtrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'تاريخ بدء التشغيل',
                  _startDateCtrl,
                  isDark,
                  hint: 'yyyy/mm/dd',
                  readOnly: true,
                  onTap: () => _selectDate(context, _startDateCtrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  'ميعاد التسليم',
                  _deliveryDateCtrl,
                  isDark,
                  hint: 'yyyy/mm/dd',
                  readOnly: true,
                  onTap: () => _selectDate(context, _deliveryDateCtrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'تاريخ الانتهاء',
                  _receivedDateCtrl,
                  isDark,
                  hint: 'yyyy/mm/dd',
                  readOnly: true,
                  onTap: () => _selectDate(context, _receivedDateCtrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle(
            'ملاحظات وتعليمات عامة',
            Icons.notes_outlined,
            isDark,
          ),
          const SizedBox(height: 12),
          _field(
            'ملاحظات',
            _generalNotesCtrl,
            isDark,
            hint: 'أكتب الملاحظات والتعليمات العامة هنا...',
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // ── خيار الحفظ في قاعدة البيانات ──────────────────────────────
          Material(
            color: _saveToDatabase
                ? const Color(0xFF1a3a6e).withValues(alpha: 0.08)
                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: _saveToDatabase
                    ? const Color(0xFF1a3a6e).withValues(alpha: 0.4)
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
                width: 1.5,
              ),
            ),
            child: CheckboxListTile(
              value: _saveToDatabase,
              onChanged: (v) => setState(() => _saveToDatabase = v ?? false),
              activeColor: const Color(0xFF1a3a6e),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: Text(
                'حفظ العميل والأصناف في سجل العملاء',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: _saveToDatabase
                      ? const Color(0xFF1a3a6e)
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                ),
              ),
              subtitle: Text(
                'تحويل العميل والأصناف إلى عميل دائم في النظام',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
              secondary: Icon(
                Icons.person_add_alt_1_outlined,
                color: _saveToDatabase
                    ? const Color(0xFF1a3a6e)
                    : (isDark ? Colors.white38 : Colors.grey.shade400),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Right Items Panel ─────────────────────────────────────────────────────────
  Widget _buildItemsPanel(bool isDark) {
    const accent = Color(0xFF1a3a6e);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle(
                'الأصناف (${_selectedIndices.length})',
                Icons.inventory_2_outlined,
                isDark,
              ),
              if (_selectedIndices.length < 3)
                InkWell(
                  onTap: _addItem,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text('إضافة صنف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: _selectedIndices.length,
            itemBuilder: (_, i) {
              final idx = _selectedIndices[i];

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.25 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => _toggleItem(idx),
                              child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(flex: 2, child: _miniField('بيان الصنف *', _itemNameCtrl[idx]!, isDark)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _miniField('الكود', _itemCodeCtrl[idx]!, isDark)),
                                    ]
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(child: _miniField('طول', _itemDimLCtrl[idx]!, isDark, keyboard: TextInputType.number)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _miniField('عرض', _itemDimWCtrl[idx]!, isDark, keyboard: TextInputType.number)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _miniField('ارتفاع', _itemDimHCtrl[idx]!, isDark, keyboard: TextInputType.number)),
                                    ]
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 12),
                            // ── صف: الكمية + ملاحظات + عرض البكر
                            Row(
                              children: [
                                  Expanded(
                                    flex: 2,
                                    child: _miniField(
                                      'العدد (الكمية)',
                                      _qtyCtrl[idx]!,
                                      isDark,
                                      keyboard: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: _miniField(
                                      'عرض البكر (سم)',
                                      _itemRollWidthCtrl[idx]!,
                                      isDark,
                                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                                      hint: 'مثال: 120',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: _miniField(
                                      'ملاحظات التشغيل',
                                      _itemNotesCtrl[idx]!,
                                      isDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // --- Corrugation Section Header
                              Row(
                                children: [
                                  const Icon(Icons.waves, size: 14, color: Color(0xFF1a3a6e)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'مواصفات التضليع',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : const Color(0xFF1a3a6e),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              
                              // --- Checkboxes Wrap
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: ['E', 'C', 'E/E', 'C/C', 'C/E'].map((type) {
                                  final isChecked = _itemSelectedCorrugations[idx]?.contains(type) ?? false;
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isChecked) {
                                          _itemSelectedCorrugations[idx]?.clear();
                                          _syncLayerControllers(idx, 0);
                                        } else {
                                          _itemSelectedCorrugations[idx] = [type];
                                          _itemCustomCorrugationCtrl[idx]?.clear();
                                          final count = _getDefaultLayerCount(idx);
                                          _syncLayerControllers(idx, count);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: Checkbox(
                                              value: _itemSelectedCorrugations[idx]?.isNotEmpty == true && 
                                                     _itemSelectedCorrugations[idx]!.first == type,
                                              activeColor: const Color(0xFF1a3a6e),
                                              onChanged: (v) {
                                                setState(() {
                                                  if (v == true) {
                                                    _itemSelectedCorrugations[idx] = [type];
                                                    _itemCustomCorrugationCtrl[idx]?.clear();
                                                    final count = _getDefaultLayerCount(idx);
                                                    _syncLayerControllers(idx, count);
                                                  } else {
                                                    _itemSelectedCorrugations[idx]?.clear();
                                                    _syncLayerControllers(idx, 0);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            type,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              
                              // --- Custom Corrugation
                              _miniField(
                                'تضليع مخصص / أخرى (مثل E/E + C)',
                                _itemCustomCorrugationCtrl[idx]!,
                                isDark,
                                hint: 'أكتب نوع التضليع إذا لم يكن بالقائمة أعلاه',
                                readOnly: _itemSelectedCorrugations[idx]?.isNotEmpty == true,
                                onChanged: (v) {
                                  if (v.isNotEmpty) {
                                    final count = _getDefaultLayerCount(idx);
                                    _syncLayerControllers(idx, count == 0 ? 3 : count);
                                    setState(() {});
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              
                              // --- Samples & Sheet Count Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _miniField(
                                      'عينات',
                                      _itemSamplesCtrl[idx]!,
                                      isDark,
                                      hint: 'مثال: معتمدة / مطابقة',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _miniField(
                                      'عدد الشرائح',
                                      _itemSheetCountCtrl[idx]!,
                                      isDark,
                                      keyboard: TextInputType.number,
                                      hint: 'أرقام فقط',
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // --- Sheet Size Row (two separate fields)
                              Row(
                                children: [
                                  Expanded(
                                    child: _miniField(
                                      'طول الشريحة',
                                      _itemSheetLenCtrl[idx]!,
                                      isDark,
                                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                                      hint: 'مثال: 80',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _miniField(
                                      'عرض الشريحة',
                                      _itemSheetWidCtrl[idx]!,
                                      isDark,
                                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                                      hint: 'مثال: 36',
                                    ),
                                  ),
                                ],
                              ),
                              
                              // ── قسم أنواع الورق (الطبقات الديناميكية)
                              Builder(builder: (context) {
                                final layers = _itemPaperLayerCtrls[idx] ?? [];
                                if (layers.isEmpty) return const SizedBox.shrink();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.layers_outlined, size: 14, color: Color(0xFF1a3a6e)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'أنواع الورق (الطبقات)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white70 : const Color(0xFF1a3a6e),
                                          ),
                                        ),
                                        const Spacer(),
                                        // زر إضافة طبقة
                                        Tooltip(
                                          message: 'إضافة طبقة',
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                _itemPaperLayerCtrls[idx]!.add(TextEditingController());
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1a3a6e).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFF1a3a6e).withValues(alpha: 0.3)),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.add, size: 13, color: Color(0xFF1a3a6e)),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'إضافة طبقة',
                                                    style: TextStyle(fontSize: 10, color: Color(0xFF1a3a6e), fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ...List.generate(layers.length, (layerIdx) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _miniField(
                                                'طبقة ${layerIdx + 1}',
                                                layers[layerIdx],
                                                isDark,
                                                hint: 'نوع الورق (مثال: فلوت عادي)',
                                              ),
                                            ),
                                            // زر حذف الطبقة (يظهر فقط للطبقات الإضافية)
                                            if (layerIdx >= _getDefaultLayerCount(idx))
                                              Padding(
                                                padding: const EdgeInsets.only(right: 4),
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      layers[layerIdx].dispose();
                                                      layers.removeAt(layerIdx);
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(Icons.remove_circle_outline, size: 16, color: Colors.redAccent),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                );
                                }),

                            ],           // end Column children
                          ),           // end Column
                        ),             // end Padding
                    ],                 // end item children
                  ),                   // end AnimatedContainer child Column
                );                     // end AnimatedContainer
              },
            ),
          ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────────
  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2535) : Colors.grey.shade50,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedIndices.length} صنف مُختار',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _isGenerating ? null : _generate,
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print_outlined, size: 18),
            label: Text(_isGenerating ? 'جاري الإنشاء...' : 'إصدار وطباعة'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1a3a6e),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared UI Helpers ─────────────────────────────────────────────────────────
  Widget _sectionTitle(String label, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF1a3a6e),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF1a3a6e),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }



  Widget _field(
    String label,
    TextEditingController ctrl,
    bool isDark, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xDEFFFFFF) : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF252B3B)
                : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF1a3a6e),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniField(
    String label,
    TextEditingController ctrl,
    bool isDark, {
    TextInputType keyboard = TextInputType.text,
    String? hint,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xDEFFFFFF) : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E2535)
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: Color(0xFF1a3a6e),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
