// lib/src/widgets/results_widget.dart

import 'package:flutter/material.dart';

class ResultsWidget extends StatelessWidget {
  final double? a1;
  final double? t1;
  final double? a2;
  final double? t2;
  final bool isWidthActive;
  final List<String> labels;

  const ResultsWidget({
    super.key,
    required this.a1,
    required this.t1,
    required this.a2,
    required this.t2,
    required this.isWidthActive,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildResultRow(labels[0], a1),
        const SizedBox(height: 12),
        _buildResultRow(labels[1], t1),
        const SizedBox(height: 12),
        _buildResultRow(labels[2], a2),
        const SizedBox(height: 12),
        _buildResultRow(labels[3], t2),
      ],
    );
  }

  Widget _buildResultRow(String label, double? value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Text(
            value?.toStringAsFixed(2) ?? '--',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
