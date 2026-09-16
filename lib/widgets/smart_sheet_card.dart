import 'package:flutter/material.dart';

class SmartSheetCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const SmartSheetCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 12.0),
    this.padding = EdgeInsets.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white, // Stark white for light mode
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            )
          else
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
