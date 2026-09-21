import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/day_schedule.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/utils/worker_utils.dart';
import 'package:smart_sheet/models/staple_production_report.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:uuid/uuid.dart';

class AddStapleProductionReportScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const AddStapleProductionReportScreen({super.key, this.initialData});

  @override
  State<AddStapleProductionReportScreen> createState() =>
      _AddStapleProductionReportScreenState();
}

class _AddStapleProductionReportScreenState
    extends State<AddStapleProductionReportScreen> {
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

  final TextEditingController _downtimeStartController =
      TextEditingController();
  final TextEditingController _downtimeEndController = TextEditingController();
  final TextEditingController _totalDowntimeController =
      TextEditingController();

  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateController.text =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _wasteController.text = "0";
    _totalDowntimeController.text = "0";

    if (widget.initialData != null) {
      _customerController.text = widget.initialData!['clientName']?.toString() ?? '';
      _itemController.text = widget.initialData!['productName']?.toString() ?? widget.initialData!['product']?.toString() ?? '';
      _itemCodeController.text = widget.initialData!['productCode']?.toString() ?? '';
      _workOrderController.text = widget.initialData!['orderNumber']?.toString() ?? '';
      _startTimeController.text = widget.initialData!['startTime']?.toString() ?? '';
      _endTimeController.text = widget.initialData!['endTime']?.toString() ?? '';
      _downtimeStartController.text = widget.initialData!['downtimeStart']?.toString() ?? '';
      _downtimeEndController.text = widget.initialData!['downtimeEnd']?.toString() ?? '';
      
      final totalDowntime = widget.initialData!['totalDowntime']?.toString();
      if (totalDowntime != null && totalDowntime.isNotEmpty) {
        _totalDowntimeController.text = totalDowntime;
      }
      
      _selectedMachine = widget.initialData!['machineName']?.toString();
      if (_selectedMachine != null && _selectedMachine!.isEmpty) _selectedMachine = null;
      
      _selectedTechnician = widget.initialData!['technicianName']?.toString();
      if (_selectedTechnician != null && _selectedTechnician!.isEmpty) _selectedTechnician = null;
      
      _selectedShift = widget.initialData!['shift']?.toString();
      if (_selectedShift != null && _selectedShift!.isEmpty) _selectedShift = null;

      final crew = widget.initialData!['crewMembers'] ?? widget.initialData!['crew_members'];
      if (crew is List) {
        _selectedCrewMembers.addAll(crew.map((e) => e.toString()));
      }

      final dimensions = widget.initialData!['dimensions'];
      if (dimensions is Map) {
        _lengthController.text = dimensions['length']?.toString() ?? '';
        _widthController.text = dimensions['width']?.toString() ?? '';
        _heightController.text = dimensions['height']?.toString() ?? '';
      } else {
        _lengthController.text = widget.initialData!['length']?.toString() ?? '';
        _widthController.text = widget.initialData!['width']?.toString() ?? '';
        _heightController.text = widget.initialData!['height']?.toString() ?? '';
      }
    }
  }

  List<String> get _shifts {
    try {
      final scheduleBox = Hive.box<DaySchedule>('factory_schedule');
      String dayName = '';
      final dt = DateTime.tryParse(_dateController.text) ?? DateTime.now();
      switch (dt.weekday) {
        case DateTime.monday:
          dayName = 'Monday';
          break;
        case DateTime.tuesday:
          dayName = 'Tuesday';
          break;
        case DateTime.wednesday:
          dayName = 'Wednesday';
          break;
        case DateTime.thursday:
          dayName = 'Thursday';
          break;
        case DateTime.friday:
          dayName = 'Friday';
          break;
        case DateTime.saturday:
          dayName = 'Saturday';
          break;
        case DateTime.sunday:
          dayName = 'Sunday';
          break;
      }

      final schedule = scheduleBox.get(dayName);
      List<String> shiftNames = [];
      if (schedule != null && schedule.shiftNames != null) {
        shiftNames = List<String>.from(schedule.shiftNames!);
      }

      if (shiftNames.isEmpty) {
        shiftNames = ['الوردية الأولى']; // Fallback
      }

      if (_selectedShift != null && !shiftNames.contains(_selectedShift)) {
        shiftNames.add(_selectedShift!);
      }

      return shiftNames;
    } catch (e) {
      return ['الوردية الأولى'];
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedShift == null) {
      final shiftsList = _shifts;
      if (shiftsList.isNotEmpty) {
        _selectedShift = shiftsList.first;
      }
    }
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
      final formattedTimeOfDay = localizations.formatTimeOfDay(pickedTime,
          alwaysUse24HourFormat: true);
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

  String? _formatDateTime(String date, String time) {
    if (time.isEmpty) return null;
    try {
      final parsedDate = DateTime.parse(date);
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(
              parsedDate.year, parsedDate.month, parsedDate.day, hour, minute)
          .toIso8601String();
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final double productionQty =
          double.tryParse(_productionController.text) ?? 0;
      final double wasteQty = double.tryParse(_wasteController.text) ?? 0;

      final syncId = const Uuid().v4();
      final String? factoryId = Hive.isBoxOpen('settings')
          ? Hive.box('settings').get('factory_id')
          : null;

      final currentUser = PermissionHelper.currentWorker;
      final isAdmin = PermissionHelper.isSuperAdmin;
      String reportStatus = 'pending';
      if (isAdmin || (currentUser != null && currentUser.job == 'رئيس القسم')) {
        reportStatus = 'approved';
      }

      final report = StapleProductionReport(
        id: syncId,
        machineName: _selectedMachine ?? '',
        technicianName: _selectedTechnician ?? '',
        reportDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
        customerName: _customerController.text,
        itemName: _itemController.text,
        itemCode: _itemCodeController.text,
        workOrder: _workOrderController.text,
        runTimeStart:
            _formatDateTime(_dateController.text, _startTimeController.text) !=
                    null
                ? DateTime.parse(_formatDateTime(
                    _dateController.text, _startTimeController.text)!)
                : null,
        runTimeEnd: _formatDateTime(
                    _dateController.text, _endTimeController.text) !=
                null
            ? DateTime.parse(
                _formatDateTime(_dateController.text, _endTimeController.text)!)
            : null,
        downtimeStart: _formatDateTime(
                    _dateController.text, _downtimeStartController.text) !=
                null
            ? DateTime.parse(_formatDateTime(
                _dateController.text, _downtimeStartController.text)!)
            : null,
        downtimeEnd: _formatDateTime(
                    _dateController.text, _downtimeEndController.text) !=
                null
            ? DateTime.parse(_formatDateTime(
                _dateController.text, _downtimeEndController.text)!)
            : null,
        productionQuantity: productionQty,
        wasteQuantity: wasteQty,
        notes: _notesController.text,
        factoryId: factoryId,
        dimensions: {
          'length': double.tryParse(_lengthController.text) ?? 0,
          'width': double.tryParse(_widthController.text) ?? 0,
          'height': double.tryParse(_heightController.text) ?? 0,
        },
        crewMembers: _selectedCrewMembers,
        shiftName: _selectedShift,
        status: reportStatus,
      );

      await _saveNewMachineIfNeeded(_selectedMachine ?? '');

      final box = Hive.isBoxOpen('staple_production_reports_box')
          ? Hive.box<StapleProductionReport>('staple_production_reports_box')
          : await Hive.openBox<StapleProductionReport>(
              'staple_production_reports_box');

      await box.put(syncId, report);

      await SyncService.instance.pushToQueue(
        'staple_production_reports',
        {
          'id': report.id,
          'machine_name': report.machineName,
          'technician_name': report.technicianName,
          'report_date': report.reportDate.toIso8601String(),
          'customer_name': report.customerName,
          'item_name': report.itemName,
          'item_code': report.itemCode,
          'work_order': report.workOrder,
          'run_time_start': report.runTimeStart?.toIso8601String(),
          'run_time_end': report.runTimeEnd?.toIso8601String(),
          'downtime_start': report.downtimeStart?.toIso8601String(),
          'downtime_end': report.downtimeEnd?.toIso8601String(),
          'production_quantity': report.productionQuantity,
          'waste_quantity': report.wasteQuantity,
          'notes': report.notes,
          'factory_id': report.factoryId,
          'dimensions': report.dimensions,
          'crew_members': report.crewMembers,
          'shift_name': report.shiftName,
          'status': report.status,
        },
        operation: 'insert',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التقرير بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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

  Future<void> _saveNewMachineIfNeeded(String machineName) async {
    if (machineName.isEmpty) return;
    if (!Hive.isBoxOpen('flexo_machines')) return;
    
    final machinesBox = Hive.box<FlexoMachine>('flexo_machines');
    bool exists = false;
    for (var m in machinesBox.values) {
      if (m.name == machineName && m.department == 'staples') {
        exists = true;
        break;
      }
    }
    
    if (!exists) {
      final newMachineId = const Uuid().v4();
      final newMachine = FlexoMachine(
        id: newMachineId,
        name: machineName,
        department: 'staples',
      );
      await machinesBox.put(newMachineId, newMachine);
      
      final String? factoryId = Hive.isBoxOpen('settings') ? Hive.box('settings').get('factory_id') : null;
      await SyncService.instance.pushToQueue(
        'machines',
        {
          'id': newMachine.id,
          'name': newMachine.name,
          'department': 'staples',
          'factory_id': factoryId,
        },
        operation: 'upsert',
      );
    }
  }

  Future<void> _showAddMachineDialog() async {
    final TextEditingController customMachineController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة ماكينة يدوياً', style: TextStyle(fontFamily: 'Cairo')),
          content: TextField(
            controller: customMachineController,
            decoration: const InputDecoration(
              hintText: 'أدخل اسم الماكينة',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                if (customMachineController.text.trim().isNotEmpty) {
                  setState(() {
                    _selectedMachine = customMachineController.text.trim();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
          prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 20) : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
          prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 20) : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () async {
          final sortedWorkers = WorkerUtils.getSortedWorkers('staples');

          await showDialog(
            context: context,
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setStateDialog) {
                  return AlertDialog(
                    title: const Text('اختر طاقم الماكينة',
                        style: TextStyle(fontFamily: 'Cairo')),
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
                            if (prevWorker.department == normDept &&
                                worker.department != normDept) {
                              showDivider = true;
                            }
                          }

                          final isSelected =
                              _selectedCrewMembers.contains(worker.name);
                          final tile = CheckboxListTile(
                            title: Text('${worker.name} (${worker.job})',
                                style: const TextStyle(fontFamily: 'Cairo')),
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
                                  child: Text('باقي أقسام المصنع',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey)),
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
                        child: const Text('موافق',
                            style: TextStyle(fontFamily: 'Cairo')),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            labelText: 'طاقم الماكينة (اختياري)',
            labelStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
            prefixIcon: const Icon(Icons.group, color: Colors.blueAccent, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0F172A)
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: Colors.blueGrey.withValues(alpha: 0.3)),
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
    final technicianNames =
        sortedWorkers.map((e) => e.name).toSet().toList(); // unique names

    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة تقرير إنتاج - الدبوس',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 1,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Container(
            margin:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  children: [
                    const Text(
                      'بيانات التقرير',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'الوردية',
                            value: _selectedShift,
                            items: _shifts,
                            icon: Icons.work_outline,
                            onChanged: (val) =>
                                setState(() => _selectedShift = val),
                          ),
                        ),
                        const SizedBox(width: 4),
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
                    _buildTextField(_workOrderController, "رقم أمر التشغيل",
                        icon: Icons.assignment,
                        isNumber: true,
                        isRequired: false),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                              _startTimeController, "🕒 وقت البداية",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(_startTimeController),
                              isRequired: false),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildTextField(
                              _endTimeController, "🕒 وقت النهاية",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(_endTimeController),
                              isRequired: false),
                        ),
                      ],
                    ),
                    _buildTextField(_customerController, "👤 اسم العميل",
                        icon: Icons.business),
                    _buildTextField(_itemController, "📦 الصنف",
                        icon: Icons.category),
                    _buildTextField(_itemCodeController, "كود الصنف",
                        icon: Icons.qr_code, isNumber: true, isRequired: false),
                    Row(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<Box<FlexoMachine>>(
                              valueListenable:
                                  Hive.box<FlexoMachine>('flexo_machines')
                                      .listenable(),
                              builder: (context, box, _) {
                                final machineNames =
                                    FlexoMachine.getMachinesForDepartment(
                                            'staples')
                                        .map((m) => m.name)
                                        .toSet()
                                        .toList();
                                if (machineNames.isEmpty) {
                                  machineNames.add('دباسة (افتراضي)');
                                }

                                if (_selectedMachine != null &&
                                    !machineNames.contains(_selectedMachine)) {
                                  machineNames.add(_selectedMachine!);
                                }
                                
                                machineNames.add('+ إضافة ماكينة يدوياً');

                                return _buildDropdown(
                                  label: 'الماكينة',
                                  value: _selectedMachine,
                                  items: machineNames,
                                  icon: Icons.precision_manufacturing,
                                  onChanged: (val) {
                                    if (val == '+ إضافة ماكينة يدوياً') {
                                      _showAddMachineDialog();
                                    } else {
                                      setState(() {
                                        _selectedMachine = val;
                                      });
                                    }
                                  },
                                );
                              }),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildDropdown(
                            label: 'اسم الفني',
                            value: _selectedTechnician,
                            items: technicianNames,
                            icon: Icons.person,
                            onChanged: (val) =>
                                setState(() => _selectedTechnician = val),
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
                        const SizedBox(width: 4),
                        Expanded(
                            child: _buildTextField(_widthController, "📏 عرض",
                                isNumber: true)),
                        const SizedBox(width: 4),
                        Expanded(
                            child: _buildTextField(
                                _heightController, "📏 ارتفاع",
                                isNumber: true)),
                      ],
                    ),
                    _buildTextField(_productionController, "🔢 عدد الشيتات",
                        isNumber: true, icon: Icons.check_circle_outline),
                    _buildTextField(_wasteController, "📉 الهالك",
                        isNumber: true,
                        isRequired: false,
                        icon: Icons.delete_outline),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                              _downtimeStartController, "⏱️ بداية العطل",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () =>
                                  _selectTime(_downtimeStartController),
                              isRequired: false),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildTextField(
                              _downtimeEndController, "⏱️ نهاية العطل",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: () => _selectTime(_downtimeEndController),
                              isRequired: false),
                        ),
                      ],
                    ),
                    _buildTextField(
                        _totalDowntimeController, "⏳ إجمالي دقائق التعطل",
                        icon: Icons.timer_off,
                        isNumber: true,
                        isRequired: false),
                    _buildTextField(_notesController, "📝 ملاحظات (اختياري)",
                        icon: Icons.notes, isRequired: false, maxLines: 3),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side:
                                    BorderSide(color: Colors.blueGrey.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
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
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'حفظ التقرير',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ),
                      ],
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
