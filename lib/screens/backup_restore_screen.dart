// lib/screens/backup_restore_screen.dart

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
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
  // 🆕 متغير جديد لحالة التقدم (0.0 إلى 1.0)
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchBackups();
  }

  @override
  void dispose() {
    _backupService.dispose();
    super.dispose();
  }

  Future<void> _fetchBackups() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final files = await _backupService.listBackups();
      setState(() {
        _backupFiles = files;
      });
    } catch (e) {
      setState(() {
        _message = '❌ فشل جلب النسخ الاحتياطية السحابية: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLocalBackup() async {
    setState(() {
      _isLoading = true;
      _message = 'جاري إنشاء وحفظ النسخة الاحتياطية محليًا...';
    });
    final result = await _backupService.createBackup();
    setState(() {
      _isLoading = false;
      _message = result;
    });
  }

  Future<void> _handleLocalRestore() async {
    setState(() {
      _isLoading = true;
      _message = 'جاري استعادة البيانات من ملف محلي...';
    });
    final result = await _backupService.restoreBackup();
    setState(() {
      _isLoading = false;
      _message = result;
    });
  }

  // 💡 التعديل: استخدام دالة onProgress لتحديث حالة التقدم
  Future<void> _handleCloudUpload() async {
    setState(() {
      _isLoading = true;
      _isUploading = true;
      _message = 'جاري إنشاء النسخة المحلية ورفعها إلى السحابة...';
      _uploadProgress = 0.0; // إعادة تعيين التقدم
    });

    try {
      final result = await _backupService.uploadToSupabase(
        onProgress: (progress) {
          // ✅ تحديث التقدم في الوقت الفعلي
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              final percentage = (_uploadProgress * 100).toStringAsFixed(1);
              if (progress < 1.0) {
                _message = 'جاري الرفع... ($percentage%)';
              } else {
                _message = 'اكتمل الرفع بنجاح!';
              }
            });
          }
        },
      );

      setState(() {
        _isLoading = false;
        _isUploading = false;
        _message = result;
        if (result?.startsWith('✅') == true) {
          _uploadProgress = 1.0; // تأكيد الوصول لـ 100%
        }
      });

      if (result?.startsWith('✅') == true) {
        await _fetchBackups(); // تحديث القائمة بعد الرفع
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isUploading = false;
        _message = '❌ فشل رفع النسخة الاحتياطية: ${e.toString()}';
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _handleCloudRestore(String filePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحذير! استعادة البيانات'),
        content: const Text(
          'هل أنت متأكد من أنك تريد استعادة هذه النسخة الاحتياطية؟ سيؤدي هذا إلى مسح جميع البيانات الحالية!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('نعم، استعادة'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _message = 'جاري تنزيل واستعادة البيانات من السحابة...';
      });
      final result = await _backupService.downloadAndRestore(filePath);
      setState(() {
        _isLoading = false;
        _message = result;
      });
      // لا نحتاج لإعادة تشغيل، بل نعتمد على رسالة المستخدم لإعادة التشغيل اليدوي
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي والاستعادة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchBackups,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- قسم الحالة والرسائل ---
            if (_isLoading)
              Column(
                children: [
                  Text(
                    _message ?? 'جاري المعالجة...',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_isUploading && _uploadProgress > 0.0)
                    // ✅ عرض شريط التقدم الدقيق أثناء الرفع
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: _uploadProgress, // القيمة الدقيقة للتقدم
                          minHeight: 10,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _uploadProgress < 1.0
                                ? Theme.of(context).primaryColor
                                : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(_uploadProgress * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: _uploadProgress < 1.0
                                    ? Theme.of(context).primaryColor
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_uploadProgress < 1.0)
                              Text(
                                'جاري الرفع...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            else
                              const Text(
                                'اكتمل!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    )
                  else if (_isLoading)
                    // شريط تحميل غير دقيق للعمليات الأخرى
                    const LinearProgressIndicator(),
                ],
              )
            else if (_message != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _message!.startsWith('✅')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        _message!.startsWith('✅') ? Colors.green : Colors.red,
                  ),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.startsWith('✅')
                        ? Colors.green[800]
                        : Colors.red[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // --- النسخ الاحتياطي المحلي ---
            _buildSectionTitle(
                'النسخ الاحتياطي/الاستعادة المحلية', Icons.sd_storage),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ نسخة محلية'),
                    onPressed: _isLoading ? null : _handleLocalBackup,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('استعادة من ملف'),
                    onPressed: _isLoading ? null : _handleLocalRestore,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // --- النسخ الاحتياطي السحابي (Supabase) ---
            _buildSectionTitle(
                'النسخ الاحتياطي السحابي (Supabase)', Icons.cloud_upload),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text('رفع نسخة جديدة إلى السحابة'),
              onPressed: _isLoading ? null : _handleCloudUpload,
            ),
            const SizedBox(height: 16),

            // --- قائمة النسخ الاحتياطية السحابية ---
            _buildSectionTitle(
                'النسخ الاحتياطية السحابية المتاحة', Icons.history),
            const SizedBox(height: 8),
            if (_isLoading && _backupFiles.isEmpty)
              const Center(child: Text('جاري تحميل القائمة...'))
            else if (_backupFiles.isEmpty)
              const Center(child: Text('لا توجد نسخ احتياطية سحابية متاحة.'))
            else
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _backupFiles.length,
                itemBuilder: (context, index) {
                  final file = _backupFiles[index];
                  // تنسيق اسم الملف
                  final displayFileName = file.name
                      .replaceFirst('manual_backups/', '')
                      .replaceFirst('_smart_sheet_backup.zip', '');
                  final dateTime = DateTime.tryParse(displayFileName);

                  // تنسيق الحجم
                  final sizeInKB = file.metadata?['size'] != null
                      ? (file.metadata!['size'] / 1024).toStringAsFixed(2)
                      : 'غير محدد';

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        dateTime != null
                            ? 'نسخة ${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} @ ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}'
                            : file.name ?? 'ملف غير معروف',
                      ),
                      subtitle: Text('الحجم: $sizeInKB KB'),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.cloud_download, color: Colors.red),
                        onPressed: _isLoading
                            ? null
                            : () => _handleCloudRestore(
                                p.join('manual_backups', file.name)),
                        tooltip:
                            'استعادة هذه النسخة (تحذير: سيمحو البيانات الحالية)',
                      ),
                    ),
                  );
                },
              ),

            const Divider(height: 32),

            // --- إدارة Bucket (لمستخدمي الويب) ---
            _buildSectionTitle('إدارة التخزين (للمطور/المشرف)', Icons.settings),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('الانتقال إلى Supabase Storage'),
              onPressed: () async {
                // URL للداشبورد
                const url = 'https://supabase.com/dashboard';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                } else {
                  setState(() => _message = '❌ لا يمكن فتح الرابط.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}
