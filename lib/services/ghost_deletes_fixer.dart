import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/services/supabase_manager.dart';

class GhostDeletesFixer {
  static Future<String> executeFix() async {
    try {
      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) return '❌ لم يتم العثور على معرّف المصنع.';

      // 1. Download Backup
      final tempDir = await getTemporaryDirectory();
      final ghostFixDir = Directory(p.join(tempDir.path, 'ghost_fix'));
      if (ghostFixDir.existsSync()) {
        ghostFixDir.deleteSync(recursive: true);
      }
      ghostFixDir.createSync(recursive: true);

      final tempZipPath = p.join(ghostFixDir.path, 'backup.zip');
      final Uint8List bytes = await Supabase.instance.client.storage
          .from('backups')
          .download('$factoryId.zip');
      
      await File(tempZipPath).writeAsBytes(bytes);

      // 2. Unzip
      final inputStream = InputFileStream(tempZipPath);
      final archive = ZipDecoder().decodeBuffer(inputStream);
      for (var file in archive.files) {
        if (file.isFile) {
          final outputStream = OutputFileStream(p.join(ghostFixDir.path, file.name));
          file.writeContent(outputStream);
          outputStream.close();
        }
      }
      inputStream.close();

      // 3. Find flexo_production_reports_box.hive and rename it so Hive can open it without conflict
      File? originalInkFile;
      for (final entity in ghostFixDir.listSync(recursive: true)) {
        if (entity is File) {
          final bName = p.basename(entity.path).toLowerCase();
          if (bName == 'inkreports.hive' || bName == 'flexo_production_reports_box.hive') {
            originalInkFile = entity;
            break;
          }
        }
      }

      if (originalInkFile == null || !originalInkFile.existsSync()) {
        return '❌ لم يتم العثور على تقارير الإنتاج في النسخة الاحتياطية السحابية.';
      }
      
      final tempBoxName = 'ghost_inkreports_${DateTime.now().millisecondsSinceEpoch}';
      // Rename it in its CURRENT directory (which might be a sub-folder)
      final renamedInkFile = File(p.join(originalInkFile.parent.path, '$tempBoxName.hive'));
      originalInkFile.renameSync(renamedInkFile.path);

      // 4. Open the temp box from that specific sub-folder!
      final box = await Hive.openBox(tempBoxName, path: originalInkFile.parent.path);
      
      int recoveredCount = 0;
      const uuid = Uuid();

      for (int i = 0; i < box.length; i++) {
        final item = box.getAt(i);
        Map<String, dynamic> mapData;
        if (item is Map) {
          mapData = Map<String, dynamic>.from(item);
        } else {
          try {
            mapData = (item as dynamic).toJson();
          } catch (e) {
            continue;
          }
        }
          
        // Generate new IDs to escape the ghost deletes
        final newSyncId = uuid.v4();
        
        mapData['sync_id'] = newSyncId;
        mapData['factory_id'] = factoryId;
        mapData.remove('id'); // Let Supabase generate a new serial ID
        
        // Add (مستعاد) to notes
        final oldNotes = mapData['notes']?.toString() ?? '';
        if (!oldNotes.contains('(مستعاد)')) {
            mapData['notes'] = oldNotes.isEmpty ? '(مستعاد)' : '$oldNotes\n(مستعاد)';
        }

        // Format check for flexo_production_reports schema
        // Ensure client_name exists
        if (!mapData.containsKey('client_name') && mapData.containsKey('clientName')) {
            mapData['client_name'] = mapData['clientName'];
            mapData.remove('clientName');
        }
        
        // Upsert to Supabase
        try {
            await Supabase.instance.client.from('flexo_production_reports').upsert(mapData);
            recoveredCount++;
        } catch (e) {
            debugPrint('GhostFixer Error inserting record: $e');
        }
      }

      await box.close();
      if (ghostFixDir.existsSync()) {
        ghostFixDir.deleteSync(recursive: true);
      }

      return '✅ تم إنقاذ ورفع $recoveredCount تقرير بنجاح! ولن تتمكن الأجهزة القديمة من مسحها مجدداً.';
    } catch (e) {
      debugPrint('GhostFixer error: $e');
      return '❌ فشل في معالجة التقارير: $e';
    }
  }
}

