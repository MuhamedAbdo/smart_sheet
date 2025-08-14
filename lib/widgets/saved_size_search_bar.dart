// lib/src/widgets/saved/saved_size_search_bar.dart

import 'package:flutter/material.dart';

class SavedSizeSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const SavedSizeSearchBar({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: "بحث باستخدام كود الصنف أو اسم العميل...",
        hintStyle: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : Colors.black45,
        ),
        border: InputBorder.none,
      ),
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
      ),
      onChanged: onChanged,
      autofocus: true,
    );
  }
}
