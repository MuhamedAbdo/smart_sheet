import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:smart_sheet/screens/pdf_preview_screen.dart';
import 'package:smart_sheet/services/job_order_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/screens/manual_job_order_dialog.dart';
import 'package:smart_sheet/screens/select_client_dialog.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';

class IssuedWorkOrdersScreen extends StatefulWidget {
  const IssuedWorkOrdersScreen({super.key});

  @override
  State<IssuedWorkOrdersScreen> createState() => _IssuedWorkOrdersScreenState();
}

class _IssuedWorkOrdersScreenState extends State<IssuedWorkOrdersScreen> {
  List<MapEntry<dynamic, JobOrderData>> _orders = [];
  List<MapEntry<dynamic, JobOrderData>> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  RealtimeChannel? _syncChannel;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchCtrl.addListener(_applyFilter);
    _setupRealtimeSync();
  }

  void _setupRealtimeSync() {
    _syncChannel = Supabase.instance.client
        .channel('public:issued_job_orders_screen')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'issued_job_orders',
          callback: (payload) {
            // Re-fetch orders when any change happens on the server
            _loadOrders();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _syncChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final orders = await JobOrderService.getSavedOrders();
    setState(() {
      _orders = orders;
      _filtered = orders;
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _orders;
      } else {
        _filtered = _orders.where((e) {
          final d = e.value;
          return d.customerName.toLowerCase().contains(q) ||
              d.orderNumber.toLowerCase().contains(q) ||
              d.jobNumber.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _deleteOrder(dynamic key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف أمر التشغيل', textDirection: TextDirection.rtl),
        content: const Text(
          'هل أنت متأكد من حذف هذا الأمر؟ لا يمكن التراجع عن هذه العملية.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await JobOrderService.deleteOrder(key);
        _loadOrders();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل الحذف: $e', textDirection: TextDirection.rtl),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openPdf(JobOrderData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: 'أمر تشغيل — ${data.customerName}',
          buildPdf: (PdfPageFormat format) =>
              JobOrderService.generateNativePdf(data, format: format),
        ),
      ),
    );
  }

  void _showNewJobOrderOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('إصدار أمر تشغيل جديد',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ListTile(
                  leading:
                      const Icon(Icons.edit_document, color: Color(0xFF1a3a6e)),
                  title: const Text('طلب حر (عميل جديد / لمرة واحدة)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => const ManualJobOrderDialog(),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people, color: Color(0xFF1a3a6e)),
                  title: const Text('من سجل العملاء (عميل مسجل)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => const SelectClientDialog(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'أوامر التشغيل الصادرة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1a3a6e),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── شريط البحث ──────────────────────────────────────────────────────
          Container(
            color: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'بحث بالعميل أو رقم الطلبية أو أمر التشغيل...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── القائمة ─────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined,
                                size: 72,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              _searchCtrl.text.isEmpty
                                  ? 'لا توجد أوامر تشغيل صادرة بعد.\nسيتم حفظها هنا تلقائياً عند إصدارها.'
                                  : 'لا توجد نتائج للبحث.',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 15,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final entry = _filtered[i];
                          final d = entry.value;
                          return _OrderCard(
                            data: d,
                            onTap: () => _openPdf(d),
                            onDelete: () => _deleteOrder(entry.key),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Consumer<AuthService>(
        builder: (context, auth, _) {
          return ValueListenableBuilder<dynamic>(
            valueListenable: (Hive.isBoxOpen('workers')
                    ? Hive.box<Worker>('workers').listenable()
                    : ValueNotifier<Box<Worker>?>(null))
                as ValueListenable<dynamic>,
            builder: (context, box, child) {
              final isDesktop = MediaQuery.of(context).size.width > 600;
              final canIssue = PermissionHelper.canIssueJobOrders;

              if (isDesktop && canIssue) {
                return FloatingActionButton.extended(
                  onPressed: () {
                    _showNewJobOrderOptions(context);
                  },
                  label: const Text('إصدار أمر تشغيل',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  icon: const Icon(Icons.add),
                  backgroundColor: const Color(0xFF1a3a6e),
                  foregroundColor: Colors.white,
                );
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}

// ── بطاقة عرض أمر التشغيل ────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final JobOrderData data;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _OrderCard({
    required this.data,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasOrderNum = data.orderNumber.isNotEmpty;
    final hasJobNum = data.jobNumber.isNotEmpty;

    final auth = Provider.of<AuthService>(context, listen: false);
    final canDelete =
        auth.isAdmin || auth.currentUserEmail == data.creatorEmail;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── الصف الأول: الأيقونة + اسم العميل + زر الحذف ──────────────
              Row(
                children: [
                  // زر الحذف
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'حذف',
                      onPressed: onDelete,
                    ),
                  const Spacer(),
                  // اسم العميل
                  Expanded(
                    flex: 5,
                    child: Text(
                      data.customerName.isNotEmpty
                          ? data.customerName
                          : 'عميل غير مسمى',
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // الأيقونة
                  CircleAvatar(
                    backgroundColor:
                        const Color(0xFF1a3a6e).withValues(alpha: 0.12),
                    child: const Icon(Icons.assignment,
                        color: Color(0xFF1a3a6e), size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // ── الصف الثاني: تفاصيل الأمر ─────────────────────────────────
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (hasOrderNum)
                    _InfoChip(
                      icon: Icons.work_outline,
                      label: 'أمر تشغيل: ${data.orderNumber}',
                    ),
                  if (hasJobNum)
                    _InfoChip(
                      icon: Icons.tag,
                      label: 'طلبية رقم: ${data.jobNumber}',
                    ),
                  if (data.orderDate.isNotEmpty)
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: data.orderDate,
                    ),
                  if (data.items.isNotEmpty)
                    _InfoChip(
                      icon: Icons.inventory_2_outlined,
                      label: '${data.items.length} صنف',
                    ),
                ],
              ),

              // ── زر المعاينة ───────────────────────────────────────────────
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('معاينة / طباعة PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13),
            textDirection: TextDirection.rtl),
        const SizedBox(width: 4),
        Icon(icon, size: 14, color: Colors.grey),
      ],
    );
  }
}
