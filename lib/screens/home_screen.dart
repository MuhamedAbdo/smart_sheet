// lib/src/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/screens/crushing_screen.dart';
import 'package:smart_sheet/screens/flexo_screen.dart';
import 'package:smart_sheet/screens/production_line_screen.dart';
import 'package:smart_sheet/screens/saved_sizes_screen.dart';
import 'package:smart_sheet/screens/add_sheet_size_screen.dart';
import 'package:smart_sheet/screens/staple_department_screen.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/home_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Sheet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: colorScheme.primary.withOpacity(0.1),
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
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('سيتم تطويره قريبًا'),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.warehouse,
                    label: 'المخازن',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('سيتم تطويره قريبًا'),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.add,
                    label: 'إضافة مقاس',
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
                    label: 'المقاسات المحفوظة',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
