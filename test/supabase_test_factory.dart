import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  test('Check local factory ID', () async {
    final storage = FlutterSecureStorage();
    final fid = await storage.read(key: 'factory_id');
    print('Local factory ID: $fid');
  });
}
