import 'package:supabase/supabase.dart';
import 'package:smart_sheet/config/constants.dart';

void main() async {
  print('=== Inspecting Supabase Factories Table (Pure Dart Client) ===');
  
  final client = SupabaseClient(
    supabaseUrl.trim(),
    supabaseAnonKey.trim(),
  );

  try {
    final data = await client.from('factories').select();
    print('Factories rows count BEFORE upsert: ${data.length}');
    for (var row in data) {
      print('Row: $row');
    }
  } catch (e) {
    print('Error: $e');
  }

  try {
    final factoryId = 'CP-2026';
    final payload = {
      'factory_id': factoryId,
      'shift_start_time': '11:00:00',
      'shift_end_time': '19:00:00',
    };
    print('Trying upsert with factory_id $factoryId...');
    final response = await client.from('factories').upsert(payload, onConflict: 'factory_id');
    print('Upsert success: $response');
  } catch (e) {
    print('Upsert failed: $e');
  }

  try {
    final data = await client.from('factories').select();
    print('Factories rows count AFTER upsert: ${data.length}');
    for (var row in data) {
      print('Row: $row');
    }
  } catch (e) {
    print('Error: $e');
  }
}
