import 'package:flutter/material.dart';
import 'package:smart_sheet/services/backup_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_sheet/screens/auth_screen.dart';

class BackupRestoreScreen extends StatefulWidget {
  static const routeName = '/backup-restore';
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _backupService = BackupService();
  bool _isLoading = false;
  String? _message;
  bool _hasBackup = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
    _checkBackupExists();
  }

  Future<void> _checkAuthenticationStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (mounted) {
      setState(() {
        _isAuthenticated = user != null;
      });
    }
  }

  // دالة فتح رابط لوحة تحكم Supabase للمطور
  Future<void> _launchSupabaseDashboard() async {
    final Uri url = Uri.parse(
        'https://supabase.com/dashboard/project/lbvaezdeaisukxqwwrmk');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('❌ تعذر فتح الرابط، تأكد من وجود متصفح')),
        );
      }
    }
  }

  Future<void> _checkBackupExists() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final backups = await _backupService.listBackups();
      if (mounted) {
        setState(() {
          _hasBackup = backups.isNotEmpty;
        });
      }
    } catch (e) {
      // Ignore errors during check
    }
  }

  Future<void> _handleCloudUpload() async {
    // Double-check authentication before proceeding
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ يجب تسجيل الدخول أولاً')),
        );
        // Redirect to auth screen
        Navigator.pushReplacementNamed(context, AuthScreen.routeName);
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'جاري رفع النسخة الاحتياطية...';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('☁️ بدأت عملية الرفع السحابي، تابع التقدم في الإشعارات')),
    );

    final result = await _backupService.uploadToSupabase();

    if (mounted) {
      setState(() {
        _message = result;
        _isLoading = false;
      });

      if (result?.startsWith('✅') == true) {
        _checkBackupExists(); // Refresh backup status
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result!)),
        );
      }
    }
  }

  Future<void> _handleCloudRestore() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ يجب تسجيل الدخول أولاً')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ تأكيد الاستعادة'),
        content: const Text(
            'سيتم حذف البيانات الحالية واستبدالها بنسختك الاحتياطية المحفوظة على السحابة. لا تغلق التطبيق أثناء العملية.'),
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

      // Direct restore from user-specific path (direct in bucket)
      final restorePath = '${user.id}.zip';
      final result = await _backupService.downloadAndRestore(restorePath);

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي السحابي'),
        actions: [
          // زر المطور لفتح Supabase
          IconButton(
            icon: const Icon(Icons.terminal, color: Colors.orangeAccent),
            tooltip: 'Supabase Dashboard (Dev)',
            onPressed: _launchSupabaseDashboard,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            if (_isLoading || _message != null) _buildStatusCard(),

            const SizedBox(height: 20),

            // Backup Status Indicator
            _buildBackupStatusCard(),

            const SizedBox(height: 30),

            // Main Action Buttons
            _buildUploadButton(),

            const SizedBox(height: 16),

            _buildRestoreButton(),

            const Spacer(),

            // Info Section
            _buildInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _message?.startsWith('✅') == true
            ? Colors.green.withAlpha(25)
            : Colors.blue.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _message?.startsWith('✅') == true ? Colors.green : Colors.blue,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            _message ?? 'جاري معالجة البيانات...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _message?.startsWith('✅') == true
                  ? Colors.green
                  : Colors.blue,
            ),
          ),
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildBackupStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            _hasBackup ? Colors.green.withAlpha(25) : Colors.grey.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _hasBackup ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _hasBackup ? Icons.cloud_done : Icons.cloud_off,
            color: _hasBackup ? Colors.green : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasBackup ? 'نسخة احتياطية متوفرة' : 'لا توجد نسخة احتياطية',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _hasBackup ? Colors.green : Colors.grey,
                  ),
                ),
                const Text(
                  'آخر نسخة محفوظة على السحابة',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    if (!_isAuthenticated) {
      return ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ يجب تسجيل الدخول أولاً')),
          );
          Navigator.pushReplacementNamed(context, AuthScreen.routeName);
        },
        icon: const Icon(Icons.login),
        label: const Text(
          'تسجيل الدخول مطلوب',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleCloudUpload,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_upload),
      label: Text(
        _isLoading ? 'جاري الرفع...' : 'رفع نسخة احتياطية',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return ElevatedButton.icon(
      onPressed: (_isLoading || !_hasBackup) ? null : _handleCloudRestore,
      icon: const Icon(Icons.cloud_download),
      label: const Text(
        'استعادة البيانات',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: _hasBackup ? Colors.orange : Colors.grey,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey, size: 20),
              SizedBox(width: 8),
              Text(
                'معلومات هامة',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• كل نسخة احتياطية جديدة تستبدل القديمة\n'
            '• يمكن استعادة آخر نسخة تم رفعها فقط\n'
            '• البيانات محفوظة بشكل آمن ومشفر',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
