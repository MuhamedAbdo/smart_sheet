import 'package:flutter/material.dart';

class ArchiveDetailScreen extends StatelessWidget {
  final Map<String, dynamic> record;

  const ArchiveDetailScreen({super.key, required this.record});

  /// تحويل وقت ISO 8601 أو HH:mm أو أي صيغة إلى HH:mm فقط
  String _formatTime(dynamic raw) {
    if (raw == null) return '--:--';
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null' || s == '--:--') return '--:--';
    // حاول تحليلها كـ DateTime (يدعم ISO 8601)
    final dt = DateTime.tryParse(s);
    if (dt != null) {
      final local = dt.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    // إذا كان بصيغة HH:mm مباشرة
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(s)) {
      return s.substring(0, 5);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تفاصيل التقرير المؤرشف"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.event_note, "معلومات أساسية"),
            _buildDetailRow(context, "📅 التاريخ:", (record['date'] ?? record['reportDate'] ?? record['report_date'] ?? '---').toString().split('T')[0].split(' ')[0]),
            _buildDetailRow(context, "👤 العميل:", (record['clientName'] ?? record['client_name'] ?? record['customerName'] ?? record['customer_name'])?.toString() ?? '---'),
            Builder(builder: (context) {
              final productCode = record['productCode'] ?? record['product_code'] ?? record['itemCode'] ?? record['item_code'];
              final productName = record['product'] ?? record['product_name'] ?? record['itemName'] ?? record['item_name'] ?? '---';
              return _buildDetailRow(context, "📦 الصنف:",
                  "$productName ${productCode != null && productCode.toString().isNotEmpty ? '[ $productCode ]' : ''}");
            }),
            Builder(builder: (context) {
              final orderNumber = record['orderNumber'] ?? record['order_number'] ?? record['workOrder'] ?? record['work_order'];
              if (orderNumber != null && orderNumber.toString().isNotEmpty) {
                return _buildDetailRow(context, "🔢 أمر التشغيل:", orderNumber.toString());
              }
              return const SizedBox.shrink();
            }),
            Builder(builder: (context) {
              final formNumber = record['formNumber'] ??
                  record['form_number'] ??
                  (record['dimensions'] is Map
                      ? (record['dimensions'] as Map)['form_number']
                      : null);
              if (formNumber != null && formNumber.toString().isNotEmpty) {
                return _buildDetailRow(context, "📄 رقم الفورمة:", formNumber.toString());
              }
              return const SizedBox.shrink();
            }),
            if (record['shift'] != null && record['shift'].toString().isNotEmpty && record['shift'] != 'null')
              _buildDetailRow(context, "🔄 الوردية:", record['shift'].toString()),
            const SizedBox(height: 20),

            _buildSectionHeader(Icons.precision_manufacturing, "بيانات التشغيل والماكينة"),
            _buildDetailRow(context, "⚙️ الماكينة:",
                (record['machineName'] ?? record['machine_name'])?.toString() ?? '---'),
            if ((record['technicianName'] ?? record['technician_name']) != null &&
                (record['technicianName'] ?? record['technician_name']).toString().isNotEmpty)
              _buildDetailRow(context, "👤 الفني المسؤول:",
                  (record['technicianName'] ?? record['technician_name']).toString()),
            Builder(builder: (context) {
              final crew = record['crewMembers'] ?? record['crew_members'];
              if (crew != null && crew is List && crew.isNotEmpty) {
                return _buildDetailRow(context, "👥 طاقم العمل:", crew.join('، '));
              }
              return const SizedBox.shrink();
            }),
            Builder(builder: (context) {
              final sTime = record['startTime'] ?? record['start_time'] ?? record['run_time_start'] ?? record['runTimeStart'];
              final eTime = record['endTime'] ?? record['end_time'] ?? record['run_time_end'] ?? record['runTimeEnd'];
              final sFormatted = _formatTime(sTime);
              final eFormatted = _formatTime(eTime);
              if (sFormatted != '--:--' || eFormatted != '--:--') {
                return _buildDetailRow(context, "🕒 وقت التشغيل:",
                    "$sFormatted  ◀  $eFormatted");
              }
              return const SizedBox.shrink();
            }),
            Builder(
              builder: (context) {
                final dStart = record['downtimeStart'] ?? record['downtime_start'];
                final dEnd = record['downtimeEnd'] ?? record['downtime_end'];
                final rawTotal = record['totalDowntime'] ?? record['total_downtime'];
                final int totalDt = rawTotal is num
                    ? rawTotal.toInt()
                    : int.tryParse(rawTotal?.toString() ?? '0') ?? 0;
                String dtDisplay = "";
                if ((dStart != null && dStart.toString().isNotEmpty) ||
                    (dEnd != null && dEnd.toString().isNotEmpty) ||
                    totalDt > 0) {
                  if (dStart != null && dStart.toString().isNotEmpty) {
                    final ds = _formatTime(dStart);
                    final de = _formatTime(dEnd);
                    dtDisplay += "$ds  ◀  $de";
                  }
                  if (totalDt > 0) {
                    dtDisplay += " (إجمالي: $totalDt دقيقة)";
                  }
                }
                if (dtDisplay.isEmpty) return const SizedBox.shrink();
                return _buildDetailRow(context, "⏱️ وقت الأعطال:", dtDisplay.trim());
              },
            ),
            const SizedBox(height: 20),

            _buildSectionHeader(Icons.straighten, "المقاسات والكميات والأوزان"),
            Builder(builder: (context) {
              final dept = record['department']?.toString();
              final mName = (record['machineName'] ?? record['machine_name'])?.toString() ?? '';
              final isCrushingDept = dept == 'crushing' || dept == 'die_cutting' || mName.contains('كسارة');
              final isProdLine = dept == 'production_line' || mName == 'خط الإنتاج';
              return _buildDimensionsDetails(context, record['dimensions'], isCrushing: isCrushingDept || isProdLine);
            }),
            _buildDetailRow(context, "🔢 الكمية:", "${record['quantity'] ?? record['production_quantity'] ?? record['productionQuantity'] ?? 0}"),
            Builder(
              builder: (context) {
                final dims = record['dimensions'] is Map
                    ? record['dimensions'] as Map
                    : {};
                final w = record['weight'] ??
                    record['weight_tons'] ??
                    dims['weight'];
                final double weightVal = w != null
                    ? (w is num
                        ? w.toDouble()
                        : (double.tryParse(w.toString()) ?? 0.0))
                    : 0.0;
                if (weightVal <= 0) return const SizedBox.shrink();
                return _buildDetailRow(context, "⚖️ الوزن:", "$weightVal طن");
              },
            ),
            Builder(
              builder: (context) {
                final dept = record['department']?.toString();
                final mName = (record['machineName'] ?? record['machine_name'])?.toString() ?? '';
                final isProdLine = dept == 'production_line' || mName == 'خط الإنتاج';
                final isCrushing = dept == 'crushing' || dept == 'die_cutting' || mName.contains('كسارة');
                final lineWaste = record['lineWaste'] ?? record['line_waste'] ?? record['wasteQuantity'] ?? record['waste_quantity'] ?? 0;
                final printWaste = record['printWaste'] ?? record['print_waste'] ?? 0;
                return _buildDetailRow(
                  context,
                  "📉 الهالك:",
                  (isProdLine || isCrushing)
                      ? "$lineWaste"
                      : "إنتاج: $lineWaste | طباعة: $printWaste",
                );
              },
            ),
            const SizedBox(height: 20),

            Builder(
              builder: (context) {
                final dims = record['dimensions'] is Map
                    ? record['dimensions'] as Map
                    : {};
                final rawLayers = record['paperLayers'] ??
                    record['paper_layers'] ??
                    dims['paperLayers'] ??
                    dims['paper_layers'];
                final List<String> layers = [];
                if (rawLayers is List) {
                  layers.addAll(rawLayers
                      .map((e) => e.toString().trim())
                      .where((e) => e.isNotEmpty));
                }
                if (layers.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.layers, "طبقات الورق"),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.brown.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.brown.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: layers
                            .asMap()
                            .entries
                            .map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    " • الطبقة ${e.key + 1}: ${e.value}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                );
              },
            ),

            Builder(
              builder: (context) {
                final dept = record['department']?.toString();
                final mName = (record['machineName'] ?? record['machine_name'])?.toString() ?? '';
                final isProdLine = dept == 'production_line' || mName == 'خط الإنتاج';
                // إخفاء الألوان لقسم التكسير (سواء بالقسم أو اسم الماكينة)
                final isCrushing = dept == 'crushing' || dept == 'die_cutting' ||
                    mName.contains('كسارة') || mName.contains('تكسير');
                if (isProdLine || isCrushing) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.palette, "الألوان والأحبار"),
                    _buildColorsList(record['colors'] ?? []),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

            if (record['notes'] != null && record['notes'].toString().trim().isNotEmpty) ...[
              _buildSectionHeader(Icons.description, "ملاحظات إضافية"),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  record['notes'].toString(),
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 10),
            Center(
              child: Text(
                "تاريخ الأرشفة: ${record['archiveDate'] ?? '---'}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionsDetails(BuildContext context, Map? d, {bool isCrushing = false}) {
    final String length = d?['length']?.toString() ?? '0';
    final String width = d?['width']?.toString() ?? '0';
    final String height = d?['height']?.toString() ?? '0';

    // التكسير: طول / عرض / ارتفاع (من اليمين لليسار) مثل باقي الأقسام
    // باقي الأقسام: ارتفاع / عرض / طول
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: isCrushing
            ? [
                _buildDimItem(context, "طول", length),
                _buildDimItem(context, "عرض", width),
                _buildDimItem(context, "ارتفاع", height),
              ]
            : [
                _buildDimItem(context, "ارتفاع", height),
                _buildDimItem(context, "عرض", width),
                _buildDimItem(context, "طول", length),
              ],
      ),
    );
  }

  Widget _buildDimItem(BuildContext context, String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          val,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildColorsList(List c) {
    if (c.isEmpty) return const Text("لا توجد ألوان مسجلة");
    return Column(
      children: c.map((i) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: const Icon(Icons.circle, color: Colors.blue),
          title: Text(i['color']?.toString() ?? ''),
          trailing: Text("${i['quantity']} لتر"),
        ),
      )).toList(),
    );
  }
}
