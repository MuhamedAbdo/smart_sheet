import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:smart_sheet/controllers/item_history_controller.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/widgets/smart_sheet_card.dart';

/// واجهة عرض سجل التعديلات (Timeline BottomSheet / Dialog)
class ItemEditHistorySheet extends StatefulWidget {
  final String itemId;
  final String productName;
  final String productCode;
  final String clientName;

  const ItemEditHistorySheet({
    super.key,
    required this.itemId,
    required this.productName,
    required this.productCode,
    required this.clientName,
  });

  /// دالة مساعدة لفتح الـ BottomSheet بسهولة من أي مكان
  static Future<bool?> show(
    BuildContext context, {
    required String itemId,
    required String productName,
    required String productCode,
    required String clientName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemEditHistorySheet(
        itemId: itemId,
        productName: productName,
        productCode: productCode,
        clientName: clientName,
      ),
    );
  }

  @override
  State<ItemEditHistorySheet> createState() => _ItemEditHistorySheetState();
}

class _ItemEditHistorySheetState extends State<ItemEditHistorySheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyList = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    // 1. قراءة السجل من الكاش المحلي وطابور المزامنة فوراً (حتى لو أوفلاين)
    final localData = await ItemHistoryController.getLocalHistory(widget.itemId);
    if (mounted) {
      setState(() {
        _historyList = localData;
        if (localData.isNotEmpty) {
          _isLoading = false;
        }
      });
    }

    // 2. عند وجود اتصال، جلب التعديلات الجديدة من Supabase وتحديث الـ UI
    try {
      final remoteData = await ItemHistoryController.fetchRemoteHistory(widget.itemId);
      if (mounted) {
        setState(() {
          _historyList = remoteData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ℹ️ [ItemEditHistorySheet] استمرار العمل بالكاش المحلي (أوفلاين): $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'تاريخ غير معروف';
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      return DateFormat('yyyy/MM/dd - hh:mm a').format(dt);
    } catch (_) {
      return timestamp.toString();
    }
  }

  /// حوار التأكيد واستدعاء منطق الاستعادة
  Future<void> _showRestoreDialog({
    required Map<String, dynamic> targetData,
    required String title,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.restore, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            "هل أنت متأكد من استعادة هذه المقاسات؟ سيتم تطبيق المقاسات القديمة وتسجيل هذا الإجراء كتعديل جديد.",
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text(
                "تأكيد الاستعادة",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    final success = await ItemHistoryController.restoreHistoryVersion(
      widget.itemId,
      targetData,
    );

    if (!mounted) return;

    if (success) {
      // إغلاق الـ BottomSheet بعد نجاح الاستعادة
      Navigator.of(context).pop(true);
      UIUtils.showInfoSnackBar(
        message: "تم استعادة النسخة بنجاح وتطبيق المقاسات",
        backgroundColor: Colors.green,
        icon: Icons.check_circle_outline,
      );
    } else {
      setState(() => _isLoading = false);
      UIUtils.showInfoSnackBar(
        message: "تعذر استعادة المقاسات. يرجى المحاولة مرة أخرى.",
        backgroundColor: Colors.red,
        icon: Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // مقبض السحب العلوي (Drag Handle)
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // رأس الـ BottomSheet (Header)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: Colors.amber.shade700,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "سجل التعديلات",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${widget.productName.isNotEmpty ? widget.productName : 'صنف'} ${widget.productCode.isNotEmpty ? '(${widget.productCode})' : ''} — ${widget.clientName}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // المحتوى الرئيسي
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2.5),
                          SizedBox(height: 14),
                          Text(
                            "جاري تحميل سجل التعديلات...",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : _historyList.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _loadHistory,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            itemCount: _historyList.length,
                            itemBuilder: (context, index) {
                              final item = _historyList[index];
                              final isFirst = index == 0;
                              final isLast = index == _historyList.length - 1;
                              return _buildTimelineItem(
                                item: item,
                                isFirst: isFirst,
                                isLast: isLast,
                                isDark: isDark,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// واجهة حالة عدم وجود تعديلات سابقة
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 54,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "لا يوجد سجل تعديلات لهذا الصنف حتى الآن.",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "لم يتم تسجيل أي تعديلات سابقة على أبعاد أو بيانات هذا الصنف حتى الآن.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء عنصر واحد في التايم لاين (Timeline Node + Card)
  Widget _buildTimelineItem({
    required Map<String, dynamic> item,
    required bool isFirst,
    required bool isLast,
    required bool isDark,
  }) {
    final oldData = Map<String, dynamic>.from(item['old_data'] as Map? ?? {});
    final newData = Map<String, dynamic>.from(item['new_data'] as Map? ?? {});
    final diffs = ItemHistoryController.computeDifferences(oldData, newData);
    final editedAtStr = _formatDateTime(item['edited_at']);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عمود خط التايم لاين والأيقونة
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isFirst ? Colors.blue.shade600 : Colors.amber.shade700,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isFirst ? Colors.blue : Colors.amber)
                          .withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isFirst ? Icons.edit_note_rounded : Icons.history_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 14),

          // بطاقة التعديل ومقارنة القيم
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SmartSheetCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // تاريخ ووقت التعديل
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 15,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                editedAtStr,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (ItemHistoryController.getOperationType(oldData, newData) == 'تكسير'
                                        ? Colors.orange
                                        : Colors.blue)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ItemHistoryController.getOperationType(oldData, newData),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: ItemHistoryController.getOperationType(oldData, newData) == 'تكسير'
                                      ? Colors.orange.shade800
                                      : Colors.blue.shade700,
                                ),
                              ),
                            ),
                            if (isFirst)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "آخر تعديل",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            // زر استعادة هذا التعديل
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: 'استعادة هذا التعديل',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                              onPressed: () => _showRestoreDialog(
                                targetData: newData.isNotEmpty ? newData : oldData,
                                title: "استعادة التعديل",
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // قائمة التغييرات المسجلة
                        if (diffs.isEmpty)
                          const Text(
                            "تحديث في بيانات الصنف (لا توجد تغييرات نصية)",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        else
                          ...diffs.map((diff) => _buildDiffRow(diff, isDark)),
                      ],
                    ),
                  ),
                  if (isLast) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade800,
                        side: BorderSide(color: Colors.amber.shade700, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                          vertical: 11,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.restore, size: 20),
                      label: const Text(
                        "استعادة الأصل (Restore Original)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () {
                        final oldestData = Map<String, dynamic>.from(
                          item['old_data'] as Map? ?? {},
                        );
                        _showRestoreDialog(
                          targetData: oldestData,
                          title: "استعادة الأصل",
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء صف تفصيلي لكل حقل تغير (القيمة القديمة ⬅️ القيمة الجديدة)
  Widget _buildDiffRow(ItemFieldDiff diff, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              diff.icon,
              size: 16,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                diff.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // القيمة القديمة
            _buildValueBox(
              value: diff.oldValue,
              color: Colors.red,
              isOld: true,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 15,
                color: Colors.grey,
              ),
            ),

            // القيمة الجديدة
            _buildValueBox(
              value: diff.newValue,
              color: Colors.green,
              isOld: false,
            ),
          ],
        ),
      ),
    );
  }

  /// مربع عرض القيمة (موحد المقاسات عبر كل الحقول دون تشويه أو تصغير)
  Widget _buildValueBox({
    required String value,
    required MaterialColor color,
    required bool isOld,
  }) {
    return Container(
      width: 70,
      height: 28,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            color: color.shade700,
            fontWeight: isOld ? FontWeight.w500 : FontWeight.bold,
            decoration: isOld ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
