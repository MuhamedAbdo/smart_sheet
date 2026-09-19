import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/widgets/smart_sheet_card.dart';
import 'package:smart_sheet/screens/add_staple_production_report_screen.dart';
import 'package:smart_sheet/screens/start_staple_job_screen.dart';

class StapleProductionReportsScreen extends StatelessWidget {
  const StapleProductionReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تقرير الإنتاج - الدبوس',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
            ),
            builder: (BuildContext context) {
              final bottomSheetTheme = Theme.of(context);
              final isDarkMode = bottomSheetTheme.brightness == Brightness.dark;

              return Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: bottomSheetTheme.colorScheme.primary, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'إضافة أوردر — الدبوس',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 0,
                        color: isDarkMode ? const Color(0xFF1E293B) : Colors.blue.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.rocket_launch, color: Colors.white),
                          ),
                          title: const Text('بدء تشغيل 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('تشغيل المؤقت وبدء العمل الآن.'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StartStapleJobScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: isDarkMode ? const Color(0xFF1E293B) : Colors.green.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade600,
                            child: const Icon(Icons.edit_document, color: Colors.white),
                          ),
                          title: const Text('إدخال تقرير يدوي (منتهي) 📝', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('تسجيل بيانات أوردر تم الانتهاء منه بالفعل.'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddStapleProductionReportScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة تقرير'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFF1E293B) 
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('staple_production_reports')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حدث خطأ أثناء جلب البيانات',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    );
                  }

                  final reports = snapshot.data ?? [];

                  if (reports.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد تقارير حالياً',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: SmartSheetCard(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'العميل: ${report['customer_name'] ?? 'غير محدد'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      'أمر: ${report['work_order'] ?? '-'}',
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'الصنف: ${report['item_name'] ?? 'غير محدد'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade400),
                                      const SizedBox(width: 4),
                                      Text(
                                        'منتج: ${report['production_quantity'] ?? 0}',
                                        style: TextStyle(color: Colors.green.shade400, fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 16, color: Colors.blueGrey),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${report['technician_name'] ?? '-'}',
                                        style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
