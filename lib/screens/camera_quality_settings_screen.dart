// lib/src/screens/settings/camera_quality_settings_screen.dart

import 'package:flutter/material.dart';

class CameraQualitySettingsScreen extends StatelessWidget {
  static const String routeName = '/camera-quality';

  const CameraQualitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("جودة الكاميرا"),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("عالية"),
            subtitle: const Text("جودة عالية - حجم ملف كبير"),
            trailing: const Icon(Icons.check),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم اختيار الجودة العالية')),
              );
            },
          ),
          ListTile(
            title: const Text("متوسطة"),
            subtitle: const Text("جودة متوسطة - توازن بين الحجم والجودة"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم اختيار الجودة المتوسطة')),
              );
            },
          ),
          ListTile(
            title: const Text("منخفضة"),
            subtitle: const Text("جودة منخفضة - حجم ملف صغير"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم اختيار الجودة المنخفضة')),
              );
            },
          ),
        ],
      ),
    );
  }
}
