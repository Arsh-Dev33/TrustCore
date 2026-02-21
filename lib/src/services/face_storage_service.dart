import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/face_record.dart';

class FaceStorageService {
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, 'trust_core.db');
    return openDatabase(dbPath, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE faces (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT UNIQUE NOT NULL,
          image_path TEXT NOT NULL,
          embedding TEXT NOT NULL,
          registered_at TEXT NOT NULL
        )
      ''');
    });
  }

  Future<void> storeFace(FaceRecord record) async {
    final db = await database;
    await db.insert(
      'faces',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<FaceRecord?> getFace(String userId) async {
    final db = await database;
    final result = await db.query(
      'faces',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) return null;
    return FaceRecord.fromMap(result.first);
  }

  Future<bool> isRegistered(String userId) async {
    final record = await getFace(userId);
    if (record == null) return false;
    return File(record.imagePath).existsSync();
  }

  Future<void> deleteFace(String userId) async {
    final record = await getFace(userId);
    if (record != null) {
      final file = File(record.imagePath);
      if (await file.exists()) await file.delete();
    }
    final db = await database;
    await db.delete('faces', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<List<String>> getAllUsers() async {
    final db = await database;
    final result = await db.query('faces', columns: ['user_id']);
    return result.map((r) => r['user_id'] as String).toList();
  }
}
