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
import 'package:smart_sheet/theme/app_theme.dart';
import 'package:smart_sheet/animations/app_transitions.dart';

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
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            // 🎨 Header محسن
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.1),
                    colorScheme.secondary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.factory,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'مرحباً بك في Smart Sheet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeL,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'اختر القسم الذي تريد العمل فيه:',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeM,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: AppTheme.spacingM,
                mainAxisSpacing: AppTheme.spacingM,
                childAspectRatio: 1.1,
                children: [
                  AppTransitions.staggeredAnimation(
                    index: 0,
                    child: HomeButton(
                      icon: Icons.factory,
                      label: 'خط الإنتاج',
                      onTap: () {
                        Navigator.push(
                          context,
                          AppTransitions.slideRoute(
                            page: const ProductionLineScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  AppTransitions.staggeredAnimation(
                    index: 1,
                    child: HomeButton(
                      icon: Icons.print,
                      label: 'الفلكسو',
                      onTap: () {
                        Navigator.push(
                          context,
                          AppTransitions.slideRoute(
                            page: const FlexoScreen(),
                          ),
                        );
                      },
                    ),
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
