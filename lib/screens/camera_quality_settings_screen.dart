// lib/src/screens/settings/camera_quality_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/utils/ui_utils.dart';

class CameraQualitySettingsScreen extends StatefulWidget {
  static const String routeName = '/camera-quality';

  const CameraQualitySettingsScreen({super.key});

  @override
  State<CameraQualitySettingsScreen> createState() =>
      _CameraQualitySettingsScreenState();
}

class _CameraQualitySettingsScreenState
    extends State<CameraQualitySettingsScreen> {
  // الجودات المتاحة
  final List<String> qualities = ['منخفضة', 'متوسطة', 'عالية'];
  final List<String> descriptions = [
    'جودة منخفضة - حجم ملف صغير',
    'جودة متوسطة - توازن بين الحجم والجودة',
    'جودة عالية - حجم ملف كبير',
  ];

  String? _selectedQuality;

  // اسم صندوق Hive
  static const String boxName = 'settings';
  static const String key = 'camera_quality';

  @override
  void initState() {
    super.initState();
    _loadSavedQuality();
  }

  Future<void> _loadSavedQuality() async {
    final box = await Hive.openBox(boxName);
    setState(() {
      _selectedQuality = box.get(key, defaultValue: 'متوسطة'); // افتراضي
    });
  }

  Future<void> _saveQuality(String quality) async {
    final box = await Hive.openBox(boxName);
    await box.put(key, quality);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("جودة الكاميرا"),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box(boxName).listenable(),
        builder: (context, box, widget) {
          return ListView.builder(
            itemCount: qualities.length,
            itemBuilder: (context, index) {
              final quality = qualities[index];
              final description = descriptions[index];

              // ignore: deprecated_member_use
              return RadioListTile<String>(
                title: Text(quality),
                subtitle: Text(description),
                value: quality,
                // ignore: deprecated_member_use
                groupValue: _selectedQuality,
                // ignore: deprecated_member_use
                onChanged: (value) async {
                  if (value != null) {
                    setState(() {
                      _selectedQuality = value;
                    });
                    await _saveQuality(value);
                    // إظهار تنبيه اختياري
                    UIUtils.showInfoSnackBar(
                      message: "تم اختيار جودة: $value",
                      backgroundColor: Colors.green,
                      icon: Icons.check_circle_outline,
                    );
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          );
        },
      ),
    );
  }
}
