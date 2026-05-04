// lib/src/screens/flexo/serial_setup_screen.dart

// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/results_widget.dart';

class SerialSetupScreen extends StatefulWidget {
  const SerialSetupScreen({super.key});

  @override
  _SerialSetupScreenState createState() => _SerialSetupScreenState();
}

class _SerialSetupScreenState extends State<SerialSetupScreen> {
  // متغيرات تبويب جنزير
  final TextEditingController lengthController = TextEditingController();
  final TextEditingController widthController = TextEditingController();
  final TextEditingController bladeController = TextEditingController();

  bool isWidthActive = true;
  double? a1, t1, a2, t2;

  // متغيرات تبويب أوتوماتيك
  final TextEditingController autoLengthController = TextEditingController();
  final TextEditingController autoWidthController = TextEditingController();

  bool autoIsWidthActive = true;
  double? autoA1, autoT1, autoA2, autoT2;

  // Hive box للحالة
  late Box _stateBox;

  String convertToWesternNumbers(String input) {
    const arabicToWestern = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9'
    };
    return input.split('').map((char) => arabicToWestern[char] ?? char).join();
  }

  // حساب جنزير
  void calculateValues() {
    final double length =
        double.tryParse(convertToWesternNumbers(lengthController.text)) ?? 0.0;
    final double width =
        double.tryParse(convertToWesternNumbers(widthController.text)) ?? 0.0;
    final double blade =
        double.tryParse(convertToWesternNumbers(bladeController.text)) ?? 0.0;

    if (isWidthActive) {
      a1 = blade + (width / 2);
      t1 = blade + width + (length / 2);
      a2 = blade + width + length + (width / 2);
      t2 = blade + width + length + width + (length / 2);
    } else {
      t1 = blade + (length / 2);
      a1 = blade + length + (width / 2);
      t2 = blade + length + width + (length / 2);
      a2 = blade + length + width + length + (width / 2);
    }

    setState(() {});
    saveState();
  }

  // حساب أوتوماتيك
  void calculateAutoValues() {
    final double length =
        double.tryParse(convertToWesternNumbers(autoLengthController.text)) ??
            0.0;
    final double width =
        double.tryParse(convertToWesternNumbers(autoWidthController.text)) ??
            0.0;

    if (autoIsWidthActive) {
      autoA1 = length + (width / 2);
      autoT1 = length / 2;
      autoA2 = width / 2;
      autoT2 = width + (length / 2);
    } else {
      autoT1 = width + (length / 2);
      autoA1 = width / 2;
      autoT2 = length / 2;
      autoA2 = length + (width / 2);
    }

    setState(() {});
    saveState();
  }

  void toggleCheckbox(bool? value) {
    setState(() {
      isWidthActive = value ?? true;
      calculateValues();
    });
  }

  void toggleAutoCheckbox(bool? value) {
    setState(() {
      autoIsWidthActive = value ?? true;
      calculateAutoValues();
    });
  }

  void clearFields() {
    setState(() {
      lengthController.clear();
      widthController.clear();
      bladeController.clear();
      a1 = null;
      t1 = null;
      a2 = null;
      t2 = null;
      isWidthActive = true;
    });
    saveState();
  }

  void clearAutoFields() {
    setState(() {
      autoLengthController.clear();
      autoWidthController.clear();
      autoA1 = null;
      autoT1 = null;
      autoA2 = null;
      autoT2 = null;
      autoIsWidthActive = true;
    });
    saveState();
  }

  void hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    if (!Hive.isBoxOpen('serial_setup_state')) {
      await Hive.openBox('serial_setup_state');
    }
    _stateBox = Hive.box('serial_setup_state');
    restoreState();
  }

  void restoreState() {
    final state = _stateBox.get('state');
    if (state != null) {
      setState(() {
        lengthController.text = state['length'] ?? '';
        widthController.text = state['width'] ?? '';
        bladeController.text = state['blade'] ?? '';
        a1 = state['a1'];
        t1 = state['t1'];
        a2 = state['a2'];
        t2 = state['t2'];
        isWidthActive = state['isWidthActive'] ?? true;

        autoLengthController.text = state['autoLength'] ?? '';
        autoWidthController.text = state['autoWidth'] ?? '';
        autoA1 = state['autoA1'];
        autoT1 = state['autoT1'];
        autoA2 = state['autoA2'];
        autoT2 = state['autoT2'];
        autoIsWidthActive = state['autoIsWidthActive'] ?? true;
      });
    }
  }

  void saveState() {
    final state = {
      'length': lengthController.text,
      'width': widthController.text,
      'blade': bladeController.text,
      'a1': a1,
      't1': t1,
      'a2': a2,
      't2': t2,
      'isWidthActive': isWidthActive,
      'autoLength': autoLengthController.text,
      'autoWidth': autoWidthController.text,
      'autoA1': autoA1,
      'autoT1': autoT1,
      'autoA2': autoA2,
      'autoT2': autoT2,
      'autoIsWidthActive': autoIsWidthActive,
    };
    _stateBox.put('state', state);
  }

  @override
  void dispose() {
    saveState();
    lengthController.dispose();
    widthController.dispose();
    bladeController.dispose();
    autoLengthController.dispose();
    autoWidthController.dispose();
    super.dispose();
  }

  Widget _buildAutoOutput(String label, double? value, BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minWidth: 70),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blue.withValues(alpha: 0.15)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDarkMode ? Colors.blue.shade800 : Colors.blue.shade200,
            width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.blue.shade300 : Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value?.toStringAsFixed(2) ?? '--',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChainTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: lengthController,
            decoration: const InputDecoration(
              labelText: 'أدخل الطول',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => calculateValues(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widthController,
            decoration: const InputDecoration(
              labelText: 'أدخل العرض',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => calculateValues(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: bladeController,
            decoration: const InputDecoration(
              labelText: 'أدخل السلاح الأول',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => calculateValues(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Checkbox(
                value: isWidthActive,
                onChanged: toggleCheckbox,
              ),
              const Text('اللسان في العرض'),
              const SizedBox(width: 20),
              Checkbox(
                value: !isWidthActive,
                onChanged: (value) => toggleCheckbox(!value!),
              ),
              const Text('اللسان في الطول'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: calculateValues,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'حساب',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: clearFields,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'مسح الحقول',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26.withValues(alpha: 0.1),
                  offset: const Offset(0, 4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: ResultsWidget(
              a1: isWidthActive ? a1 : t1,
              t1: isWidthActive ? t1 : a1,
              a2: isWidthActive ? a2 : t2,
              t2: isWidthActive ? t2 : a2,
              isWidthActive: isWidthActive,
              labels: isWidthActive
                  ? ["ع1", "ط1", "ع2", "ط2"]
                  : ["ط1", "ع1", "ط2", "ع2"],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: autoLengthController,
            decoration: const InputDecoration(
              labelText: 'أدخل الطول',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => calculateAutoValues(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: autoWidthController,
            decoration: const InputDecoration(
              labelText: 'أدخل العرض',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => calculateAutoValues(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Checkbox(
                value: autoIsWidthActive,
                onChanged: toggleAutoCheckbox,
              ),
              const Text('اللسان في العرض'),
              const SizedBox(width: 20),
              Checkbox(
                value: !autoIsWidthActive,
                onChanged: (value) => toggleAutoCheckbox(!value!),
              ),
              const Text('اللسان في الطول'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: calculateAutoValues,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'حساب',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: clearAutoFields,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'مسح الحقول',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26.withValues(alpha: 0.1),
                    offset: const Offset(0, 4),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // اليمين
                    if (autoIsWidthActive) ...[
                      _buildAutoOutput("ع1", autoA1, context),
                      const SizedBox(width: 8),
                      _buildAutoOutput("ط1", autoT1, context),
                    ] else ...[
                      _buildAutoOutput("ط1", autoT1, context),
                      const SizedBox(width: 8),
                      _buildAutoOutput("ع1", autoA1, context),
                    ],

                    const SizedBox(width: 16),

                    // 3 dividers
                    _buildDividers(context),

                    const SizedBox(width: 16),

                    // اليسار
                    if (autoIsWidthActive) ...[
                      _buildAutoOutput("ع2", autoA2, context),
                      const SizedBox(width: 8),
                      _buildAutoOutput("ط2", autoT2, context),
                    ] else ...[
                      _buildAutoOutput("ط2", autoT2, context),
                      const SizedBox(width: 8),
                      _buildAutoOutput("ع2", autoA2, context),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDividers(BuildContext context) {
    final Color dividerColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade600
        : Colors.grey.shade300;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 2, height: 60, color: dividerColor),
        const SizedBox(width: 3),
        Container(width: 2, height: 60, color: dividerColor),
        const SizedBox(width: 3),
        Container(width: 2, height: 60, color: dividerColor),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("ضبط تركيب السيريل"),
          centerTitle: true,
          elevation: 1,
          bottom: const TabBar(
            tabs: [
              Tab(text: "جنزير"),
              Tab(text: "أوتوماتيك"),
            ],
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        body: GestureDetector(
          onTap: hideKeyboard,
          child: TabBarView(
            children: [
              _buildChainTab(),
              _buildAutoTab(),
            ],
          ),
        ),
      ),
    );
  }
}
