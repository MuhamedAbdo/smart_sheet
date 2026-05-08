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
import 'package:flutter/services.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/services/sync_service.dart';

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
      _message = 'جاري إرسال البيانات للمزامنة الفورية...';
    });

    UIUtils.showInfoSnackBar(
      message: "بدأت عملية المزامنة السحابية الإجبارية، تابع التقدم في الخلفية",
      backgroundColor: Colors.blueAccent,
      icon: Icons.sync,
    );

    final result = await SyncService.instance.forcePushAllLocalDataToServer();

    if (mounted) {
      setState(() {
        _message = result;
        _isLoading = false;
      });

      if (result.startsWith('✅')) {
        UIUtils.showInfoSnackBar(
          message: "تم بدء المزامنة بنجاح!",
          backgroundColor: Colors.green,
          icon: Icons.check_circle_outline,
        );
      } else {
        UIUtils.showInfoSnackBar(
          message: result,
          backgroundColor: Colors.red,
          icon: Icons.error_outline,
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
    final authService = context.watch<AuthService>();
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
      body: Padding(
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
            
            _buildQRActionSection(isAdmin),

            const SizedBox(height: 32),

            // Info Section
            _buildInfoSection(),

            const SizedBox(height: 16),
            Center(
              child: Text(
                isAdmin ? '(صلاحية: مدير النظام)' : '(صلاحية: مستخدم مساعد)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
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
          : const Icon(Icons.sync_alt),
      label: Text(
        _isLoading ? 'جاري المزامنة...' : 'مزامنة سحابية إجبارية (Push)',
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

    final authService = context.read<AuthService>();
    final currentFactoryId = authService.factoryId;
    final isLinked = currentFactoryId != null && currentFactoryId.isNotEmpty;

    // 1. الجزء الخاص بالمدير (Admin) - يظهر دائماً خيار التوليد
    if (isAdmin) {
      return Column(
        children: [
          if (isLinked) ...[
            _buildLinkedStatusBox(currentFactoryId, isAdmin),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
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
          ),
        ],
      );
    }

    // 2. الجزء الخاص بالمساعد (Assistant)
    if (isLinked) {
      return _buildLinkedStatusBox(currentFactoryId, isAdmin);
    }

    // المساعد غير مرتبط -> اظهر خيار القارئ
    return ElevatedButton.icon(
      onPressed: _openQRScanner,
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text(
        'ربط بالمصنع (QR أو كود)',
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

  Widget _buildLinkedStatusBox(String factoryId, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'هذا الجهاز مرتبط بنجاح بالمصنع: $factoryId',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (!isAdmin) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                onPressed: _handleUnlink,
                icon: const Icon(Icons.link_off, size: 20),
                label: const Text('فك ارتباط هذا الجهاز', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleUnlink() async {
    final authService = context.read<AuthService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('⚠️ فك الارتباط', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text('هل أنت متأكد من فك الارتباط؟ سيتم حذف كافة البيانات المحلية (التقارير، العمال، المقاسات) من هذا الجهاز وإيقاف المزامنة فوراً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('فك الارتباط الآن'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // تفريغ القواعد المحلية
      try {
        if (Hive.isBoxOpen('flexo_live_sessions')) await Hive.box<LiveSession>('flexo_live_sessions').clear();
        if (Hive.isBoxOpen('savedSheetSizes')) await Hive.box('savedSheetSizes').clear();
        if (Hive.isBoxOpen('workers_flexo')) await Hive.box<Worker>('workers_flexo').clear();
        if (Hive.isBoxOpen('inkReports')) await Hive.box('inkReports').clear();
        if (Hive.isBoxOpen('sync_queue')) await Hive.box('sync_queue').clear();
        debugPrint('🧹 تم تفريغ جميع قواعد البيانات المحلية بنجاح.');
      } catch (e) {
        debugPrint('❌ فشل تفريغ القواعد المحلية: $e');
      }

      await authService.unlinkFactory();
      
      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: "تم فك ارتباط الجهاز ومسح البيانات بنجاح",
          backgroundColor: Colors.redAccent,
          icon: Icons.delete_sweep,
        );
      }
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

    setState(() => _isLoading = true);

    // توليد كود عشوائي من 6 أرقام
    final random = Random();
    final String shortCode = (100000 + random.nextInt(900000)).toString();

    // حفظ الكود في جدول pairing_codes بصلاحية 5 دقائق
    try {
      await Supabase.instance.client.from('pairing_codes').insert({
        'factory_id': factoryId,
        'pairing_code': shortCode,
        'expires_at': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: "فشل توليد كود الربط، تحقق من الاتصال بالإنترنت.",
          backgroundColor: Colors.red,
          icon: Icons.error_outline,
        );
      }
      return;
    }

    setState(() => _isLoading = false);

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
                'وجه هاتف المساعد نحو الكود، أو أعطه كود الربط اليدوي',
                style: TextStyle(fontSize: 15, color: Colors.grey),
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
              const Text('كود الربط اليدوي:', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shortCode,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shortCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ الكود')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
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
    final TextEditingController codeController = TextEditingController();
    
    final String? result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Colors.blue),
            SizedBox(width: 10),
            Text('ربط الجهاز يدوياً'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل كود الربط المكون من 6 خانات أو المعرف الكامل للمصنع:'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'كود الربط',
                hintText: 'مثال: 550E84',
                counterText: '',
              ),
              maxLength: 36, // لدعم UUID أيضاً
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters, // تحويل تلقائي للحروف الكبيرة
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, codeController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('تأكيد الربط'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
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
        await authService.refreshUserData();
        await _checkBackupExists();
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
