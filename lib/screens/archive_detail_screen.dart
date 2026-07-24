import 'package:flutter/material.dart';

class ArchiveDetailScreen extends StatelessWidget {
  final Map<String, dynamic> record;

  const ArchiveDetailScreen({super.key, required this.record});

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
            _buildDetailRow(context, "📅 التاريخ:", record['date'] ?? '---'),
            _buildDetailRow(context, "👤 العميل:", record['clientName']?.toString() ?? '---'),
            _buildDetailRow(context, "📦 الصنف:",
                "${record['product']?.toString() ?? '---'} ${record['productCode'] != null && record['productCode'].toString().isNotEmpty ? '[ ${record['productCode']} ]' : ''}"),
            if (record['orderNumber'] != null && record['orderNumber'].toString().isNotEmpty)
              _buildDetailRow(context, "🔢 أمر التشغيل:", record['orderNumber'].toString()),
            if (record['formNumber'] != null && record['formNumber'].toString().isNotEmpty)
              _buildDetailRow(context, "📄 رقم الفورمة:", record['formNumber'].toString()),
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
            if ((record['startTime'] != null && record['startTime'].toString().isNotEmpty) ||
                (record['endTime'] != null && record['endTime'].toString().isNotEmpty))
              _buildDetailRow(context, "🕒 وقت التشغيل:",
                  "${record['startTime'] ?? '--:--'} إلى ${record['endTime'] ?? '--:--'}"),
            Builder(
              builder: (context) {
                final dStart = record['downtimeStart'] ?? record['downtime_start'];
                final dEnd = record['downtimeEnd'] ?? record['downtime_end'];
                final rawTotal = record['totalDowntime'];
                final int totalDt = rawTotal is num
                    ? rawTotal.toInt()
                    : int.tryParse(rawTotal?.toString() ?? '0') ?? 0;
                String dtDisplay = "";
                if ((dStart != null && dStart.toString().isNotEmpty) ||
                    (dEnd != null && dEnd.toString().isNotEmpty) ||
                    totalDt > 0) {
                  if (dStart != null && dStart.toString().isNotEmpty) {
                    dtDisplay += "$dStart إلى ${dEnd ?? ''}";
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
            _buildDimensionsDetails(context, record['dimensions']),
            _buildDetailRow(context, "🔢 الكمية:", "${record['quantity'] ?? 0}"),
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
                final lineWaste = record['lineWaste'] ?? 0;
                final printWaste = record['printWaste'] ?? 0;
                return _buildDetailRow(
                  context,
                  "📉 الهالك:",
                  isProdLine
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
                if (isProdLine) return const SizedBox.shrink();
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

  Widget _buildDimensionsDetails(BuildContext context, Map? d) {
    final String length = d?['length']?.toString() ?? '0';
    final String width = d?['width']?.toString() ?? '0';
    final String height = d?['height']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDimItem(context, "طول", length),
          _buildDimItem(context, "عرض", width),
          _buildDimItem(context, "ارتفاع", height),
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
