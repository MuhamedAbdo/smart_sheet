// lib/src/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:smart_sheet/screens/crushing_screen.dart';
import 'package:smart_sheet/screens/flexo_screen.dart';
import 'package:smart_sheet/screens/production_line_screen.dart';
import 'package:smart_sheet/screens/saved_sizes_screen.dart';
import 'package:smart_sheet/screens/add_sheet_size_screen.dart';
import 'package:smart_sheet/screens/staple_department_screen.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/home_button.dart';
import 'package:smart_sheet/utils/ui_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeScreenState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWindows = !kIsWeb && Platform.isWindows;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Sheet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: isWindows ? null : const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                'اختر القسم الذي تريد العمل فيه :',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.primary,
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
                        icon: Icons.factory,
                        label: 'خط الإنتاج',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductionLineScreen(),
                            ),
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.print,
                        label: 'الفلكسو',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FlexoScreen(),
                            ),
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.cut,
                        label: 'التكسير',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CrushingScreen(),
                            ),
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.push_pin,
                        label: 'الدبوس',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StapleDepartmentScreen(),
                            ),
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.science,
                        label: 'السليكات',
                        onTap: () {
                          UIUtils.showInfoSnackBar(
                            message: 'سيتم تطويره قريبًا',
                            backgroundColor: Colors.blueGrey,
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.warehouse,
                        label: 'المخازن',
                        onTap: () {
                          UIUtils.showInfoSnackBar(
                            message: 'سيتم تطويره قريبًا',
                            backgroundColor: Colors.blueGrey,
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.add,
                        label: 'إضافة عميل جديد',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddSheetSizeScreen(),
                            ),
                          );
                        },
                      ),
                      HomeButton(
                        icon: Icons.save,
                        label: 'سجل العملاء',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SavedSizesScreen(),
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
