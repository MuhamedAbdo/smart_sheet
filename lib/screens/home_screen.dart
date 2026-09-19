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
import 'package:smart_sheet/widgets/smart_sheet_card.dart';

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

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 900;
                  
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark 
                            ? const Color(0xFF1E293B) // Slate 800
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : 600),
                        child: isDesktop 
                            ? _buildDesktopLayout(context, theme)
                            : _buildMobileLayout(context, theme),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        ..._buildSection1(context, theme),
        const SizedBox(height: 24),
        ..._buildSection2(context, theme),
        const SizedBox(height: 24),
        ..._buildSection3(context, theme),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: _buildSection1(context, theme),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: VerticalDivider(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
            thickness: 1,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              ..._buildSection2(context, theme),
              const SizedBox(height: 24),
              ..._buildSection3(context, theme),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSection1(BuildContext context, ThemeData theme) {
    return [
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
    ];
  }

  List<Widget> _buildSection2(BuildContext context, ThemeData theme) {
    return [
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
    ];
  }

  List<Widget> _buildSection3(BuildContext context, ThemeData theme) {
    return [
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
    ];
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
}
