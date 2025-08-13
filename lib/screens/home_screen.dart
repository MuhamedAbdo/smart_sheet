// lib/src/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/home_button.dart'; // ✅ صحّح المسار

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Sheet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 1,
      ),
      // ✅ AppDrawer دلوقتي بدون أي parameters
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.blue.shade50,
              child: const Text(
                'اختر القسم الذي تريد العمل فيه:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم الدخول إلى خط الإنتاج'),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.print,
                    label: 'الفلكسو',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم الدخول إلى الفلكسو'),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.cut,
                    label: 'التكسير',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم الدخول إلى التكشير'),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.push_pin,
                    label: 'الدبوس',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم الدخول إلى الدبوس'),
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
                          content: Text('تم الدخول إلى السليكات'),
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
                          content: Text('تم الدخول إلى المخازن'),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.add,
                    label: 'إضافة مقاس',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('فتح نموذج إضافة مقاس'),
                        ),
                      );
                    },
                  ),
                  HomeButton(
                    icon: Icons.save,
                    label: 'المقاسات المحفوظة',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('عرض المقاسات المحفوظة'),
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
