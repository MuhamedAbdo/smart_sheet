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
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchBackups();
  }

  Future<void> _fetchBackups() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    final files = await _backupService.listBackups();
    setState(() {
      _backupFiles = files;
      _isLoading = false;
    });
  }

  Future<void> _handleCloudUpload() async {
    setState(() {
      _isLoading = true;
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    final result = await _backupService.uploadToSupabase(
        onProgress: (p) => setState(() => _uploadProgress = p));
    setState(() {
      _isLoading = false;
      _isUploading = false;
      _message = result;
    });
    if (result?.startsWith('✅') == true) _fetchBackups();
  }

  Future<void> _handleCloudRestore(String fullPath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الاستعادة'),
        content: const Text(
            'سيتم استبدال بياناتك الحالية بالنسخة السحابية. هل تود المتابعة؟'),
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
        _message = 'جاري التحميل...';
      });
      final result = await _backupService.downloadAndRestore(fullPath);
      setState(() {
        _isLoading = false;
        _message = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchBackups)
      ]),
      body: Column(
        children: [
          if (_isLoading || _message != null) _buildStatusArea(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('النسخ السحابي', Icons.cloud_upload),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleCloudUpload,
                  icon: const Icon(Icons.upload),
                  label: const Text('رفع نسخة للسحابة'),
                ),
                const Divider(height: 40),
                _buildSectionTitle('النسخ المتوفرة', Icons.history),
                const SizedBox(height: 10),
                _buildBackupList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Text(_message ?? 'جاري المعالجة...', textAlign: TextAlign.center),
          if (_isUploading) LinearProgressIndicator(value: _uploadProgress),
        ],
      ),
    );
  }

  Widget _buildBackupList() {
    if (_backupFiles.isEmpty && !_isLoading)
      return const Center(child: Text('لا توجد نسخ'));
    final user = Supabase.instance.client.auth.currentUser;

    return Column(
      children: _backupFiles.map((file) {
        // بناء المسار الكامل لضمان عدم حدوث 404
        final String fullPath = 'manual_backups/${user?.id}/${file.name}';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_download, color: Colors.blue),
            title: Text(file.name.split('_').first),
            subtitle: Text(
                '${((file.metadata?['size'] ?? 0) / 1024).toStringAsFixed(1)} KB'),
            onTap: _isLoading ? null : () => _handleCloudRestore(fullPath),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: Colors.blue),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold))
    ]);
  }
}
