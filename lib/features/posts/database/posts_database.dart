import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class PostsDatabase {
  static final PostsDatabase instance = PostsDatabase._init();
  static Database? _database;

  PostsDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('posts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Increment version to force rebuild
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Clear all data on upgrade
        await db.execute('DROP TABLE IF EXISTS posts');
        await _createDB(db, newVersion);
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE posts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        type TEXT,
        content TEXT,
        author_data TEXT,
        media_data TEXT,
        stats_data TEXT,
        is_local INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_type_created ON posts(type, created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_sync_status ON posts(sync_status)
    ''');

    await db.execute('''
      CREATE INDEX idx_server_id ON posts(server_id)
    ''');
  }

  Future<int> insertPost(Map<String, dynamic> postData) async {
    final db = await database;
    return await db.insert('posts', postData);
  }

  Future<List<Map<String, dynamic>>> getPosts({
    String? type,
    String? excludeType,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (type != null && excludeType != null) {
      whereClause = 'WHERE type = ? AND type != ?';
      whereArgs = [type, excludeType];
    } else if (type != null) {
      whereClause = 'WHERE type = ?';
      whereArgs = [type];
    } else if (excludeType != null) {
      whereClause = 'WHERE type != ?';
      whereArgs = [excludeType];
    }

    final result = await db.rawQuery('''
      SELECT * FROM posts
      $whereClause
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    ''', [...whereArgs, limit, offset]);

    return result;
  }

  Future<List<Map<String, dynamic>>> getLocalPosts() async {
    final db = await database;
    return await db.query(
      'posts',
      where: 'is_local = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updatePost(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'posts',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updatePostByServerId(int serverId, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'posts',
      data,
      where: 'server_id = ?',
      whereArgs: [serverId],
    );
  }

  Future<int> deletePost(int id) async {
    final db = await database;
    return await db.delete(
      'posts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePostByServerId(int serverId) async {
    final db = await database;
    return await db.delete(
      'posts',
      where: 'server_id = ?',
      whereArgs: [serverId],
    );
  }

  Future<void> deleteOldPosts(int keepCount) async {
    final db = await database;
    await db.rawDelete('''
      DELETE FROM posts
      WHERE id NOT IN (
        SELECT id FROM posts
        ORDER BY created_at DESC
        LIMIT ?
      ) AND is_local = 0
    ''', [keepCount]);
  }

  Future<void> clearRemotePosts() async {
    final db = await database;
    await db.delete(
      'posts',
      where: 'is_local = ?',
      whereArgs: [0],
    );
  }

  Future<bool> postExists(int serverId) async {
    final db = await database;
    final result = await db.query(
      'posts',
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> upsertPosts(List<Map<String, dynamic>> posts) async {
    final db = await database;
    final batch = db.batch();

    for (final post in posts) {
      final serverId = post['server_id'];
      if (serverId != null) {
        final exists = await postExists(serverId);
        if (exists) {
          batch.update(
            'posts',
            post,
            where: 'server_id = ?',
            whereArgs: [serverId],
          );
        } else {
          batch.insert('posts', post);
        }
      }
    }

    await batch.commit(noResult: true);
  }

  /// Clear all posts from database
  Future<void> clearAllPosts() async {
    final db = await database;
    await db.delete('posts');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) await db.close();
    _database = null;
  }
}