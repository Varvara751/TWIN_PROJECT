import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalProfileStore {
  LocalProfileStore._();

  static final LocalProfileStore instance = LocalProfileStore._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dbPath, 'twin_local.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          create table local_profiles (
            user_id text primary key,
            data text not null,
            updated_at text not null
          )
        ''');
        await db.execute('''
          create table local_profile_photos (
            id integer primary key autoincrement,
            user_id text not null,
            image_url text,
            local_path text,
            storage_path text,
            synced integer not null default 0,
            created_at text not null
          )
        ''');
        await db.execute('''
          create table sync_queue (
            id integer primary key autoincrement,
            user_id text not null,
            type text not null,
            payload text not null,
            attempts integer not null default 0,
            created_at text not null
          )
        ''');
      },
    );
    _db = db;
    return db;
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final db = await database;
    final rows = await db.query(
      'local_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(rows.first['data'] as String));
  }

  Future<void> saveProfile(String userId, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('local_profiles', {
      'user_id': userId,
      'data': jsonEncode(data),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPhotos(String userId) async {
    final db = await database;
    final rows = await db.query(
      'local_profile_photos',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at desc',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> replaceRemotePhotos(
    String userId,
    List<Map<String, dynamic>> photos,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'local_profile_photos',
        where: 'user_id = ? and synced = 1',
        whereArgs: [userId],
      );
      for (final photo in photos) {
        await txn.insert('local_profile_photos', {
          'user_id': userId,
          'image_url': photo['image_url'],
          'storage_path': photo['storage_path'],
          'local_path': null,
          'synced': 1,
          'created_at':
              photo['created_at']?.toString() ??
              DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<int> addLocalPhoto(String userId, String localPath) async {
    final db = await database;
    return db.insert('local_profile_photos', {
      'user_id': userId,
      'local_path': localPath,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markPhotoSynced({
    required int localId,
    required String imageUrl,
    required String storagePath,
  }) async {
    final db = await database;
    await db.update(
      'local_profile_photos',
      {'image_url': imageUrl, 'storage_path': storagePath, 'synced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> enqueue({
    required String userId,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'user_id': userId,
      'type': type,
      'payload': jsonEncode(payload),
      'attempts': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> queue(String userId) async {
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at asc',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<bool> hasPendingSync(String userId) async {
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      columns: ['id'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> removeQueueItem(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementQueueAttempts(int id) async {
    final db = await database;
    await db.rawUpdate(
      'update sync_queue set attempts = attempts + 1 where id = ?',
      [id],
    );
  }

  Future<void> deletePhoto(int id) async {
    final db = await database;
    await db.delete('local_profile_photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> removePhotoUploadQueueItem(int localPhotoId) async {
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      columns: ['id', 'payload'],
      where: 'type = ?',
      whereArgs: ['photo_upload'],
    );
    for (final row in rows) {
      final payload = Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String),
      );
      if (payload['localPhotoId'] == localPhotoId) {
        await removeQueueItem(row['id'] as int);
      }
    }
  }

  Future<void> clearUserData(String userId) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        'sync_queue',
        'local_profile_photos',
        'local_profiles',
      ]) {
        await txn.delete(table, where: 'user_id = ?', whereArgs: [userId]);
      }
    });
  }
}
