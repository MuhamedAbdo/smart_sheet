// lib/src/screens/flexo/flexo_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/screens/calculator_screen.dart';
import 'package:smart_sheet/screens/color_palette_screen.dart';
import 'package:smart_sheet/screens/production_report_screen.dart';
import 'package:smart_sheet/screens/maintenance_screen.dart';
import 'package:smart_sheet/screens/serial_setup_screen.dart';
import 'package:smart_sheet/screens/store_entry_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:smart_sheet/screens/machine_management_screen.dart';
// ✅ أضف هذا السطر لاستيراد شاشة البالتة

// ✅ استيراد الشاشات

import 'package:smart_sheet/widgets/home_button.dart';
import 'package:smart_sheet/widgets/flexo_report_drawer.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';

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
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      drawer: const AppDrawer(),
      endDrawer: const FlexoReportDrawer(),
      // ✅ الـ Drawer متاح في كل الشاشات
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // عنوان فوق الأزرار
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                'اختر القسم الذي تريد العمل فيه :',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 2;
                  if (constraints.maxWidth > 1000) {
                    crossAxisCount = 5;
                  } else if (constraints.maxWidth > 700) {
                    crossAxisCount = 4;
                  } else if (constraints.maxWidth > 500) {
                    crossAxisCount = 3;
                  }

                  return Scrollbar(
                    thumbVisibility: true,
                    child: GridView.count(
                      primary: true,
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 1.1,
                      children: [
                        HomeButton(
                          icon: Icons.print_outlined,
                          label: 'تقارير الماكينات',
                          onTap: () {
                            Scaffold.of(context).openEndDrawer();
                          },
                        ),
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
                        label: 'تقرير الإنتاج',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductionReportScreen(),
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
                                boxName: 'maintenance_flexo_v2',
                                title: 'صيانة الفلكسو',
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
                        label: 'طاقم الفلكسو',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WorkersScreen(
                                departmentBoxName: 'workers_flexo',
                                departmentTitle: 'طاقم الفلكسو',
                              ),
                            ),
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.precision_manufacturing,
                        label: 'إدارة الماكينات',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MachineManagementScreen(),
                            ),
                          );
                        },
                      ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
