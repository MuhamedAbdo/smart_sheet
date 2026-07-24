import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Check Supabase production_reports', () async {
    final supabase = SupabaseClient('https://lbvaezdeaisukxqwwrmk.supabase.co', 'sb_publishable_Twjk68loXnXuJIJKy1MkNQ_KdP1iKnQ');
    try {
      print('Fetching from production_reports...');
      final res = await supabase.from('production_reports').select();
      print('Total records in table: ${res.length}');
      
      Map<String, int> factoryCounts = {};
      Map<String, int> deptCounts = {};
      for (var r in res) {
        String fid = r['factory_id']?.toString() ?? 'null';
        String dept = r['department']?.toString() ?? 'null';
        factoryCounts[fid] = (factoryCounts[fid] ?? 0) + 1;
        deptCounts[dept] = (deptCounts[dept] ?? 0) + 1;
      }
      print('Factory IDs: $factoryCounts');
      print('Departments: $deptCounts');
      print('Sample: ${res.isNotEmpty ? res.last : 'Empty'}');
    } catch (e) {
      print('Error: $e');
    }
  });
}
