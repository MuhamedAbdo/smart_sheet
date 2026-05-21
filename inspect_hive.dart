import 'dart:io';
import 'package:hive/hive.dart';

void main() async {
  print('=== Inspecting Hive Boxes ===');
  final path = 'C:\\Users\\MuhamedAbdo\\Documents';
  Hive.init(path);
  
  try {
    final box = await Hive.openBox('settings');
    print('Box settings opened successfully.');
    print('Keys: ${box.keys.toList()}');
    print('isDarkTheme: ${box.get('isDarkTheme')}');
    print('fontScale: ${box.get('fontScale')}');
    print('shiftStartHour: ${box.get('shiftStartHour')}');
    print('shiftStartMinute: ${box.get('shiftStartMinute')}');
    print('shiftEndHour: ${box.get('shiftEndHour')}');
    print('shiftEndMinute: ${box.get('shiftEndMinute')}');
    await box.close();
  } catch (e) {
    print('Error opening settings box: $e');
  }

  try {
    final box = await Hive.openBox('sync_queue');
    print('\nBox sync_queue opened successfully.');
    print('Length: ${box.length}');
    for (var i = 0; i < box.length; i++) {
      print('Item $i: ${box.getAt(i)}');
    }
    await box.close();
  } catch (e) {
    print('Error opening sync_queue box: $e');
  }
}
