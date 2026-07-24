import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

void main() {
  test('Check local factory ID', () async {
    const storage = FlutterSecureStorage();
    final fid = await storage.read(key: 'factory_id');
    debugPrint('Local factory ID: $fid');
  });
}
