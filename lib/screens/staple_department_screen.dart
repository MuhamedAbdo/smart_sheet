// lib/src/screens/staple/staple_department_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/screens/finished_product_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/home_button.dart'; // ✅ استيراد زر الواجهة

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
      drawer: const AppDrawer(), // ✅ الـ Drawer متاح
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // عنوان فوق الأزرار
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.orange.shade50,
              child: const Text(
                'اختر القسم الذي تريد العمل فيه :',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.orange,
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
                  // ✅ زر جديد يوجه إلى finished_product_screen
                  HomeButton(
                    icon: Icons.check_circle,
                    label: 'المنتج التام',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const FinishedProductScreen(), // <-- هنا
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
                            departmentBoxName:
                                'workers_staple', // ✅ اسم الصندوق المخصص
                            departmentTitle: 'طاقم الدبوس', // ✅ عنوان القسم
                          ),
                        ),
                      );
                    },
                  ),
                  // HomeButton(
                  //   icon: Icons.settings,
                  //   label: 'إعدادات الدبوس', // مثال لزر آخر يمكنك إضافته لاحقًا
                  //   onTap: () {
                  //     // Navigator.push(...);
                  //   },
                  // ),
                  // يمكنك إضافة المزيد من الأزرار هنا
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
