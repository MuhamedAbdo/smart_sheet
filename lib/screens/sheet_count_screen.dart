// lib/src/screens/sheet_count/sheet_count_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';

class SheetCountScreen extends StatefulWidget {
  const SheetCountScreen({super.key});

  @override
  State<SheetCountScreen> createState() => _SheetCountScreenState();
}

class _SheetCountScreenState extends State<SheetCountScreen> {
  late Box settingsBox;
  bool isDarkTheme = false;

  final TextEditingController firstSheetLengthController =
      TextEditingController();
  final TextEditingController firstSheetCountController =
      TextEditingController();
  final TextEditingController secondSheetLengthController =
      TextEditingController();

  String result = '';

  @override
  void initState() {
    super.initState();
    settingsBox = Hive.box('settings');
    isDarkTheme = settingsBox.get('isDarkTheme', defaultValue: false);
  }

  void _calculateSheetCount() {
    double firstLength = double.tryParse(
            _convertToEnglishNumbers(firstSheetLengthController.text)) ??
        0.0;
    int firstCount = int.tryParse(
            _convertToEnglishNumbers(firstSheetCountController.text)) ??
        0;
    double secondLength = double.tryParse(
            _convertToEnglishNumbers(secondSheetLengthController.text)) ??
        1.0;

    if (secondLength == 0) {
      setState(() {
        result = 'خطأ: طول الشيت الثاني لا يمكن أن يكون صفرًا';
      });
      return;
    }

    int secondCount = ((firstLength * firstCount) / secondLength).toInt();

    setState(() {
      result = 'عدد الشيتات الثاني: $secondCount';
    });
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  String _convertToEnglishNumbers(String input) {
    return input
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
  }

  @override
  void dispose() {
    firstSheetLengthController.dispose();
    firstSheetCountController.dispose();
    secondSheetLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('عدد الشيتات'),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: _hideKeyboard,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: firstSheetLengthController,
                decoration: const InputDecoration(
                  labelText: 'طول الشيت الأول (سم)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.straighten),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: firstSheetCountController,
                decoration: const InputDecoration(
                  labelText: 'عدد الشيتات الأول',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secondSheetLengthController,
                decoration: const InputDecoration(
                  labelText: 'طول الشيت الثاني (سم)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.straighten),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _calculateSheetCount,
                  icon: const Icon(Icons.calculate),
                  label:
                      const Text('احسب العدد', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (result.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      result,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
