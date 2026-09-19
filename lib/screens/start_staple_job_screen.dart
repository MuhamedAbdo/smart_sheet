import 'package:flutter/material.dart';
import 'package:smart_sheet/utils/worker_utils.dart';

class StartStapleJobScreen extends StatefulWidget {
  const StartStapleJobScreen({super.key});

  @override
  State<StartStapleJobScreen> createState() => _StartStapleJobScreenState();
}

class _StartStapleJobScreenState extends State<StartStapleJobScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _selectedMachine;
  String? _selectedTechnician;
  
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _itemCodeController = TextEditingController();
  final TextEditingController _workOrderController = TextEditingController();
  
  final List<String> _selectedCrewMembers = [];
  
  final List<String> machines = ['دباسة 1', 'دباسة 2', 'تعبئة وتغليف'];

  @override
  void dispose() {
    _customerController.dispose();
    _itemController.dispose();
    _itemCodeController.dispose();
    _workOrderController.dispose();
    super.dispose();
  }

  Future<void> _startJob() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    // TODO: Add backend logic for starting a job for staple department
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم بدء التشغيل بنجاح! ⚡'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    bool isNumber = false,
    bool isRequired = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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
      padding: const EdgeInsets.only(bottom: 24.0),
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
                            if (prevWorker.department == 'staples' && worker.department != 'staples') {
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
          setState(() {}); 
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
    final technicianNames = sortedWorkers.map((e) => e.name).toSet().toList(); 

    return Scaffold(
      appBar: AppBar(
        title: const Text('بدء تشغيل — الدبوس', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      'بيانات التشغيل',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'الماكينة',
                      value: _selectedMachine,
                      items: machines,
                      icon: Icons.precision_manufacturing,
                      onChanged: (val) => setState(() => _selectedMachine = val),
                    ),
                    _buildTextField(_customerController, "👤 اسم العميل", icon: Icons.business),
                    _buildTextField(_itemController, "📦 الصنف", icon: Icons.category),
                    _buildTextField(_itemCodeController, "كود الصنف", icon: Icons.qr_code, isNumber: true, isRequired: false),
                    _buildTextField(_workOrderController, "رقم أمر التشغيل", icon: Icons.assignment, isNumber: true),
                    _buildDropdown(
                      label: 'اسم الفني (رئيسي)',
                      value: _selectedTechnician,
                      items: technicianNames,
                      icon: Icons.person,
                      onChanged: (val) => setState(() => _selectedTechnician = val),
                    ),
                    _buildCrewMembersSelector(),
                    SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _startJob,
                        icon: _isLoading 
                          ? const SizedBox.shrink() 
                          : const Icon(Icons.flash_on, size: 28),
                        label: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'ابدأ التشغيل الآن ⚡',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
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
