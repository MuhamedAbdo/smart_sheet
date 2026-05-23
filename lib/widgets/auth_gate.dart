import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/screens/home_screen.dart';
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:smart_sheet/services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isAuthenticated = authService.isAuthenticated;

    if (isAuthenticated) {
      return const HomeScreen();
    }
    return const AuthScreen();
  }
}
