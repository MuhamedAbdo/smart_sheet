import 'package:flutter/material.dart';
import 'package:smart_sheet/services/job_order_service.dart';

/// Dialog إصدار أمر التشغيل — حصرياً لسطح المكتب (Windows)
class JobOrderDialog extends StatefulWidget {
  final String clientName;
  final String clientCode;

  /// قائمة أصناف العميل من صندوق savedSheetSizes
  final List<Map<String, dynamic>> clientItems;

  const JobOrderDialog({
    super.key,
    required this.clientName,
    this.clientCode = '',
    this.clientItems = const [],
  });

  @override
  State<JobOrderDialog> createState() => _JobOrderDialogState();
}

class _JobOrderDialogState extends State<JobOrderDialog> {
  // ── Controllers ──────────────────────────────────────────────────────────────
  final _orderNumberCtrl = TextEditingController();
  final _jobNumberCtrl = TextEditingController();
  final _createdByCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _supervisorCtrl = TextEditingController();
  final _deliveryDateCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _receivedDateCtrl = TextEditingController();
  final _generalNotesCtrl = TextEditingController();

  // Per-item controllers keyed by item index
  final Map<int, TextEditingController> _qtyCtrl = {};
  final Map<int, TextEditingController> _itemNotesCtrl = {};

  // Corrugation controllers keyed by item index
  final Map<int, List<String>> _itemSelectedCorrugations = {};
  final Map<int, TextEditingController> _itemCustomCorrugationCtrl = {};
  final Map<int, TextEditingController> _itemSamplesCtrl = {};
  final Map<int, TextEditingController> _itemBoxSizeCtrl = {};
  final Map<int, TextEditingController> _itemSheetSizeCtrl = {};
  final Map<int, TextEditingController> _itemSheetCountCtrl = {};

  // Selected items list (ordered)
  final List<int> _selectedIndices = [];

