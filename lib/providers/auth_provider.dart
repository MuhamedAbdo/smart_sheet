// // lib/src/providers/auth_provider.dart

// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class AuthProvider with ChangeNotifier {
//   User? _user;
//   User? get user => _user;
//   bool get isLoggedIn => _user != null;

//   AuthProvider() {
//     Supabase.instance.client.auth.onAuthStateChange.listen(_authChange);
//     _user = Supabase.instance.client.auth.currentSession?.user;
//     notifyListeners();
//   }

//   void _authChange(AuthState state) {
//     final user = state.session?.user;
//     if (_user?.id != user?.id) {
//       _user = user;
//       notifyListeners(); // ← مهم جدًا
//     }
//   }

//   Future<void> signOut() async {
//     await Supabase.instance.client.auth.signOut();
//   }
// }
