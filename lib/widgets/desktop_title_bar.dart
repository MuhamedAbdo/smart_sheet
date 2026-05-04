import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class DesktopTitleBar extends StatelessWidget {
  const DesktopTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: WindowCaption(
          brightness: Theme.of(context).brightness,
          title: Row(
            children: [
              Image.asset(
                'assets/images/app_icon.jpg',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Smart Sheet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
