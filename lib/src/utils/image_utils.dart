import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageUtils {
  static Future<String> saveImage(String sourcePath, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = path.join(dir.path, 'faces', fileName);
    await Directory(path.dirname(dest)).create(recursive: true);
    await File(sourcePath).copy(dest);
    return dest;
  }

  static Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }
}
