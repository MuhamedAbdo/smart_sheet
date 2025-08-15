// lib/src/screens/maintenance/maintenance_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/maintenance_section.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("🛠 سجلات الصيانة"),
        centerTitle: true,
      ),
      body: const MaintenanceSection(
        boxName: 'maintenanceRecords',
        title: "سجلات الصيانة",
      ),
    );
  }
}
