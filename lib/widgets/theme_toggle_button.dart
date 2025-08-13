// lib/src/widgets/buttons/theme_toggle_button.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return IconButton(
      icon:
          Icon(themeProvider.isDarkTheme ? Icons.dark_mode : Icons.light_mode),
      onPressed: themeProvider.toggleTheme,
      tooltip: themeProvider.isDarkTheme ? 'الوضع النهاري' : 'الوضع الليلي',
    );
  }
}
