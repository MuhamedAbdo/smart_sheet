import 'package:flutter/material.dart';
import 'package:smart_sheet/services/backup_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _fetchBackups() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final files = await _backupService.listBackups();
    if (mounted) {
      setState(() {
        _backupFiles = files;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCloudUpload() async {
    setState(() {
      _isLoading = true;
      _message = 'جاري الرفع في الخلفية... يمكنك مغادرة هذه الصفحة الآن.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('☁️ بدأت عملية الرفع السحابي، تابع التقدم في الإشعارات')),
    );

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
        title: const Text('⚠️ تأكيد الاستعادة'),
        content: const Text(
            'سيتم حذف البيانات الحالية واستبدالها بالنسخة المختارة. لا تغلق التطبيق أثناء العملية.'),
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
        _message = 'جاري استعادة البيانات... برجاء الانتظار';
      });

      _backupService.downloadAndRestore(fullPath).then((result) {
        if (mounted) {
          setState(() {
            _message = result;
            _isLoading = false;
          });
          if (result == 'SUCCESS_RESTORE') {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ تمت الاستعادة بنجاح')));
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي السحابي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchBackups,
          )
        ],
      ),
      body: Column(
        children: [
          if (_isLoading || _message != null) _buildStatusCard(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildActionButtons(),
                const SizedBox(height: 20),
                const Text('النسخ المتوفرة على السحابة:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                _buildBackupList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      // تم تحديث الشفافية لتجنب التحذير
      color: Colors.blue.withAlpha(25),
      child: Column(
        children: [
          Text(_message ?? 'جاري معالجة البيانات...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue)),
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleCloudUpload,
      icon: const Icon(Icons.cloud_upload),
      label: const Text('بدء الرفع السحابي الآن'),
      style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50)),
    );
  }

  Widget _buildBackupList() {
    if (_backupFiles.isEmpty && !_isLoading) {
      return const Center(child: Text('لا توجد نسخ متوفرة'));
    }
    return Column(
      children: _backupFiles
          .map((file) => Card(
                child: ListTile(
                  // تم تغيير الأيقونة إلى folder_zip
                  leading: const Icon(Icons.folder_zip, color: Colors.orange),
                  title: Text(file.name),
                  trailing: const Icon(Icons.settings_backup_restore),
                  onTap: _isLoading
                      ? null
                      : () => _handleCloudRestore(
                          'manual_backups/${Supabase.instance.client.auth.currentUser?.id}/${file.name}'),
                ),
              ))
          .toList(),
    );
  }
}
