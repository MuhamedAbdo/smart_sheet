// lib/src/screens/flexo/flexo_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
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

import 'package:smart_sheet/widgets/flexo_report_drawer.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/smart_sheet_card.dart';

class FlexoScreen extends StatelessWidget {
  const FlexoScreen({super.key});

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
                        title: 'تقرير الإنتاج',
                        icon: Icons.receipt,
                        onTap: () {
                          Navigator.push(
                            innerContext,
                            MaterialPageRoute(
                              builder: (context) => const FlexoProductionReportScreen(),
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
                                boxName: 'store_flexo',
                                title: 'وارد مخزن الفلكسو',
                              ),
                            ),
                          );
                        },
                      ),
                      _buildDepartmentCard(
                        context: innerContext,
                        title: 'تقارير الماكينات',
                        icon: Icons.print_outlined,
                        onTap: () {
                          Scaffold.of(innerContext).openEndDrawer();
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      _buildSectionTitle('الإدارة والصيانة', theme),
                      _buildDepartmentCard(
                        context: innerContext,
                        title: 'طاقم الفلكسو',
                        icon: Icons.group,
                        onTap: () {
                          Navigator.push(
                            innerContext,
                            MaterialPageRoute(
                              builder: (context) => const WorkersScreen(
                                departmentBoxName: 'workers_flexo',
                                departmentTitle: 'طاقم الفلكسو',
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
                                boxName: 'maintenance_flexo_v2',
                                title: 'صيانة الفلكسو',
                              ),
                            ),
                          );
                        },
                      ),
                      _buildDepartmentCard(
                        context: innerContext,
                        title: 'إدارة الماكينات',
                        icon: Icons.precision_manufacturing,
                        onTap: () {
                          Navigator.push(
                            innerContext,
                            MaterialPageRoute(
                              builder: (context) => const MachineManagementScreen(
                                department: 'flexo',
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
                      _buildDepartmentCard(
                        context: innerContext,
                        title: 'بالتة الألوان',
                        icon: Icons.palette,
                        onTap: () {
                          Navigator.push(
                            innerContext,
                            MaterialPageRoute(
                              builder: (context) => const ColorPaletteScreen(),
                            ),
                          );
                        },
                      ),
                      if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS))
                        _buildDepartmentCard(
                          context: innerContext,
                          title: 'تركيب السيريل',
                          icon: Icons.build_circle,
                          onTap: () {
                            Navigator.push(
                              innerContext,
                              MaterialPageRoute(
                                builder: (context) => const SerialSetupScreen(),
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


