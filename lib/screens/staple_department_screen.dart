// lib/src/screens/staple/staple_department_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/screens/calculator_screen.dart';
import 'package:smart_sheet/screens/finished_product_screen.dart';
import 'package:smart_sheet/screens/maintenance_screen.dart';
import 'package:smart_sheet/screens/store_entry_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:smart_sheet/widgets/home_button.dart';

class StapleDepartmentScreen extends StatelessWidget {
  const StapleDepartmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'قسم الدبوس',
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
                        icon: Icons.check_circle,
                        label: 'المنتج التام',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FinishedProductScreen(),
                            ),
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.people,
                        label: 'طاقم الدبوس',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WorkersScreen(
                                departmentBoxName: 'workers_staple',
                                departmentTitle: 'طاقم الدبوس',
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
                        icon: Icons.settings,
                        label: 'الصيانة',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MaintenanceScreen(
                                boxName: 'maintenance_staple_v2',
                                title: 'صيانة الدبوس',
                              ),
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
                                boxName: 'store_staple',
                                title: 'وارد مخزن الدبوس',
                              ),
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
