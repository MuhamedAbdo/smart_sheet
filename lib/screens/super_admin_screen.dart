import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _factoryNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _factoryNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createNewFactory() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        debugPrint('🔥 جاري إرسال الطلب إلى الدالة السحابية...');
        await Supabase.instance.client.functions.invoke(
          'create_factory_admin',
          body: {
            'factoryName': _factoryNameController.text.trim(),
            'adminEmail': _adminEmailController.text.trim(),
            'adminPassword': _adminPasswordController.text,
          },
        );

        debugPrint('✅ تم تنفيذ الطلب بنجاح!');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم إنشاء المصنع وحساب المدير بنجاح"),
            backgroundColor: Colors.green,
          ),
        );

        _factoryNameController.clear();
        _adminEmailController.clear();
        _adminPasswordController.clear();
      } on FunctionException catch (e) {
        debugPrint('❌ FunctionException Caught!');
        debugPrint('تفاصيل الخطأ (Details): ${e.details}');
        debugPrint('حالة الرد (Reason): ${e.reasonPhrase}');

        if (!mounted) return;
        
        String errorMessage = 'حدث خطأ غير متوقع';
        if (e.details is Map && (e.details as Map).containsKey('error')) {
          errorMessage = (e.details as Map)['error'].toString();
        } else if (e.details != null) {
          errorMessage = e.details.toString();
        } else if (e.reasonPhrase != null) {
          errorMessage = e.reasonPhrase!;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("فشل: $errorMessage"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        debugPrint('❌ General Error Caught: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ: $e"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _updateFactoryStatus(String factoryId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('factories')
          .update({'status': newStatus})
          .eq('factory_id', factoryId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'active' ? "تمت استعادة المصنع بنجاح" : "تم إيقاف المصنع مؤقتاً"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("حدث خطأ أثناء تحديث الحالة: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _hardDeleteFactory(String factoryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف النهائي"),
        content: const Text("هل أنت متأكد من أنك تريد حذف هذا المصنع نهائياً؟ سيتم حذف جميع البيانات المرتبطة به ولا يمكن التراجع عن هذا الإجراء."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("حذف نهائي"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('factories')
          .delete()
          .eq('factory_id', factoryId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم حذف المصنع نهائياً بنجاح"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error deleting factory: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("حدث خطأ أثناء الحذف: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAddFactoryTab() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings,
                        size: 64, color: Colors.red[800]),
                    const SizedBox(height: 16),
                    const Text(
                      "إضافة مصنع جديد",
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _factoryNameController,
                      decoration: const InputDecoration(
                        labelText: "اسم المصنع",
                        prefixIcon: Icon(Icons.factory),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال اسم المصنع';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _adminEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "البريد الإلكتروني لمدير المصنع",
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال البريد الإلكتروني';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'الرجاء إدخال بريد إلكتروني صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _adminPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "كلمة المرور المؤقتة",
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال كلمة المرور';
                        }
                        if (value.length < 6) {
                          return 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isLoading ? null : _createNewFactory,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "إنشاء المصنع وحساب المدير",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFactoriesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('factories')
          .stream(primaryKey: ['factory_id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }

        final allFactories = snapshot.data ?? [];
        final factories = allFactories.where((f) => f['status'] == 'active').toList();

        if (factories.isEmpty) {
          return const Center(child: Text('لا توجد مصانع نشطة'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: factories.length,
          itemBuilder: (context, index) {
            final factory = factories[index];
            final factoryId = factory['factory_id']?.toString() ?? '';
            final factoryName = factory['name']?.toString() ?? 'بدون اسم';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.factory, color: Colors.white),
                ),
                title: Text(factoryName),
                subtitle: Text('كود المصنع: $factoryId'),
                trailing: IconButton(
                  tooltip: 'إيقاف/حذف مؤقت',
                  icon: const Icon(Icons.pause_circle_filled, color: Colors.orange),
                  onPressed: () => _updateFactoryStatus(factoryId, 'suspended'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSuspendedFactoriesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('factories')
          .stream(primaryKey: ['factory_id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }

        final allFactories = snapshot.data ?? [];
        final factories = allFactories.where((f) => f['status'] == 'suspended').toList();

        if (factories.isEmpty) {
          return const Center(child: Text('سلة المحذوفات فارغة'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: factories.length,
          itemBuilder: (context, index) {
            final factory = factories[index];
            final factoryId = factory['factory_id']?.toString() ?? '';
            final factoryName = factory['name']?.toString() ?? 'بدون اسم';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.delete_outline, color: Colors.white),
                ),
                title: Text(factoryName),
                subtitle: Text('كود المصنع: $factoryId'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'استعادة',
                      icon: const Icon(Icons.restore, color: Colors.green),
                      onPressed: () => _updateFactoryStatus(factoryId, 'active'),
                    ),
                    IconButton(
                      tooltip: 'حذف نهائي',
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _hardDeleteFactory(factoryId),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red[800],
          foregroundColor: Colors.white,
          title: const Text("لوحة تحكم النظام (Super Admin)"),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.add_business), text: "إضافة مصنع"),
              Tab(icon: Icon(Icons.factory), text: "المصانع النشطة"),
              Tab(icon: Icon(Icons.delete_outline), text: "سلة المحذوفات"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAddFactoryTab(),
            _buildActiveFactoriesTab(),
            _buildSuspendedFactoriesTab(),
          ],
        ),
      ),
    );
  }
}
