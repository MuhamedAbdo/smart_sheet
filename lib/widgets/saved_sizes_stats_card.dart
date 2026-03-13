import 'package:flutter/material.dart';

class SavedSizesStatsCard extends StatelessWidget {
  final int totalProducts;
  final int uniqueClients;

  const SavedSizesStatsCard({
    super.key,
    required this.totalProducts,
    required this.uniqueClients,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.indigo.shade900],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            context,
            icon: Icons.people_alt_rounded,
            label: "عدد العملاء",
            value: uniqueClients.toString(),
          ),
          VerticalDivider(color: Colors.white.withValues(alpha: 0.3), thickness: 1),
          _buildStatItem(
            context,
            icon: Icons.inventory_2_rounded,
            label: "إجمالي الأصناف",
            value: totalProducts.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}