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
            _buildDetailRow("📅 التاريخ:", record['date'] ?? '---'),
            _buildDetailRow("👤 العميل:", record['clientName']?.toString() ?? '---'),
            _buildDetailRow("📦 الصنف:", record['product']?.toString() ?? '---'),
            const SizedBox(height: 20),
            
            _buildSectionHeader(Icons.straighten, "المقاسات"),
            _buildDimensionsDetails(record['dimensions']),
            _buildDetailRow("🔢 الكمية:", "${record['quantity'] ?? 0}"),
            const SizedBox(height: 20),
            
            _buildSectionHeader(Icons.palette, "الألوان والأحبار"),
            _buildColorsList(record['colors'] ?? []),
            const SizedBox(height: 20),
            
            if (record['notes'] != null && record['notes'].toString().isNotEmpty) ...[
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
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
            
            const SizedBox(height: 30),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDimensionsDetails(Map? d) {
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
          _buildDimItem("طول", length),
          _buildDimItem("عرض", width),
          _buildDimItem("ارتفاع", height),
        ],
      ),
    );
  }

  Widget _buildDimItem(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