  bool _isGenerating = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final dateStr =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    
    _orderNumberCtrl.text = "0000";
    _jobNumberCtrl.text = "0000";
    _startDateCtrl.text = dateStr;
  }

  @override
  void dispose() {
    _orderNumberCtrl.dispose();
    _jobNumberCtrl.dispose();
    _createdByCtrl.dispose();
    _addressCtrl.dispose();
    _startDateCtrl.dispose();
    _supervisorCtrl.dispose();
    _deliveryDateCtrl.dispose();
    _phoneCtrl.dispose();
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
    for (final c in _itemBoxSizeCtrl.values) {
      c.dispose();
    }
    for (final c in _itemSheetSizeCtrl.values) {
      c.dispose();
    }
    for (final c in _itemSheetCountCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Item Selection ───────────────────────────────────────────────────────────
  void _toggleItem(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        _qtyCtrl.remove(index)?.dispose();
        _itemNotesCtrl.remove(index)?.dispose();

        _itemSelectedCorrugations.remove(index);
        _itemCustomCorrugationCtrl.remove(index)?.dispose();
        _itemSamplesCtrl.remove(index)?.dispose();
        _itemBoxSizeCtrl.remove(index)?.dispose();
        _itemSheetSizeCtrl.remove(index)?.dispose();
        _itemSheetCountCtrl.remove(index)?.dispose();
      } else {
        _selectedIndices.add(index);
        _qtyCtrl[index] = TextEditingController();
        _itemNotesCtrl[index] = TextEditingController();

        // Initialize corrugation controllers
        final raw = widget.clientItems[index];
        final l = raw['length']?.toString() ?? '';
        final w = raw['width']?.toString() ?? '';
        final h = raw['height']?.toString() ?? '';

        final defaultBoxSize = [l, w, h].where((x) => x.isNotEmpty).join(' / ');
        final defaultSheetSize = [l, w].where((x) => x.isNotEmpty).join(' / ');

        _itemSelectedCorrugations[index] = [];
        _itemCustomCorrugationCtrl[index] = TextEditingController();
        _itemSamplesCtrl[index] = TextEditingController();
        _itemBoxSizeCtrl[index] = TextEditingController(text: defaultBoxSize);
        _itemSheetSizeCtrl[index] = TextEditingController(text: defaultSheetSize);
        _itemSheetCountCtrl[index] = TextEditingController();
      }
    });
  }



  // ── PDF Generation ───────────────────────────────────────────────────────────
  Future<void> _generate() async {
    if (_selectedIndices.isEmpty) {
      _showSnack('يرجى اختيار صنف واحد على الأقل');
      return;
    }

    final now = DateTime.now();
    final orderDate =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    // بناء قائمة الأصناف المُختارة بترتيب الاختيار
    final items = _selectedIndices.map((idx) {
      final raw = widget.clientItems[idx];
      return JobOrderItem(
        productName: raw['productName']?.toString() ?? '',
        productCode: raw['productCode']?.toString() ?? '',
        length: raw['length']?.toString() ?? '',
        width: raw['width']?.toString() ?? '',
        height: raw['height']?.toString() ?? '',
        quantity: _qtyCtrl[idx]?.text ?? '',
        itemNotes: _itemNotesCtrl[idx]?.text ?? '',
        corrugationTypes: List.from(_itemSelectedCorrugations[idx] ?? []),
        customCorrugation: _itemCustomCorrugationCtrl[idx]?.text ?? '',
        corrugationSamples: _itemSamplesCtrl[idx]?.text ?? '',
        corrugationBoxSize: _itemBoxSizeCtrl[idx]?.text ?? '',
        corrugationSheetSize: _itemSheetSizeCtrl[idx]?.text ?? '',
        corrugationSheetCount: _itemSheetCountCtrl[idx]?.text ?? '',
      );
    }).toList();

    setState(() => _isGenerating = true);
    try {
      final data = JobOrderData(
        orderNumber: _orderNumberCtrl.text,
        jobNumber: _jobNumberCtrl.text,
        orderDate: orderDate,
        createdBy: _createdByCtrl.text,
        customerName: widget.clientName,
        clientCode: widget.clientCode,
        address: _addressCtrl.text,
        startDate: _startDateCtrl.text,
        supervisor: _supervisorCtrl.text,
        deliveryDate: _deliveryDateCtrl.text,
        phone: _phoneCtrl.text,
        receivedDate: _receivedDateCtrl.text,
        generalNotes: _generalNotesCtrl.text,
        items: items,
      );
      if (mounted) {
        await JobOrderService.showPreview(context, data);
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left panel — form fields
                    Expanded(flex: 5, child: _buildFormPanel(isDark)),
                    // Divider
                    VerticalDivider(
                      width: 1,
                      color: isDark
                          ? Colors.white12
                          : Colors.grey.shade200,
                    ),
                    // Right panel — item selection
                    Expanded(flex: 4, child: _buildItemsPanel(isDark)),
                  ],
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
                  'العميل: ${widget.clientName}',
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
          Row(
            children: [
              Expanded(
                child: _field(
                  'رقم أمر التشغيل',
                  _orderNumberCtrl,
                  isDark,
                  hint: 'تلقائي',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'طلبية رقم',
                  _jobNumberCtrl,
                  isDark,
                  hint: 'رقم الطلبية',
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
          const SizedBox(height: 20),
          _sectionTitle('بيانات العميل', Icons.business_outlined, isDark),
          const SizedBox(height: 12),
          _field('العنوان', _addressCtrl, isDark, hint: 'عنوان العميل'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  'المسئول',
                  _supervisorCtrl,
                  isDark,
                  hint: 'اسم المسئول',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'التليفون',
                  _phoneCtrl,
                  isDark,
                  hint: '01x-xxxxxxxx',
                  keyboard: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('المواعيد', Icons.event_outlined, isDark),
          const SizedBox(height: 12),
          Row(
            children: [
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
              const SizedBox(width: 12),
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
            ],
          ),
          const SizedBox(height: 12),
          _field(
            'تاريخ الانتهاء',
            _receivedDateCtrl,
            isDark,
            hint: 'yyyy/mm/dd',
            readOnly: true,
            onTap: () => _selectDate(context, _receivedDateCtrl),
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
          child: _sectionTitle(
            'الأصناف (${_selectedIndices.length} مُختار)',
            Icons.inventory_2_outlined,
            isDark,
          ),
        ),
        if (widget.clientItems.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'لا توجد أصناف مسجلة لهذا العميل',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: widget.clientItems.length,
              itemBuilder: (_, idx) {
                final item = widget.clientItems[idx];
                final isSelected = _selectedIndices.contains(idx);
                final name = item['productName']?.toString() ?? '—';
                final code = item['productCode']?.toString() ?? '';
                final l = item['length']?.toString() ?? '';
                final w = item['width']?.toString() ?? '';
                final h = item['height']?.toString() ?? '';
                final dims = [l, w, h].where((x) => x.isNotEmpty).join(' × ');

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: isDark ? 0.25 : 0.08)
                        : (isDark
                            ? const Color(0xFF252B3B)
                            : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? accent.withValues(alpha: 0.6)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Product row (tap to toggle)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _toggleItem(idx),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accent
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? accent
                                        : (isDark
                                            ? Colors.white30
                                            : Colors.grey.shade400),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (code.isNotEmpty || dims.isNotEmpty)
                                      Text(
                                        [
                                          if (code.isNotEmpty) 'كود: $code',
                                          if (dims.isNotEmpty) dims,
                                        ].join('  •  '),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Expanded detail fields when selected
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _miniField(
                                      'العدد (الكمية)',
                                      _qtyCtrl[idx]!,
                                      isDark,
                                      keyboard: TextInputType.number,
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
                                    'مواصفات التضليع (سيتم إدراجها بالظهر)',
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
                                          _itemSelectedCorrugations[idx]?.remove(type);
                                        } else {
                                          _itemSelectedCorrugations[idx]?.add(type);
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
                                              value: isChecked,
                                              activeColor: const Color(0xFF1a3a6e),
                                              onChanged: (v) {
                                                setState(() {
                                                  if (v == true) {
                                                    _itemSelectedCorrugations[idx]?.add(type);
                                                  } else {
                                                    _itemSelectedCorrugations[idx]?.remove(type);
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
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // --- Box Size & Sheet Size Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _miniField(
                                      'مقاس العلبة (طول / عرض / إرتفاع)',
                                      _itemBoxSizeCtrl[idx]!,
                                      isDark,
                                      hint: 'مثال: 80 / 36 / 48',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _miniField(
                                      'مقاس الشريحة (طول / عرض)',
                                      _itemSheetSizeCtrl[idx]!,
                                      isDark,
                                      hint: 'مثال: 80 / 36',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
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
