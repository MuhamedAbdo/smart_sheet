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
      children: [
        _buildCheckboxRow(
          "أوڨر فلاب",
          isOverFlap,
          onOverFlapChanged,
          "فلاب",
          isFlap,
          onFlapChanged,
        ),
        _buildCheckboxRow(
          "1 فلاب",
          isOneFlap,
          onOneFlapChanged,
          "2 فلاب",
          isTwoFlap,
          onTwoFlapChanged,
        ),
        CheckboxListTile(
          title: const Text("إضافة 2 مللم"),
          value: addTwoMm,
          onChanged: onAddTwoMmChanged,
        ),
        _buildCheckboxRow(
          "ص",
          isFullSize,
          onFullSizeChanged,
          "1/2 ص",
          !isFullSize && !isQuarterSize,
          (value) {
            onFullSizeChanged(!value!);
            onQuarterSizeChanged(false);
          },
        ),
        CheckboxListTile(
          title: const Text("1/4 ص"),
          value: isQuarterSize,
          onChanged: onQuarterSizeChanged,
        ),
        if (isQuarterSize)
          _buildCheckboxRow(
            "عرض",
            isQuarterWidth,
            onQuarterWidthChanged,
            "طول",
            !isQuarterWidth,
            (value) => onQuarterWidthChanged(!value!),
          ),
      ],
    );
  }

  Widget _buildCheckboxRow(
    String title1,
    bool value1,
    Function(bool?) onChanged1,
    String title2,
    bool value2,
    Function(bool?) onChanged2,
  ) {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            title: Text(title1),
            value: value1,
            onChanged: onChanged1,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: CheckboxListTile(
            title: Text(title2),
            value: value2,
            onChanged: onChanged2,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
