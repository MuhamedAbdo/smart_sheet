import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

void main() async {
  debugPrint('=== Inspecting Hive Boxes ===');
  const path = 'C:\\Users\\MuhamedAbdo\\Documents';
  Hive.init(path);

  try {
    final box = await Hive.openBox('settings');
    debugPrint('Box settings opened successfully.');
    debugPrint('Keys: ${box.keys.toList()}');
    debugPrint('isDarkTheme: ${box.get('isDarkTheme')}');
    debugPrint('fontScale: ${box.get('fontScale')}');
    debugPrint('shiftStartHour: ${box.get('shiftStartHour')}');
    debugPrint('shiftStartMinute: ${box.get('shiftStartMinute')}');
    debugPrint('shiftEndHour: ${box.get('shiftEndHour')}');
    debugPrint('shiftEndMinute: ${box.get('shiftEndMinute')}');
    await box.close();
  } catch (e) {
    debugPrint('Error opening settings box: $e');
  }

  try {
    final box = await Hive.openBox('sync_queue');
    debugPrint('\nBox sync_queue opened successfully.');
    debugPrint('Length: ${box.length}');
    for (var i = 0; i < box.length; i++) {
      debugPrint('Item $i: ${box.getAt(i)}');
    }
    await box.close();
  } catch (e) {
    debugPrint('Error opening sync_queue box: $e');
  }
}
