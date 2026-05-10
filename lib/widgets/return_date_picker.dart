import 'package:flutter/material.dart';

/// Custom return date picker widget for worker actions
class ReturnDatePicker extends StatefulWidget {
  final DateTime? initialDate;
  final String? label;
  final ValueChanged<DateTime?>? onDateChanged;

  const ReturnDatePicker({
    super.key,
    required this.label,
    this.initialDate,
    this.onDateChanged,
  });

  @override
  State<ReturnDatePicker> createState() => _ReturnDatePickerState();
}

class _ReturnDatePickerState extends State<ReturnDatePicker> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label ?? "",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initialDate?.toString() ?? "اختر التاريخ",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: widget.initialDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      widget.onDateChanged?.call(picked);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
