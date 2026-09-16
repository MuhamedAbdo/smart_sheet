// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:smart_sheet/screens/crushing_screen.dart';
import 'package:smart_sheet/screens/flexo_screen.dart';
import 'package:smart_sheet/screens/production_line_screen.dart';
import 'package:smart_sheet/screens/saved_sizes_screen.dart';
import 'package:smart_sheet/screens/staple_department_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:smart_sheet/screens/linked_accounts_screen.dart';
import 'package:smart_sheet/screens/issued_work_orders_screen.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWindows = !kIsWeb && Platform.isWindows;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await SystemNavigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Smart Sheet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 1,
        ),
        drawer: isWindows ? null : const AppDrawer(),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: ValueListenableBuilder<Box<Worker>>(
            valueListenable: Hive.box<Worker>('workers').listenable(),
            builder: (context, box, child) {
              if (!Hive.isBoxOpen('workers')) {
                return const Center(child: CircularProgressIndicator());
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // القسم الأول: أقسام المصنع
                      _buildSectionTitle('أقسام المصنع', theme),
                      _buildCard(
                        context: context,
                        title: 'الفلكسو',
                        icon: Icons.print,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FlexoScreen()),
                        ),
                      ),
                      _buildCard(
                        context: context,
                        title: 'خط الإنتاج',
                        icon: Icons.factory,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProductionLineScreen()),
                        ),
                      ),
                      _buildCard(
                        context: context,
                        title: 'التكسير',
                        icon: Icons.cut,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CrushingScreen()),
                        ),
                      ),
                      _buildCard(
                        context: context,
                        title: 'الدبوس',
                        icon: Icons.push_pin,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StapleDepartmentScreen()),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // القسم الثاني: الإنتاج والمخازن
                      _buildSectionTitle('الإنتاج والمخازن', theme),
                      _buildCard(
                        context: context,
                        title: 'أوامر التشغيل الصادرة',
                        icon: Icons.assignment,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const IssuedWorkOrdersScreen()),
                        ),
                      ),
                      _buildCard(
                        context: context,
                        title: 'المخازن',
                        icon: Icons.warehouse,
                        onTap: () {
                          UIUtils.showInfoSnackBar(
                            message: 'سيتم تطويره قريبًا',
                            backgroundColor: Colors.blueGrey,
                          );
                        },
                      ),
                      _buildCard(
                        context: context,
                        title: 'السليكات',
                        icon: Icons.science,
                        onTap: () {
                          UIUtils.showInfoSnackBar(
                            message: 'سيتم تطويره قريبًا',
                            backgroundColor: Colors.blueGrey,
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // القسم الثالث: الإدارة والنظام
                      _buildSectionTitle('الإدارة والنظام', theme),
                      _buildCard(
                        context: context,
                        title: 'سجل العملاء',
                        icon: Icons.save,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SavedSizesScreen()),
                        ),
                      ),
                      _buildCard(
                        context: context,
                        title: 'سجل العمال',
                        icon: Icons.people,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WorkersScreen(
                              departmentBoxName: 'workers',
                              departmentTitle: 'طاقم المصنع الموحد',
                            ),
                          ),
                        ),
                      ),
                      if (context.read<AuthService>().isAdmin)
                        _buildCard(
                          context: context,
                          title: 'الأجهزة المرتبطة',
                          icon: Icons.manage_accounts,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LinkedAccountsScreen()),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

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

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Deep Navy / Slate
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_back_ios, 
                size: 16,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
