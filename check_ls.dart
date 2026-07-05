import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/config/constants.dart';

void main() async {
  debugPrint('=== Inspecting live_sessions Table ===');
  final client = SupabaseClient(
    supabaseUrl.trim(),
    supabaseAnonKey.trim(),
  );

  try {
    final data = await client.from('live_sessions').select().limit(1);
    debugPrint('live_sessions rows sample: $data');
    if (data.isNotEmpty) {
      debugPrint('Columns: ${data.first.keys.toList()}');
    }
  } catch (e) {
    debugPrint('Error selecting live_sessions: $e');
  }
}
