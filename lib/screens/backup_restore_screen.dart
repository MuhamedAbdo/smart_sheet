import 'package:flutter/material.dart';
import 'package:smart_sheet/services/backup_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smart_sheet/screens/qr_scanner_screen.dart';

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
      UIUtils.showInfoSnackBar(
        message: "تعذر فتح الرابط، تأكد من وجود متصفح",
        backgroundColor: Colors.redAccent,
        icon: Icons.browser_not_supported,
      );
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
        UIUtils.showInfoSnackBar(
          message: "يجب تسجيل الدخول أولاً",
          backgroundColor: Colors.redAccent,
          icon: Icons.login_outlined,
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

    UIUtils.showInfoSnackBar(
      message: "بدأت عملية الرفع السحابي، تابع التقدم في الإشعارات",
      backgroundColor: Colors.blueAccent,
      icon: Icons.cloud_upload_outlined,
    );

    final result = await _backupService.uploadToSupabase();

    if (mounted) {
      setState(() {
        _message = result;
        _isLoading = false;
      });

      if (result?.startsWith('✅') == true) {
        _checkBackupExists(); // Refresh backup status
        UIUtils.showInfoSnackBar(
          message: result!,
          backgroundColor: Colors.green,
          icon: Icons.check_circle_outline,
        );
      }
    }
  }

  Future<void> _handleCloudRestore() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: "يجب تسجيل الدخول أولاً",
          backgroundColor: Colors.redAccent,
          icon: Icons.login_outlined,
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
          UIUtils.showInfoSnackBar(
            message: "تمت الاستعادة بنجاح",
            backgroundColor: Colors.green,
            icon: Icons.cloud_done_outlined,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isAdmin = authService.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي السحابي'),
        actions: [
          // زر تحديث الصلاحيات
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.blue),
              tooltip: 'تحديث بيانات المستخدم',
              onPressed: () async {
                final result = await authService.refreshUserData();
                if (!context.mounted) return;
                
                if (result != null) {
                   UIUtils.showInfoSnackBar(
                     message: result,
                     backgroundColor: Colors.orange,
                     icon: Icons.warning_amber_rounded,
                   );
                   if (result.contains("تم تسجيل الخروج")) {
                     Navigator.pushReplacementNamed(context, AuthScreen.routeName);
                   }
                } else {
                   UIUtils.showInfoSnackBar(
                     message: "تم مزامنة بياناتك بنجاح",
                     backgroundColor: Colors.green,
                     icon: Icons.check_circle_outline,
                   );
                }
              },
            ),
          // زر المطور لفتح Supabase - يظهر فقط للأدمن
          if (Supabase.instance.client.auth.currentUser?.email ==
              'mohamedabdo9999933@gmail.com')
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

            const SizedBox(height: 16),
            
            _buildQRActionSection(isAdmin),

            const Spacer(),

            // Info Section
            _buildInfoSection(),
            
            const SizedBox(height: 16),
            
            // Debug Section
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black12,
              child: Column(
                children: [
                  Text('Debug User ID: ${Supabase.instance.client.auth.currentUser?.id}'),
                  Text('Debug Role: ${authService.state.role} (isAdmin: ${authService.isAdmin})'),
                  if (authService.state.errorMessage != null)
                    Text('Debug Error: ${authService.state.errorMessage}', style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
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
          UIUtils.showInfoSnackBar(
            message: "يجب تسجيل الدخول أولاً",
            backgroundColor: Colors.redAccent,
            icon: Icons.login_outlined,
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

  Widget _buildQRActionSection(bool isAdmin) {
    if (!_isAuthenticated) return const SizedBox.shrink();

    if (isAdmin) {
      return ElevatedButton.icon(
        onPressed: _showAdminQRCode,
        icon: const Icon(Icons.qr_code_2),
        label: const Text(
          'إضافة جهاز مساعد',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue[900],
          side: BorderSide(color: Colors.blue[900]!, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: _openQRScanner,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text(
          'ربط بالمصنع عبر QR',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<void> _showAdminQRCode() async {
    const storage = FlutterSecureStorage();
    final factoryId = await storage.read(key: 'factory_id');

    if (factoryId == null || factoryId.isEmpty) {
      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: "لا يوجد معرف مصنع لربطه. يرجى تسجيل الدخول مجدداً.",
          backgroundColor: Colors.red,
          icon: Icons.error_outline,
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ربط جهاز مساعد',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'وجه هاتف المساعد نحو هذا الكود',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: factoryId,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black87,
                  ),
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('إغلاق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openQRScanner() async {
    final authService = context.read<AuthService>();
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && result is String) {
      setState(() {
        _isLoading = true;
        _message = 'جاري ربط الحساب بالمصنع...';
      });

      final error = await authService.linkToFactory(result);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _message = null;
      });

      if (error == null) {
        UIUtils.showInfoSnackBar(
          message: "تم الربط بنجاح! يتم الآن تحديث البيانات.",
          backgroundColor: Colors.green,
          icon: Icons.check_circle_outline,
        );
        _checkBackupExists();
      } else {
        UIUtils.showInfoSnackBar(
          message: error,
          backgroundColor: Colors.red,
          icon: Icons.error_outline,
        );
      }
    }
  }
}
