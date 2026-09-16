// lib/src/screens/staple/staple_department_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/screens/calculator_screen.dart';
import 'package:smart_sheet/screens/finished_product_screen.dart';
import 'package:smart_sheet/screens/maintenance_screen.dart';
import 'package:smart_sheet/screens/store_entry_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:smart_sheet/widgets/smart_sheet_card.dart';

class StapleDepartmentScreen extends StatelessWidget {
  const StapleDepartmentScreen({super.key});

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.blueGrey,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDepartmentCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SmartSheetCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.blueAccent,
          size: 28,
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: Icon(
          Icons.arrow_back_ios,
          size: 16,
          color: isDark ? Colors.white54 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark 
                  ? const Color(0xFF1E293B) 
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Builder(
                builder: (innerContext) {
                  return ListView(
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      _buildSectionTitle('الإنتاج والمخازن', theme),
                      _buildDepartmentCard(
                        context: innerContext,
                        title: 'المنتج التام',
                        icon: Icons.check_circle,
                        onTap: () {
                          Navigator.push(
                            innerContext,
                            MaterialPageRoute(
                              builder: (context) => const FinishedProductScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDepartmentCard(
                        context: innerContext,
                        title: 'وارد المخزن',
                        icon: Icons.inventory,
                        onTap: () {
                          Navigator.push(
                            innerContext,
                            MaterialPageRoute(
                              builder: (context) => const StoreEntryScreen(
                                boxName: 'store_staple',
                                title: 'وارد مخزن الدبوس',
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      _buildSectionTitle('الإدارة والصيانة', theme),
                      _buildDepartmentCard(
                        context: innerContext,
                        title: 'طاقم الدبوس',
                        icon: Icons.people,
                        onTap: () {
                          Navigator.push(
                            innerContext,
                            MaterialPageRoute(
                              builder: (context) => const WorkersScreen(
                                departmentBoxName: 'workers_staple',
                                departmentTitle: 'طاقم الدبوس',
                              ),
                            ),
                          );
                        },
                      ),
                      _buildDepartmentCard(
                        context: innerContext,
                        title: 'الصيانة',
                        icon: Icons.settings,
                        onTap: () {
                          Navigator.push(
                            innerContext,
                            MaterialPageRoute(
                              builder: (context) => const MaintenanceScreen(
                                boxName: 'maintenance_staple_v2',
                                title: 'صيانة الدبوس',
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      _buildSectionTitle('أدوات مساعدة', theme),
                      _buildDepartmentCard(
                        context: innerContext,
                        title: 'الآلة الحاسبة',
                        icon: Icons.calculate,
                        onTap: () {
                          Navigator.push(
                            innerContext,
                            MaterialPageRoute(
                              builder: (context) => const CalculatorScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }
              ),
            ),
          ),
        ),
      ),
    );
  }
}
