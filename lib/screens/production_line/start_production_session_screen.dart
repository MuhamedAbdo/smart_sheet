// lib/screens/production_line/start_production_session_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:smart_sheet/services/server_time_service.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/utils/device_manager.dart';
import 'package:smart_sheet/utils/permission_helper.dart';

class StartProductionSessionScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const StartProductionSessionScreen({super.key, this.initialData});

  @override
  State<StartProductionSessionScreen> createState() =>
      _StartProductionSessionScreenState();
}

class _StartProductionSessionScreenState
    extends State<StartProductionSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientController = TextEditingController();
  final _productController = TextEditingController();
  final _productCodeController = TextEditingController();
  final _orderNumberController = TextEditingController();
  final _techController = TextEditingController();
  final List<TextEditingController> _paperLayerControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  String? _selectedMachine;
  String _selectedShift = 'صباحية';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initDefaultMachine();
    if (widget.initialData != null) {
      _clientController.text =
          widget.initialData!['clientName']?.toString() ?? '';
      _productController.text =
          widget.initialData!['productName']?.toString() ??
              widget.initialData!['product']?.toString() ??
              '';
      _productCodeController.text =
          widget.initialData!['productCode']?.toString() ?? '';
      _orderNumberController.text =
          widget.initialData!['orderNumber']?.toString() ?? '';
      if (widget.initialData!['paperLayers'] is List) {
        final layers = (widget.initialData!['paperLayers'] as List)
            .map((e) => e.toString())
            .toList();
        if (layers.isNotEmpty) {
          _paperLayerControllers.clear();
          for (var layer in layers) {
            _paperLayerControllers.add(TextEditingController(text: layer));
          }
        }
      }
    }
  }

  void _initDefaultMachine() {
    final machines = FlexoMachine.getMachinesForDepartment('production_line');
    if (machines.isNotEmpty) {
      _selectedMachine = machines.first.name;
    }
  }

  void _addPaperLayer() {
    setState(() {
      _paperLayerControllers.add(TextEditingController());
    });
  }

  void _removePaperLayer(int index) {
    if (_paperLayerControllers.length > 1) {
      setState(() {
        _paperLayerControllers[index].dispose();
        _paperLayerControllers.removeAt(index);
      });
    }
  }

  @override
  void dispose() {
    _clientController.dispose();
    _productController.dispose();
    _productCodeController.dispose();
    _orderNumberController.dispose();
    _techController.dispose();
    for (var controller in _paperLayerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_selectedMachine == null || _clientController.text.trim().isEmpty) {
      UIUtils.showInfoSnackBar(
        message: 'يرجى اختيار الماكينة وإدخال اسم العميل على الأقل',
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sessionId = const Uuid().v4();
      final fId = await SupabaseManager.getFactoryId();
      final deviceId = await DeviceManager.getDeviceId();

      String? techId = PermissionHelper.currentWorker?.id;
      if (techId == null && Hive.isBoxOpen('workers_production')) {
        try {
          techId = Hive.box<Worker>('workers_production').values.firstWhere(
                (w) =>
                    w.name.trim().toLowerCase() ==
                    _techController.text.trim().toLowerCase(),
              ).id;
        } catch (_) {}
      }

      final layersList = _paperLayerControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final session = LiveSession(
        id: sessionId,
        machineName: _selectedMachine!,
        clientName: _clientController.text.trim(),
        productName: _productController.text.trim(),
        productCode: _productCodeController.text.trim(),
        orderNumber: _orderNumberController.text.trim(),
        technicianName: _techController.text.trim(),
        startTime: ServerTimeService.nowUtc,
        downtimeIntervals: [],
        lastStateChange: ServerTimeService.nowUtc,
        isRunning: true,
        dimensions: widget.initialData?['dimensions'],
        isSheet: widget.initialData?['isSheet'] ?? false,
        imagePaths:
            List<String>.from(widget.initialData?['imagePaths'] ?? []),
        factoryId: fId,
        createdByDeviceId: deviceId,
        technicianId: techId,
        department: 'production_line',
        shift: _selectedShift,
        paperLayers: layersList,
      );

      // حفظ في صندوق جلسات التشغيل
      final liveBox = Hive.isBoxOpen('flexo_live_sessions')
          ? Hive.box<LiveSession>('flexo_live_sessions')
          : await Hive.openBox<LiveSession>('flexo_live_sessions');
      await liveBox.put(sessionId, session);

      if (Hive.isBoxOpen('live_sessions')) {
        await Hive.box<LiveSession>('live_sessions').put(sessionId, session);
      }

      // إرسال لقائمة المزامنة
      await SyncService.instance.pushToQueue(
        'live_sessions',
        session.toJson(),
        operation: 'upsert',
      );

      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: '⚡ تم بدء تشغيل خط الإنتاج بنجاح ($_selectedShift)',
          backgroundColor: Colors.green,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: 'حدث خطأ أثناء بدء الجلسة: $e',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final machines = FlexoMachine.getMachinesForDepartment('production_line');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '🚀 بدء تشغيل خط الإنتاج',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 1,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(theme),
                  const SizedBox(height: 16),
                  _buildMachineSection(theme, machines),
                  const SizedBox(height: 16),
                  _buildShiftSelector(theme),
                  const SizedBox(height: 16),
                  _buildOrderInfoCard(theme),
                  const SizedBox(height: 16),
                  _buildPaperLayersCard(theme),
                  const SizedBox(height: 16),
                  _buildCrewSection(theme),
                  const SizedBox(height: 24),
                  _buildSubmitButton(theme),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.precision_manufacturing,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جلسة تقرير خط الإنتاج',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'أدخل تفاصيل الأوردر لبدء المتابعة الحية للإنتاج وتوقفات الماكينة',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineSection(
      ThemeData theme, List<FlexoMachine> machines) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.factory,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'اختيار خط الإنتاج / الماكينة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedMachine,
              decoration: InputDecoration(
                labelText: 'الماكينة / الخط',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              items: machines
                  .map((m) => DropdownMenuItem(
                        value: m.name,
                        child: Text(m.name),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMachine = val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSelector(ThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final startStr = themeProvider.shiftStart.format(context);
    final endStr = themeProvider.shiftEnd.format(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'تحديد الوردية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildShiftChip(
                    title: 'وردية صباحية ☀️',
                    subtitle: '$startStr - $endStr',
                    value: 'صباحية',
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildShiftChip(
                    title: 'وردية مسائية 🌙',
                    subtitle: '$endStr - $startStr',
                    value: 'مسائية',
                    theme: theme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftChip({
    required String title,
    required String subtitle,
    required String value,
    required ThemeData theme,
  }) {
    final isSelected = _selectedShift == value;
    return InkWell(
      onTap: () => setState(() => _selectedShift = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'بيانات أمر التشغيل والصنف',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _clientController,
              label: 'اسم العميل *',
              icon: Icons.person,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _productController,
              label: 'اسم الصنف',
              icon: Icons.inventory,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _productCodeController,
                    label: 'كود الصنف',
                    icon: Icons.qr_code,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _orderNumberController,
                    label: 'رقم أمر التشغيل',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperLayersCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.layers,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'أنواع و طبقات الورق',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _addPaperLayer,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('إضافة طبقة'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'أدخل أنواع الورق لكل طبقة (طبقة 1، طبقة 2...) المكونة للكرتون:',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_paperLayerControllers.length, (index) {
              final label = index == 0
                  ? 'الطبقة 1 (الوجه الخارجي)'
                  : index == 1
                      ? 'الطبقة 2 (الفلوت)'
                      : 'الطبقة ${index + 1}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _paperLayerControllers[index],
                        label: label,
                        icon: Icons.article_outlined,
                      ),
                    ),
                    if (_paperLayerControllers.length > 1) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => _removePaperLayer(index),
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.redAccent),
                        tooltip: 'حذف الطبقة',
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCrewSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'طاقم الوردية / الفني المسؤول',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildWorkerAutocomplete(),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerAutocomplete() {
    List<String> workersList = [];
    if (Hive.isBoxOpen('workers_production')) {
      final box = Hive.box<Worker>('workers_production');
      workersList = box.values.map((w) => w.name.trim()).toSet().toList();
    }

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return workersList;
        return workersList.where(
          (option) =>
              option.toLowerCase().contains(value.text.toLowerCase()),
        );
      },
      onSelected: (selection) {
        _techController.text = selection;
      },
      fieldViewBuilder:
          (context, controller, focusNode, onEditingComplete) {
        if (_techController.text.isNotEmpty && controller.text.isEmpty) {
          controller.text = _techController.text;
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (val) => _techController.text = val,
          decoration: InputDecoration(
            labelText: 'اختر أو اكتب اسم الفني / العامل',
            prefixIcon: const Icon(Icons.engineering),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
        ),
        onPressed: _isLoading ? null : _startSession,
        icon: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow, size: 26),
        label: Text(
          _isLoading ? 'جاري بدء الجلسة...' : 'بدء الجلسة الحية الآن ⚡',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
