import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class Base64Service {
  static Future<String> imageFileToBase64(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  static Future<String> base64ToTempFile(String base64String) async {
    final bytes = base64Decode(base64String);
    final dir = await getTemporaryDirectory();
    final filePath = path.join(
      dir.path,
      'tc_ref_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  static Future<void> cleanupTempFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }
}
