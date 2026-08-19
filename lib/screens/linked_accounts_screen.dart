import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:smart_sheet/widgets/worker_form.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/utils/ui_utils.dart';

class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _profiles = [];
  Map<String, String> _workerNames = {};

  @override
  void initState() {
    super.initState();
    _fetchLinkedAccounts();
  }

  Future<void> _fetchLinkedAccounts() async {
    setState(() => _isLoading = true);
    try {
      final factoryId = context.read<AuthService>().factoryId;
      if (factoryId == null) return;

      final profilesRes = await _supabase
          .from('profiles')
          .select('id, role, factory_id, status, email')
          .eq('factory_id', factoryId);

      final workersRes = await _supabase
          .from('workers')
          .select('email, name')
          .not('email', 'is', null);

      Map<String, String> namesMap = {};
      for (var w in workersRes) {
        if (w['email'] != null) {
          namesMap[w['email'].toString().toLowerCase().trim()] = w['name'].toString();
        }
      }

      setState(() {
        _profiles = List<Map<String, dynamic>>.from(profilesRes);
        _workerNames = namesMap;
      });
    } catch (e) {
      debugPrint('Error fetching linked accounts: $e');
      if (mounted) {
        UIUtils.showInfoSnackBar(message: 'فشل تحميل الحسابات المرتبطة', backgroundColor: Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unlinkAccount(String profileId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فك الارتباط'),
        content: const Text('هل أنت متأكد من فك ارتباط هذا الحساب؟ سيتم طرده نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('طرد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _supabase.from('profiles').update({'factory_id': null}).eq('id', profileId);
      UIUtils.showInfoSnackBar(message: 'تم فك ارتباط الحساب بنجاح', backgroundColor: Colors.green);
      _fetchLinkedAccounts();
    } catch (e) {
      UIUtils.showInfoSnackBar(message: 'فشل فك الارتباط', backgroundColor: Colors.red);
    }
  }

  Future<void> _toggleSuspend(String profileId, String currentStatus) async {
    final newStatus = currentStatus == 'suspended' ? 'active' : 'suspended';
    final actionName = newStatus == 'suspended' ? 'إيقاف' : 'تفعيل';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionName الحساب'),
        content: Text('هل أنت متأكد من $actionName هذا الحساب مؤقتاً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _supabase.from('profiles').update({'status': newStatus}).eq('id', profileId);
      UIUtils.showInfoSnackBar(message: 'تم $actionName الحساب بنجاح', backgroundColor: Colors.green);
      _fetchLinkedAccounts();
    } catch (e) {
      UIUtils.showInfoSnackBar(message: 'فشل $actionName الحساب', backgroundColor: Colors.red);
    }
  }

  Future<void> _showManualLinkDialog() async {
    if (!Hive.isBoxOpen('workers')) {
      UIUtils.showInfoSnackBar(message: 'سجل العمال غير متاح حالياً.', backgroundColor: Colors.red);
      return;
    }

    final box = Hive.box<Worker>('workers');
    final workers = box.values.toList();

    if (workers.isEmpty) {
      UIUtils.showInfoSnackBar(message: 'لا يوجد عمال مسجلين للربط.', backgroundColor: Colors.red);
      return;
    }

    Worker? selectedWorker;
    final emailController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text('ربط عامل بالمصنع (عبر حسابه)', textDirection: TextDirection.rtl),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('اختر العامل:', textDirection: TextDirection.rtl),
                  const SizedBox(height: 8),
                  DropdownButton<Worker>(
                    isExpanded: true,
                    hint: const Text('-- اختر العامل --'),
                    value: selectedWorker,
                    items: workers.map((w) {
                      return DropdownMenuItem<Worker>(
                        value: w,
                        child: Text(
                          w.name,
                          textDirection: TextDirection.rtl,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setStateSB(() {
                        selectedWorker = val;
                        // Auto-populate the email field if the worker already has an email
                        if (val != null && val.email != null && val.email!.isNotEmpty) {
                          emailController.text = val.email!;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('البريد الإلكتروني لحساب العامل:', textDirection: TextDirection.rtl),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      hintText: 'أدخل الإيميل الخاص بحساب العامل',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final accountEmail = emailController.text.trim();
                    if (selectedWorker == null) {
                      UIUtils.showInfoSnackBar(message: 'يرجى اختيار العامل.', backgroundColor: Colors.red);
                      return;
                    }
                    if (accountEmail.isEmpty) {
                      UIUtils.showInfoSnackBar(message: 'يرجى إدخال البريد الإلكتروني للحساب.', backgroundColor: Colors.red);
                      return;
                    }
                    
                    Navigator.pop(ctx);
                    _linkWorkerByEmail(accountEmail, selectedWorker!);
                  },
                  child: const Text('تأكيد الربط'),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Future<void> _linkWorkerByEmail(String accountEmail, Worker worker) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الربط'),
        content: Text('هل أنت متأكد من ربط حساب "$accountEmail"\nبالعامل "${worker.name}" في هذا المصنع؟\nسيتم السماح له بتسجيل الدخول فوراً.', textDirection: TextDirection.rtl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('جاري ربط الحساب بالمصنع...', textDirection: TextDirection.rtl),
          ],
        ),
      ),
    );

    try {
      final currentFactoryId = context.read<AuthService>().factoryId;

      // 1. البحث عن الحساب (profile) في السحابة بالإيميل لتحديث مصنعه
      final profileRes = await _supabase.from('profiles').select('id').eq('email', accountEmail).maybeSingle();
      
      if (profileRes != null) {
        // الحساب موجود، نربطه بالمصنع ونفعله
        await _supabase.from('profiles').update({
          'factory_id': currentFactoryId,
          'status': 'active'
        }).eq('id', profileRes['id']);
      }

      // 2. تحديث إيميل العامل وحالة الربط في Supabase
      if (worker.id != null && worker.id!.isNotEmpty) {
        await _supabase.from('workers').update({
          'email': accountEmail,
          'is_device_linked': true,
        }).eq('id', worker.id!);
      }

      // 3. تحديث محلي في Hive
      worker.email = accountEmail;
      worker.isDeviceLinked = true;
      
      final box = Hive.box<Worker>('workers');
      // البحث عن المفتاح الصحيح للتحديث
      final key = box.keys.firstWhere(
        (k) => box.get(k)?.id == worker.id || box.get(k)?.name == worker.name, 
        orElse: () => null
      );
      if (key != null) {
        await box.put(key, worker);
      }

      if (mounted) Navigator.pop(context); // إغلاق نافذة التحميل
      UIUtils.showInfoSnackBar(message: 'تم ربط الحساب والعامل بنجاح', backgroundColor: Colors.green);
      
      _fetchLinkedAccounts();
    } catch (e) {
      if (mounted) Navigator.pop(context); // إغلاق نافذة التحميل
      debugPrint('Error linking worker by email: $e');
      UIUtils.showInfoSnackBar(message: 'حدث خطأ أثناء الربط: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _managePermissions(String profileId, String role, String? email, String? workerName) async {
    if (email != null && email != 'غير متوفر' && workerName != null) {
      // العامل موجود بالفعل، نقوم بتخطي نافذة الإدخال وفتح بياناته مباشرة
      _openWorkerFormDirectly(email);
      return;
    }

    final nameController = TextEditingController(text: workerName ?? '');
    final emailController = TextEditingController(text: (email != 'غير متوفر') ? (email ?? '') : '');
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعداد سجل الصلاحيات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('لإدارة صلاحيات هذا الحساب، نحتاج لإنشاء سجل عامل له (أو ربطه بسجل موجود عبر الإيميل).'),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم الجهاز/الحساب (مثال: جهاز السكرتارية)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailController,
              readOnly: email != null && email != 'غير متوفر' && email.isNotEmpty,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني للحساب'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final currentFactoryId = context.read<AuthService>().factoryId;
              Navigator.pop(ctx);
              if (nameController.text.isEmpty || emailController.text.isEmpty) {
                UIUtils.showInfoSnackBar(message: 'يرجى إدخال البيانات', backgroundColor: Colors.red);
                return;
              }
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text('جاري إعداد الصلاحيات...'),
                    ],
                  ),
                ),
              );
              
              try {
                // Check if worker already exists by email
                final existingWorkers = await _supabase.from('workers').select().eq('email', emailController.text.trim());
                Worker workerObj;
                final box = Hive.box<Worker>('workers');
                
                if (existingWorkers.isNotEmpty) {
                  final data = existingWorkers.first;
                  workerObj = Worker.fromJson(data);
                  workerObj.id = data['id'];
                  workerObj.email = data['email'];
                } else {
                  // Create new worker
                  final newWorkerData = {
                    'name': nameController.text.trim(),
                    'email': emailController.text.trim(),
                    'job': 'إدارة/سكرتارية',
                    'department': 'general_mgmt',
                    'is_device_linked': true,
                    'factory_id': currentFactoryId,
                  };
                  
                  final inserted = await _supabase.from('workers').insert(newWorkerData).select().single();
                  workerObj = Worker.fromJson(inserted);
                  workerObj.id = inserted['id'];
                  workerObj.email = inserted['email'];
                }
                
                // Add or update in local Hive box
                bool found = false;
                for (int i = 0; i < box.length; i++) {
                  if (box.getAt(i)?.id == workerObj.id) {
                    await box.putAt(i, workerObj);
                    found = true;
                    break;
                  }
                }
                if (!found) {
                  await box.add(workerObj);
                }
                
                if (mounted) Navigator.pop(context); // Close loading
                
                // Open Worker Form
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => WorkerForm(
                      existingWorker: workerObj,
                      box: Hive.box<Worker>('workers'),
                    ),
                  );
                }
                
              } catch (e) {
                if (mounted) Navigator.pop(context);
                UIUtils.showInfoSnackBar(message: 'حدث خطأ: $e', backgroundColor: Colors.red);
              }
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWorkerFormDirectly(String email) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('جاري تحميل بيانات الصلاحيات...'),
          ],
        ),
      ),
    );

    try {
      final existingWorkers = await _supabase.from('workers').select().eq('email', email.trim());
      Worker workerObj;
      final box = Hive.box<Worker>('workers');
      
      if (existingWorkers.isNotEmpty) {
        final data = existingWorkers.first;
        workerObj = Worker.fromJson(data);
        workerObj.id = data['id'];
        workerObj.email = data['email'];

        // Add or update in local Hive box
        bool found = false;
        for (int i = 0; i < box.length; i++) {
          if (box.getAt(i)?.id == workerObj.id) {
            await box.putAt(i, workerObj);
            found = true;
            break;
          }
        }
        if (!found) {
          await box.add(workerObj);
        }
        
        if (mounted) Navigator.pop(context); // Close loading
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => WorkerForm(
              existingWorker: workerObj,
              box: Hive.box<Worker>('workers'),
            ),
          );
        }
      } else {
        if (mounted) Navigator.pop(context);
        UIUtils.showInfoSnackBar(message: 'لم يتم العثور على سجل العامل', backgroundColor: Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      UIUtils.showInfoSnackBar(message: 'حدث خطأ: $e', backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الحسابات المرتبطة'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLinkedAccounts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualLinkDialog,
        icon: const Icon(Icons.link, color: Colors.white),
        label: const Text('ربط حساب بعامل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? const Center(child: Text('لا توجد حسابات مرتبطة حالياً.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    final isSuspended = profile['status'] == 'suspended';
                    final role = profile['role'] ?? 'employee';
                    final email = profile['email']?.toString() ?? 'غير متوفر';
                    final workerName = _workerNames[email.toLowerCase().trim()];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSuspended ? Colors.redAccent : Colors.grey.shade300,
                          width: isSuspended ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isSuspended ? Colors.red.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
                          child: Icon(
                            role == 'admin' ? Icons.admin_panel_settings : Icons.computer,
                            color: isSuspended ? Colors.red : Colors.blue,
                          ),
                        ),
                        title: Text(workerName ?? 'حساب غير مسمى (ID: ${profile['id'].toString().substring(0, 8)})'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('الإيميل: $email', style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 2),
                            Text('الدور: ${role == 'admin' ? 'مدير' : 'جهاز مرتبط'}'),
                            const SizedBox(height: 4),
                            Text(
                              isSuspended ? 'الحالة: موقوف مؤقتاً' : 'الحالة: نشط',
                              style: TextStyle(
                                color: isSuspended ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: 'إدارة الصلاحيات',
                              icon: const Icon(Icons.security, color: Colors.blueGrey),
                              onPressed: () => _managePermissions(profile['id'], role, email, workerName),
                            ),
                            IconButton(
                              tooltip: isSuspended ? 'تفعيل الحساب' : 'إيقاف مؤقت',
                              icon: Icon(
                                isSuspended ? Icons.play_arrow : Icons.pause,
                                color: isSuspended ? Colors.green : Colors.orange,
                              ),
                              onPressed: () => _toggleSuspend(profile['id'], profile['status'] ?? 'active'),
                            ),
                            IconButton(
                              tooltip: 'فك الارتباط والطرد',
                              icon: const Icon(Icons.link_off, color: Colors.red),
                              onPressed: () => _unlinkAccount(profile['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
