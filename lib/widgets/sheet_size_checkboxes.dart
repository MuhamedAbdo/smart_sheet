// lib/src/widgets/sheet_size/sheet_size_checkboxes.dart

import 'package:flutter/material.dart';

class SheetSizeCheckboxes extends StatelessWidget {
  final bool isOverFlap;
  final bool isFlap;
  final bool isOneFlap;
  final bool isTwoFlap;
  final bool addTwoMm;
  final bool isFullSize;
  final bool isQuarterSize;
  final bool isQuarterWidth;
  final void Function(bool?) onOverFlapChanged;
  final void Function(bool?) onFlapChanged;
  final void Function(bool?) onOneFlapChanged;
  final void Function(bool?) onTwoFlapChanged;
  final void Function(bool?) onAddTwoMmChanged;
  final void Function(bool?) onFullSizeChanged;
  final void Function(bool?) onQuarterSizeChanged;
  final void Function(bool?) onQuarterWidthChanged;

  const SheetSizeCheckboxes({
    super.key,
    required this.isOverFlap,
    required this.isFlap,
    required this.isOneFlap,
    required this.isTwoFlap,
    required this.addTwoMm,
    required this.isFullSize,
    required this.isQuarterSize,
    required this.isQuarterWidth,
    required this.onOverFlapChanged,
    required this.onFlapChanged,
    required this.onOneFlapChanged,
    required this.onTwoFlapChanged,
    required this.onAddTwoMmChanged,
    required this.onFullSizeChanged,
    required this.onQuarterSizeChanged,
    required this.onQuarterWidthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // صف الأوفر فلاب والفلاب
        Row(
          children: [
            Expanded(
              child: _buildCompactCheckbox(
                "أوڨر فلاب",
                isOverFlap,
                onOverFlapChanged,
              ),
            ),
            Expanded(
              child: _buildCompactCheckbox(
                "فلاب",
                isFlap,
                onFlapChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // صف 1 فلاب و 2 فلاب
        Row(
          children: [
            Expanded(
              child: _buildCompactCheckbox(
                "1 فلاب",
                isOneFlap,
                onOneFlapChanged,
              ),
            ),
            Expanded(
              child: _buildCompactCheckbox(
                "2 فلاب",
                isTwoFlap,
                onTwoFlapChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // خيار الدوبل (إضافة 2 مللم)
        _buildCompactCheckbox(
          "دوبل (إضافة 2 مللم للفلاب)",
          addTwoMm,
          onAddTwoMmChanged,
        ),
        const Divider(height: 24),
        // خيارات المقاس (ص، 1/2 ص)
        Row(
          children: [
            Expanded(
              child: _buildCompactCheckbox(
                "ص",
                isFullSize,
                onFullSizeChanged,
              ),
            ),
            Expanded(
              child: _buildCompactCheckbox(
                "1/2 ص",
                !isFullSize && !isQuarterSize,
                (value) {
                  onFullSizeChanged(!value!);
                  onQuarterSizeChanged(false);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // خيار 1/4 ص
        _buildCompactCheckbox(
          "1/4 ص",
          isQuarterSize,
          onQuarterSizeChanged,
        ),
        if (isQuarterSize) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactCheckbox(
                  "عرض",
                  isQuarterWidth,
                  onQuarterWidthChanged,
                ),
              ),
              Expanded(
                child: _buildCompactCheckbox(
                  "طول",
                  !isQuarterWidth,
                  (value) => onQuarterWidthChanged(!value!),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCompactCheckbox(
    String title,
    bool value,
    void Function(bool?) onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
