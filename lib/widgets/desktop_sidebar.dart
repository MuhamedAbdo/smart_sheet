import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:smart_sheet/screens/flexo_archive_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:smart_sheet/utils/archive_rbac_logic.dart';

class DesktopSidebar extends StatefulWidget {
  const DesktopSidebar({super.key});

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  int _selectedIndex = 0;

  /// استخدام صلاحيات الأرشيف
  bool _canViewArchive(String targetDepartment) {
    if (PermissionHelper.isSuperAdmin) return true;
    final Worker? cw = PermissionHelper.currentWorker;
    if (cw == null) return false;

    return ArchiveRbacService.canRead(cw);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkTheme;
    final auth = context.watch<AuthService>().state;

    return Container(
      width: 250,
      color: Theme.of(context).drawerTheme.backgroundColor ?? 
             (isDarkMode ? Colors.grey[900] : Colors.white),
      child: Column(
        children: [
          // Branding Header
          Container(
            padding: const EdgeInsets.all(20),
            color: isDarkMode ? Colors.grey[850] : Colors.blue,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage(
                    isDarkMode
                        ? 'assets/images/appdrawer_dark.jpg'
                        : 'assets/images/appdrawer_light.jpg',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Smart Sheet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                Text(
                  auth.user?.email ?? 'الوضع المحلي',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Hive.isBoxOpen('workers')
                ? ValueListenableBuilder<Box<Worker>>(
                    valueListenable: Hive.box<Worker>('workers').listenable(),
                    builder: (context, _, __) => _buildSidebarNavList(auth),
                  )
                : _buildSidebarNavList(auth),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavList(dynamic auth) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildNavItem(
          icon: Icons.home,
          title: 'الرئيسية',
          index: 0,
          onTap: () {
            setState(() => _selectedIndex = 0);
            context.read<AuthService>().navigatorKey.currentState?.popUntil((route) => route.isFirst);
          },
        ),
        if (_canViewArchive('flexo'))
          _buildNavItem(
            icon: Icons.inventory_2_outlined,
            title: 'أرشيف الفلكسو',
            index: 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              final nav = context.read<AuthService>().navigatorKey.currentState;
              nav?.popUntil((route) => route.isFirst);
              nav?.push(MaterialPageRoute(
                  builder: (_) => const FlexoArchiveScreen(
                        department: 'flexo',
                      )));
            },
          ),
        if (_canViewArchive('production_line'))
          _buildNavItem(
            icon: Icons.archive_outlined,
            title: 'أرشيف خط الإنتاج',
            index: 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              final nav = context.read<AuthService>().navigatorKey.currentState;
              nav?.popUntil((route) => route.isFirst);
              nav?.push(MaterialPageRoute(
                  builder: (_) => const FlexoArchiveScreen(
                        department: 'production_line',
                      )));
            },
          ),
        if (_canViewArchive('crushing'))
          _buildNavItem(
            icon: Icons.auto_awesome_motion,
            title: 'أرشيف التكسير',
            index: 3,
            onTap: () {
              setState(() => _selectedIndex = 3);
              final nav = context.read<AuthService>().navigatorKey.currentState;
              nav?.popUntil((route) => route.isFirst);
              nav?.push(MaterialPageRoute(
                  builder: (_) => const FlexoArchiveScreen(
                        department: 'crushing',
                      )));
            },
          ),
        const Divider(),
        _buildNavItem(
          icon: Icons.settings_outlined,
          title: 'الإعدادات والنسخ السحابي',
          index: 4,
          onTap: () {
            setState(() => _selectedIndex = 4);
            final nav = context.read<AuthService>().navigatorKey.currentState;
            nav?.popUntil((route) => route.isFirst);
            nav?.pushNamed(SettingsScreen.routeName);
          },
        ),
        const Divider(),
        if (!auth.isAuthenticated)
          _buildNavItem(
            icon: Icons.person_add_alt_1_outlined,
            title: 'تسجيل الدخول / إنشاء حساب',
            index: 5,
            color: Colors.blue,
            onTap: () {
              setState(() => _selectedIndex = 5);
              final nav = context.read<AuthService>().navigatorKey.currentState;
              nav?.popUntil((route) => route.isFirst);
              nav?.pushNamed(AuthScreen.routeName);
            },
          )
        else
          _buildNavItem(
            icon: Icons.logout,
            title: 'تسجيل الخروج',
            index: 6,
            color: Colors.red,
            onTap: () async {
              await context.read<AuthService>().signOut();
            },
          ),
      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required int index,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    // ✅ Material شفاف يُمكّن Ink Splashes من الظهور فوق الـ ColoredBox الخلفي
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ListTile(
          leading: Icon(
            icon,
            color: color ?? (isSelected ? theme.colorScheme.primary : theme.iconTheme.color),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isSelected ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color),
            ),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
      ),
    );
  }
}
