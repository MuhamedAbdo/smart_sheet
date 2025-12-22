import 'package:flutter/material.dart';
import 'package:smart_sheet/services/backup_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BackupRestoreScreen extends StatefulWidget {
  static const routeName = '/backup-restore';
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _backupService = BackupService();
  List<FileObject> _backupFiles = [];
  bool _isLoading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _fetchBackups();
  }

  Future<void> _launchSupabaseDashboard() async {
    final Uri url = Uri.parse(
        'https://supabase.com/dashboard/project/_/storage/buckets/backups');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر فتح المتصفح')));
    }
  }

  Future<void> _fetchBackups() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    final files = await _backupService.listBackups();
    if (mounted)
      setState(() {
        _backupFiles = files;
        _isLoading = false;
      });
  }

  Future<void> _handleCloudUpload() async {
    setState(() {
      _isLoading = true;
      _message =
          'بدأ الرفع... يمكنك استخدام التطبيق، سنقوم بتحديث القائمة فور الانتهاء.';
    });

    // الرفع في الخلفية (Don't await here so UI remains active)
    _backupService.uploadToSupabase().then((result) {
      if (mounted) {
        setState(() {
          _message = result;
          _isLoading = false;
        });
        if (result?.startsWith('✅') == true) _fetchBackups();
      }
    });
  }

  Future<void> _handleCloudRestore(String fullPath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الاستعادة'),
        content: const Text('سيتم استبدال البيانات الحالية بالنسخة السحابية.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استعادة')),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _message = 'جاري التنزيل والاستعادة...';
      });
      try {
        final result = await _backupService.downloadAndRestore(fullPath);
        if (mounted)
          setState(() {
            _message = result;
          });
      } finally {
        if (mounted)
          setState(() {
            _isLoading = false;
          });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي السحابي'),
        actions: [
          IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.orange),
              onPressed: _launchSupabaseDashboard),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _fetchBackups)
        ],
      ),
      body: Column(
        children: [
          if (_isLoading || _message != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: isDark
                  ? Colors.blueGrey.withOpacity(0.2)
                  : Colors.blue.shade50,
              child: Column(
                children: [
                  Text(
                    _message ?? 'جاري المعالجة...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator()),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle(
                    'الرفع للسحابة', Icons.cloud_upload, context),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleCloudUpload,
                  icon: const Icon(Icons.backup),
                  label: const Text('بدء الرفع السحابي الآن'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50)),
                ),
                const SizedBox(height: 30),
                _buildSectionTitle('النسخ المتوفرة', Icons.storage, context),
                const Divider(),
                _buildBackupList(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupList(bool isDark) {
    if (_backupFiles.isEmpty && !_isLoading)
      return const Center(child: Text('لا توجد نسخ سحابية'));
    final user = Supabase.instance.client.auth.currentUser;

    return Column(
      children: _backupFiles.map((file) {
        final String fullPath = 'manual_backups/${user?.id}/${file.name}';
        final String displayName =
            file.name.split('_').first.replaceAll('T', ' ').substring(0, 16);

        return Card(
          child: ListTile(
            leading: const Icon(Icons.folder_zip, color: Colors.blue),
            title: Text(displayName),
            subtitle: Text(
                'الحجم: ${((file.metadata?['size'] ?? 0) / 1024).toStringAsFixed(1)} KB'),
            trailing: const Icon(Icons.settings_backup_restore),
            onTap: _isLoading ? null : () => _handleCloudRestore(fullPath),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.blue),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold))
    ]);
  }
}
