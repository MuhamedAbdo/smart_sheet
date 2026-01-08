// lib/src/screens/flexo/flexo_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/screens/calculator_screen.dart';
import 'package:smart_sheet/screens/color_palette_screen.dart';
import 'package:smart_sheet/screens/ink_report_screen.dart';
import 'package:smart_sheet/screens/maintenance_screen.dart';
import 'package:smart_sheet/screens/serial_setup_screen.dart';
import 'package:smart_sheet/screens/store_entry_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
// ✅ أضف هذا السطر لاستيراد شاشة البالتة

// ✅ استيراد الشاشات

import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/home_button.dart';

class FlexoScreen extends StatelessWidget {
  const FlexoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الفلكسو',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const AppDrawer(), // ✅ الـ Drawer متاح في كل الشاشات
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // عنوان فوق الأزرار
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.green.shade50,
              child: const Text(
                'اختر القسم الذي تريد العمل فيه :',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  HomeButton(
                    icon: Icons.build_circle,
                    label: 'تركيب السيريل',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SerialSetupScreen(),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.receipt,
                    label: 'تقرير الأحبار',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InkReportScreen(),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.inventory,
                    label: 'وارد المخزن',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StoreEntryScreen(
                            boxName: 'store_flexo',
                            title: 'وارد مخزن الفلكسو',
                          ),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.settings,
                    label: 'الصيانة',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MaintenanceScreen(
                            // ✅ أضف المعلمات المطلوبة
                            boxName:
                                'maintenance_flexo_v2', // <-- اسم الصندوق الخاص بـ Flexo
                            title: 'صيانة الفلكسو', // <-- عنوان الشاشة
                          ),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.calculate,
                    label: 'الآلة الحاسبة',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalculatorScreen(),
                        ),
                      );
                    },
                  ),
                  // ✅ أضف هذا الزر الجديد
                  HomeButton(
                    icon: Icons.palette,
                    label: 'بالتة الألوان',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ColorPaletteScreen(),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.group,
                    label: 'طاقم الفلكسو', // ✅ تغيير التسمية
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WorkersScreen(
                            // ← استخدام WorkersScreen الجديد
                            departmentBoxName:
                                'workers_flexo', // ✅ اسم الصندوق المخصص
                            departmentTitle: 'طاقم الفلكسو', // ✅ عنوان القسم
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
