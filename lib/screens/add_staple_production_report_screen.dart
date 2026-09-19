import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/utils/worker_utils.dart';

class AddStapleProductionReportScreen extends StatefulWidget {
  const AddStapleProductionReportScreen({super.key});

  @override
  State<AddStapleProductionReportScreen> createState() => _AddStapleProductionReportScreenState();
}

class _AddStapleProductionReportScreenState extends State<AddStapleProductionReportScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController _dateController = TextEditingController();
  String? _selectedShift;
  
  final TextEditingController _workOrderController = TextEditingController();
  
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _itemCodeController = TextEditingController();
  
  String? _selectedMachine;
  String? _selectedTechnician;
  
  final List<String> _selectedCrewMembers = [];
  
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  
  final TextEditingController _productionController = TextEditingController();
  final TextEditingController _wasteController = TextEditingController();
  
  final TextEditingController _downtimeStartController = TextEditingController();
  final TextEditingController _downtimeEndController = TextEditingController();
  final TextEditingController _totalDowntimeController = TextEditingController();
  
  final TextEditingController _notesController = TextEditingController();

  final List<String> shifts = ['الوردية الصباحية', 'الوردية المسائية'];
  final List<String> machines = ['دباسة 1', 'دباسة 2', 'تعبئة وتغليف'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateController.text = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _wasteController.text = "0";
    _totalDowntimeController.text = "0";
  }

  @override
  void dispose() {
    _dateController.dispose();
    _workOrderController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _customerController.dispose();
    _itemController.dispose();
    _itemCodeController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _productionController.dispose();
    _wasteController.dispose();
    _downtimeStartController.dispose();
    _downtimeEndController.dispose();
    _totalDowntimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (pickedTime != null) {
      if (!mounted) return;
      final localizations = MaterialLocalizations.of(context);
      final formattedTimeOfDay = localizations.formatTimeOfDay(pickedTime, alwaysUse24HourFormat: true);
      setState(() {
        controller.text = formattedTimeOfDay;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      setState(() {
        _dateController.text =
            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final double productionQty = double.tryParse(_productionController.text) ?? 0;
      final double wasteQty = double.tryParse(_wasteController.text) ?? 0;

      await Supabase.instance.client.from('staple_production_reports').insert({
        'shift_name': _selectedShift,
        'report_date': _dateController.text,
        'work_order': _workOrderController.text,
        'start_time': _startTimeController.text,
        'end_time': _endTimeController.text,
        'customer_name': _customerController.text,
        'item_name': _itemController.text,
        'item_code': _itemCodeController.text,
        'machine_name': _selectedMachine,
        'technician_name': _selectedTechnician,
        'crew_members': _selectedCrewMembers,
        'length': double.tryParse(_lengthController.text),
        'width': double.tryParse(_widthController.text),
        'height': double.tryParse(_heightController.text),
        'production_quantity': productionQty,
        'waste_quantity': wasteQty,
        'downtime_start': _downtimeStartController.text,
        'downtime_end': _downtimeEndController.text,
        'total_downtime': int.tryParse(_totalDowntimeController.text),
        'notes': _notesController.text,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'approved',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التقرير بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    bool isNumber = false,
    bool isRequired = true,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade400),
          prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent) : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
        ),
        validator: isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    IconData? icon,
    bool isRequired = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade400),
          prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent) : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
        ),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        isExpanded: true,
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              item, 
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: isRequired
            ? (val) => val == null || val.isEmpty ? 'هذا الحقل مطلوب' : null
            : null,
      ),
    );
  }

  Widget _buildCrewMembersSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () async {
          final sortedWorkers = WorkerUtils.getSortedWorkers('staples');
          
          await showDialog(
            context: context,
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setStateDialog) {
                  return AlertDialog(
                    title: const Text('اختر طاقم الماكينة', style: TextStyle(fontFamily: 'Cairo')),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sortedWorkers.length,
                        itemBuilder: (context, index) {
                          final worker = sortedWorkers[index];
                          bool showDivider = false;
                          if (index > 0) {
                            final prevWorker = sortedWorkers[index - 1];
                            String normDept = 'staples';
                            if (prevWorker.department == normDept && worker.department != normDept) {
                              showDivider = true;
                            }
                          }

                          final isSelected = _selectedCrewMembers.contains(worker.name);
                          final tile = CheckboxListTile(
                            title: Text('${worker.name} (${worker.job})', style: const TextStyle(fontFamily: 'Cairo')),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setStateDialog(() {
                                if (value == true) {
                                  _selectedCrewMembers.add(worker.name);
                                } else {
                                  _selectedCrewMembers.remove(worker.name);
                                }
                              });
                            },
                          );

                          if (showDivider) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Divider(thickness: 2),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text('باقي أقسام المصنع', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                ),
                                tile,
                              ],
                            );
                          }
                          return tile;
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('موافق', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ],
                  );
                },
              );
            },
          );
          setState(() {}); // Update UI to reflect selected count
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'طاقم الماكينة (اختياري)',
            labelStyle: TextStyle(color: Colors.blueGrey.shade400),
            prefixIcon: const Icon(Icons.group, color: Colors.blueAccent),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
            ),
          ),
          child: Text(
            _selectedCrewMembers.isEmpty 
                ? 'اضغط لاختيار الطاقم' 
                : 'تم اختيار ${_selectedCrewMembers.length} عمال',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sortedWorkers = WorkerUtils.getSortedWorkers('staples');
    final technicianNames = sortedWorkers.map((e) => e.name).toSet().toList(); // unique names

    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة تقرير إنتاج - الدبوس', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 1,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFF1E293B) 
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    const Text(
                      'بيانات التقرير',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'الوردية',
                            value: _selectedShift,
                            items: shifts,
                            icon: Icons.work_outline,
                            onChanged: (val) => setState(() => _selectedShift = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            _dateController,
                            "التاريخ",
                            icon: Icons.calendar_today,
                            readOnly: true,
                            onTap: _selectDate,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(_workOrderController, "رقم أمر التشغيل", icon: Icons.assignment, isNumber: true),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_startTimeController, "🕒 وقت البداية",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(_startTimeController),
                              isRequired: false),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(_endTimeController, "🕒 وقت النهاية",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(_endTimeController),
                              isRequired: false),
                        ),
                      ],
                    ),
                    
                    _buildTextField(_customerController, "👤 اسم العميل", icon: Icons.business),
                    _buildTextField(_itemController, "📦 الصنف", icon: Icons.category),
                    _buildTextField(_itemCodeController, "كود الصنف", icon: Icons.qr_code, isNumber: true, isRequired: false),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'الماكينة',
                            value: _selectedMachine,
                            items: machines,
                            icon: Icons.precision_manufacturing,
                            onChanged: (val) => setState(() => _selectedMachine = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(
                            label: 'اسم الفني',
                            value: _selectedTechnician,
                            items: technicianNames,
                            icon: Icons.person,
                            onChanged: (val) => setState(() => _selectedTechnician = val),
                          ),
                        ),
                      ],
                    ),
                    
                    _buildCrewMembersSelector(),
                    
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(_lengthController, "📏 طول",
                                isNumber: true)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildTextField(_widthController, "📏 عرض",
                                isNumber: true)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildTextField(
                                _heightController, "📏 ارتفاع",
                                isNumber: true)),
                      ],
                    ),
                    
                    _buildTextField(_productionController, "🔢 عدد الشيتات", isNumber: true, icon: Icons.check_circle_outline),
                    _buildTextField(_wasteController, "📉 الهالك", isNumber: true, isRequired: false, icon: Icons.delete_outline),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_downtimeStartController, "⏱️ بداية العطل",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(_downtimeStartController),
                              isRequired: false),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(_downtimeEndController, "⏱️ نهاية العطل",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(_downtimeEndController),
                              isRequired: false),
                        ),
                      ],
                    ),
                    _buildTextField(_totalDowntimeController, "⏳ إجمالي دقائق التعطل", icon: Icons.timer_off, isNumber: true, isRequired: false),
                    _buildTextField(_notesController, "📝 ملاحظات (اختياري)", icon: Icons.notes, isRequired: false, maxLines: 3),

                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'حفظ التقرير',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
