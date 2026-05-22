// lib/screens/about_screen.dart

import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color accent = Colors.blueAccent;
    final Color surface =
        isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF5F7FF);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: const Text('عن التطبيق والمطور',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── قسم عن التطبيق ───────────────────────────────────────────
            _SectionCard(
              isDark: isDark,
              child: Column(
                children: [
                  // شعار التطبيق
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image(
                          image: AssetImage(
                            isDark
                                ? 'assets/images/appdrawer_dark.jpg'
                                : 'assets/images/appdrawer_light.jpg',
                          ),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Smart Sheet',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'الإصدار: Version 1.0.0',
                      style:
                          TextStyle(color: accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'نظام إدارة ومتابعة ورديات الإنتاج الذكي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'نظام رقمي متكامل مصمم خصيصاً للمطابع والمنشآت الصناعية لإدارة خطوط الإنتاج، ومتابعة الجلسات النشطة لحظياً، وحساب الهالك والأعطال بدقة لرفع الكفاءة التشغيلية.',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: isDark ? Colors.grey[300] : Colors.grey[800]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── قسم عن المطور ────────────────────────────────────────────
            _SectionCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(icon: Icons.person, label: 'عن المطور'),
                  const SizedBox(height: 16),
                  _InfoRow(
                    isDark: isDark,
                    icon: Icons.badge_outlined,
                    label: 'الاسم',
                    value: 'محمد عبد العال',
                  ),
                  _InfoRow(
                    isDark: isDark,
                    icon: Icons.work_outline,
                    label: 'الوظيفة',
                    value:
                        'فني طباعة بشركة العاشر للطباعة والنشر والتغليف (كارتبرس)\nمبرمج Flutter',
                  ),
                  _InfoRow(
                    isDark: isDark,
                    icon: Icons.military_tech_outlined,
                    label: 'الخبرة',
                    value:
                        '24 عاماً في مجال طباعة الفلكسو وتحسين كفاءة الإنتاج',
                  ),
                  _InfoRow(
                    isDark: isDark,
                    icon: Icons.email_outlined,
                    label: 'التواصل',
                    value: 'mohamedabdo9999933@gmail.com',
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── حقوق النسخ ───────────────────────────────────────────────
            Text(
              '© ${DateTime.now().year} Smart Sheet — جميع الحقوق محفوظة',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[600] : Colors.grey[500]),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets مساعدة ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _SectionCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252535) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 22),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 18,
                  color: isDark ? Colors.blueAccent[100] : Colors.blueAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? Colors.grey[200] : Colors.grey[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
      ],
    );
  }
}
