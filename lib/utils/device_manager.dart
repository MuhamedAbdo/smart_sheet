import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class DeviceManager {
  static Future<String> getDeviceId() async {
    final box = Hive.isBoxOpen('settings') 
        ? Hive.box('settings') 
        : await Hive.openBox('settings');
        
    String? deviceId = box.get('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await box.put('device_id', deviceId);
    }
    return deviceId;
  }
}
