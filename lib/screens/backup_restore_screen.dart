import 'dart:async';
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
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:smart_sheet/services/pairing_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  static const routeName = '/backup-restore';
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _backupService = BackupService();
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _message;
  bool _hasBackup = false;
  bool _isAuthenticated = false;
  String? _factoryId;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
    _checkBackupExists();
    _loadFactoryId();
  }

  Future<void> _loadFactoryId() async {
    final AuthService authService = AuthService();
    final factoryId = await authService.getFactoryId();
    if (mounted) {
      setState(() {
        _factoryId = factoryId;
      });
    }
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
      final backupExists = backups.any((file) => file.name.endsWith('.zip'));

      if (mounted) {
        setState(() {
          _hasBackup = backupExists;
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
        await _checkBackupExists(); // Refresh backup status
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

      // Direct restore from factory-specific path
      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _message = '❌ فشل الاستعادة: تعذر العثور على معرّف المصنع';
          });
        }
        return;
      }
      
      final restorePath = '$factoryId.zip';
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

  Future<void> _handleLocalBackup() async {
    setState(() {
      _isLoading = true;
      _message = 'جاري إنشاء نسخة احتياطية محلية...';
    });

    final result = await _backupService.createBackup();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _message = result;
      });
      if (result?.startsWith('✅') == true) {
        UIUtils.showInfoSnackBar(
          message: result!,
          backgroundColor: Colors.green,
          icon: Icons.save_alt,
        );
      }
    }
  }

  Future<void> _handleLocalRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ تأكيد الاستعادة المحلية'),
        content: const Text(
            'سيتم حذف البيانات الحالية واستبدالها بالملف المختار. هل تريد الاستمرار؟'),
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
        _message = 'جاري استعادة البيانات...';
      });

      final result = await _backupService.restoreBackup();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = result;
        });
        if (result == 'SUCCESS_RESTORE') {
          UIUtils.showInfoSnackBar(
            message: "تمت الاستعادة بنجاح، سيتم إعادة تشغيل التطبيق",
            backgroundColor: Colors.green,
            icon: Icons.check_circle,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = context.watch<AuthService>();
    final isAdmin = authService.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي السحابي'),
        actions: [
          // زر تحديث الصلاحيات
          if (_isAuthenticated)
            _isRefreshing
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.blue),
                    tooltip: 'تحديث بيانات المستخدم',
                    onPressed: () async {
                      setState(() {
                        _isRefreshing = true;
                      });
                      
                      await _checkBackupExists();
                      final result = await authService.refreshUserData();
                      
                      if (!context.mounted) return;
                      
                      setState(() {
                        _isRefreshing = false;
                      });
                      
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
            // Status Card
            if (_isLoading || _message != null) _buildStatusCard(),

            const SizedBox(height: 20),

            // Backup Status Indicator
            _buildBackupStatusCard(),

            const SizedBox(height: 30),

            // Main Action Buttons (Cloud)
            const Text("النسخ السحابي", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildUploadButton(),
            const SizedBox(height: 12),
            _buildRestoreButton(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Local Backup Buttons
            const Text("النسخ المحلي", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleLocalBackup,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ نسخة محلية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleLocalRestore,
                    icon: const Icon(Icons.restore),
                    label: const Text('استعادة نسخة محلية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            
            _buildQRActionSection(isAdmin, _factoryId),

            const SizedBox(height: 32),

            // Info Section
            _buildInfoSection(),
            
            const SizedBox(height: 16),
            
            // Debug Section
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black12,
              child: Text(
                authService.isAdmin ? 'مسؤول' : 'مستخدم',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
          ),
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

  Widget _buildQRActionSection(bool isAdmin, String? factoryId) {
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
      // إذا كان الجهاز مرتبط، اعرض زر فك الارتباط
      if (factoryId != null && factoryId.isNotEmpty) {
        return ElevatedButton.icon(
          onPressed: () => _showUnlinkConfirmation(factoryId),
          icon: const Icon(Icons.link_off),
          label: Text(
            'فك الارتباط بالمصنع ($factoryId)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      // إذا لم يكن مرتبط، اعرض زر الربط
      return ElevatedButton.icon(
        onPressed: _openQRScanner,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text(
          'ربط بالمصنع عبر الكود/QR',
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

    // توليد كود الربط
    debugPrint('🔄 Generating pairing code...');
    final pairingCode = await PairingService().generatePairingCode();
    debugPrint('📱 Generated pairing code: $pairingCode');

    if (pairingCode == null) {
      debugPrint('❌ Failed to generate pairing code');
      UIUtils.showInfoSnackBar(
        message: "فشل في توليد كود الربط. تأكد من الاتصال بالإنترنت.",
        backgroundColor: Colors.red,
        icon: Icons.error_outline,
      );
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return _PairingCodeDialog(
          factoryId: factoryId,
          pairingCode: pairingCode,
          onClose: () {
            PairingService().cancelCurrentCode();
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Future<void> _openQRScanner() async {
    // على سطح المكتب، نستخدم كود الربط المكون من 6 أرقام
    final TextEditingController codeController = TextEditingController();

    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
          insetPadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
        title: const Row(
          children: [
            Icon(Icons.computer, color: Colors.blue),
            SizedBox(width: 8),
            Text('ربط جهاز الكمبيوتر'),
          ],
        ),
        content: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'أدخل كود الربط المكون من 6 أرقام الذي يظهر في تطبيق الأدمن:',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 3),
                    ),
                    hintText: '123 456',
                    hintStyle: const TextStyle(
                      fontSize: 24,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    filled: true,
                    fillColor: Colors.blue.shade900.withValues(alpha: 0.3),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                const Text(
                  'صالح لمدة 5 دقائق فقط',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, codeController.text.trim()),
            icon: const Icon(Icons.link),
            label: const Text('ربط الآن'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[900],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // إزالة المسافات من الكود قبل التحقق
      final cleanCode = result.replaceAll(' ', '').replaceAll('-', '');
      await _verifyAndLinkWithCode(cleanCode);
    }
  }

  Future<void> _verifyAndLinkWithCode(String code) async {
    final AuthService authService = AuthService();

    setState(() {
      _isLoading = true;
      _message = 'جاري التحقق من الكود...';
    });

    // التحقق من الكود والربط
    final verificationResult = await PairingService().verifyAndLink(code);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _message = null;
    });

    if (verificationResult == null) {
      UIUtils.showInfoSnackBar(
        message: "حدث خطأ أثناء التحقق من الكود",
        backgroundColor: Colors.red,
        icon: Icons.error_outline,
      );
      return;
    }

    if (verificationResult['success'] == false) {
      UIUtils.showInfoSnackBar(
        message: verificationResult['error'] ?? 'الكود غير صحيح',
        backgroundColor: Colors.red,
        icon: Icons.error_outline,
      );
      return;
    }

    // الكود صحيح، نكمل الربط
    final factoryId = verificationResult['factory_id'] as String;

    setState(() {
      _isLoading = true;
      _message = 'جاري ربط الحساب بالمصنع...';
    });

    final error = await authService.linkToFactory(factoryId);

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
      await authService.refreshUserData();
      await _checkBackupExists();
      await _loadFactoryId(); // إعادة تحميل factoryId
      setState(() {}); // تحديث الـ UI فوراً
    } else {
      UIUtils.showInfoSnackBar(
        message: error,
        backgroundColor: Colors.red,
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _showUnlinkConfirmation(String factoryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('تأكيد فك الارتباط'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل أنت متأكد من فك ارتباط الجهاز بالمصنع؟',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'المصنع: $factoryId',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'بعد فك الارتباط، ستفقد الوصول إلى بيانات المصنع وستحتاج إلى إعادة الربط مرة أخرى.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('فك الارتباط'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final AuthService authService = AuthService();
      final error = await authService.unlinkFactory();
      
      if (!mounted) return;

      if (error == null) {
        UIUtils.showInfoSnackBar(
          message: "تم فك الارتباط بنجاح",
          backgroundColor: Colors.green,
          icon: Icons.check_circle_outline,
        );
        await _checkBackupExists();
        setState(() {
          _factoryId = null; // تحديث factoryId فوراً
        });
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

/// Dialog showing QR code and pairing code with countdown timer
class _PairingCodeDialog extends StatefulWidget {
  final String factoryId;
  final String? pairingCode;
  final VoidCallback onClose;

  const _PairingCodeDialog({
    required this.factoryId,
    required this.pairingCode,
    required this.onClose,
  });

  @override
  State<_PairingCodeDialog> createState() => _PairingCodeDialogState();
}

class _PairingCodeDialogState extends State<_PairingCodeDialog> {
  late Timer _timer;
  int _remainingSeconds = 300; // 5 minutes
  String? _currentCode;

  @override
  void initState() {
    super.initState();
    _currentCode = widget.pairingCode;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        // إعادة توليد الكود تلقائياً
        _regenerateCode();
      }
    });
  }

  Future<void> _regenerateCode() async {
    final newCode = await PairingService().generatePairingCode();
    if (mounted) {
      setState(() {
        _currentCode = newCode;
        _remainingSeconds = 300;
      });
      _startTimer();
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatCode(String code) {
    // تنسيق الكود كـ XXX XXX (أول 3 أرقام + مسافة + آخر 3 أرقام)
    debugPrint('🎨 Formatting code: $code -> part1: ${code.substring(0, 3)} part2: ${code.substring(3)}');
    if (code.length == 6) {
      return '${code.substring(0, 3)} ${code.substring(3)}';
    }
    return code;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // العنوان
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
            'امسح الكود أو أدخل الكود المكون من 6 أرقام',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // QR Code
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
              data: widget.factoryId,
              version: QrVersions.auto,
              size: 180.0,
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

          // خط فاصل
          const Divider(),

          const SizedBox(height: 16),

          // أو استخدم الكود
          const Text(
            'أو أدخل هذا الكود في جهاز الكمبيوتر',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // الكود بتنسيق كبير
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    _currentCode != null ? _formatCode(_currentCode!) : '---- --',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // العداد التنازلي
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.timer,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // أزرار التحكم
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _regenerateCode,
                  icon: const Icon(Icons.refresh),
                  label: const Text('كود جديد'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                  label: const Text('إغلاق'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



















