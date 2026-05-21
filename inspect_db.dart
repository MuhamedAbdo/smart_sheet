import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/config/constants.dart';

void main() async {
  debugPrint('=== Inspecting Supabase Factories Table (Pure Dart Client) ===');

  final client = SupabaseClient(
    supabaseUrl.trim(),
    supabaseAnonKey.trim(),
  );

  try {
    final data = await client.from('factories').select();
    debugPrint('Factories rows count BEFORE upsert: ${data.length}');
    for (var row in data) {
      debugPrint('Row: $row');
    }
  } catch (e) {
    debugPrint('Error: $e');
  }

  try {
    const factoryId = 'CP-2026';
    final payload = {
      'factory_id': factoryId,
      'shift_start_time': '11:00:00',
      'shift_end_time': '19:00:00',
    };
    debugPrint('Trying upsert with factory_id $factoryId...');
    final response = await client
        .from('factories')
        .upsert(payload, onConflict: 'factory_id');
    debugPrint('Upsert success: $response');
  } catch (e) {
    debugPrint('Upsert failed: $e');
  }

  try {
    final data = await client.from('factories').select();
    debugPrint('Factories rows count AFTER upsert: ${data.length}');
    for (var row in data) {
      debugPrint('Row: $row');
    }
  } catch (e) {
    debugPrint('Error: $e');
  }
}
