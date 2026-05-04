// lib/src/screens/production/production_line_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/screens/calculator_screen.dart';
import 'package:smart_sheet/screens/maintenance_screen.dart';
import 'package:smart_sheet/screens/new_sheet_size_screen.dart';
import 'package:smart_sheet/screens/sheet_count_screen.dart';
import 'package:smart_sheet/screens/store_entry_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:smart_sheet/widgets/home_button.dart';

// ✅ استيراد الشاشات

class ProductionLineScreen extends StatelessWidget {
  const ProductionLineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'خط الإنتاج',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 1,
      ),
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

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: 1.1,
                    children: [
                      HomeButton(
                        icon: Icons.straighten,
                        label: 'مقاس الشيت',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NewSheetSizeScreen(),
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
                        icon: Icons.inventory,
                        label: 'وارد المخزن',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StoreEntryScreen(
                                boxName: 'store_production',
                                title: 'وارد مخزن خط الإنتاج',
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
                                boxName: 'maintenance_production_v2',
                                title: 'صيانة خط الإنتاج',
                              ),
                            ),
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.group,
                        label: 'طاقم خط الإنتاج',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WorkersScreen(
                                departmentBoxName: 'workers_production',
                                departmentTitle: 'طاقم خط الإنتاج',
                              ),
                            ),
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.production_quantity_limits,
                        label: 'عدد الشيتات',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SheetCountScreen(),
                            ),
                          );
                        },
                      ),
                    ],
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
