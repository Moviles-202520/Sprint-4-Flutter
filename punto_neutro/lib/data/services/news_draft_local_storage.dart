import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/models/news_draft.dart';

/// Local SQLite storage for news drafts.
/// 
/// This storage provides:
/// - Persistent draft storage across app restarts
/// - Autosave support (called by AutosaveService)
/// - Draft resume capability
/// - Multiple drafts support (user can have several in progress)
class NewsDraftLocalStorage {
  static final NewsDraftLocalStorage _instance =
      NewsDraftLocalStorage._internal();
  static Database? _database;

  factory NewsDraftLocalStorage() => _instance;

  NewsDraftLocalStorage._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'news_drafts.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE news_drafts (
        draft_id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        category_id INTEGER,
        source_url TEXT,
        images TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        status TEXT NOT NULL,
        upload_error TEXT
      )
    ''');

    // Index for quick retrieval of drafts by status
    await db.execute(
        'CREATE INDEX idx_drafts_status ON news_drafts(status)');
    await db.execute(
        'CREATE INDEX idx_drafts_updated ON news_drafts(updated_at DESC)');
  }

  /// Save or update a draft
  /// This is called by autosave service periodically
  Future<int> saveDraft(NewsDraft draft) async {
    final db = await database;
    final now = DateTime.now();

    final data = {
      'title': draft.title,
      'content': draft.content,
      'category_id': draft.categoryId,
      'source_url': draft.sourceUrl,
      'images': jsonEncode(draft.images.map((img) => img.toJson()).toList()),
      'updated_at': now.toIso8601String(),
      'status': draft.status.name,
      'upload_error': draft.uploadError,
    };

    if (draft.draftId == null) {
      // New draft
      data['created_at'] = draft.createdAt.toIso8601String();
      return await db.insert('news_drafts', data);
    } else {
      // Update existing draft
      await db.update(
        'news_drafts',
        data,
        where: 'draft_id = ?',
        whereArgs: [draft.draftId],
      );
      return draft.draftId!;
    }
  }

  /// Get a specific draft by ID
  Future<NewsDraft?> getDraft(int draftId) async {
    final db = await database;
    final results = await db.query(
      'news_drafts',
      where: 'draft_id = ?',
      whereArgs: [draftId],
    );

    if (results.isEmpty) return null;
    return _draftFromJson(results.first);
  }

  /// Get all drafts (most recently updated first)
  Future<List<NewsDraft>> getAllDrafts() async {
    final db = await database;
    final results = await db.query(
      'news_drafts',
      orderBy: 'updated_at DESC',
    );

    return results.map((json) => _draftFromJson(json)).toList();
  }

  /// Get drafts by status
  Future<List<NewsDraft>> getDraftsByStatus(DraftStatus status) async {
    final db = await database;
    final results = await db.query(
      'news_drafts',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'updated_at DESC',
    );

    return results.map((json) => _draftFromJson(json)).toList();
  }

  /// Get drafts that are ready to upload (valid + images processed + not uploading)
  Future<List<NewsDraft>> getUploadReadyDrafts() async {
    final drafts = await getDraftsByStatus(DraftStatus.saved);
    return drafts.where((draft) => draft.isReadyToUpload).toList();
  }

  /// Delete a draft
  Future<void> deleteDraft(int draftId) async {
    final db = await database;
    await db.delete(
      'news_drafts',
      where: 'draft_id = ?',
      whereArgs: [draftId],
    );
  }

  /// Delete all drafts (for cleanup or testing)
  Future<void> deleteAllDrafts() async {
    final db = await database;
    await db.delete('news_drafts');
  }

  /// Delete drafts older than specified days
  Future<int> deleteOldDrafts(int daysOld) async {
    final db = await database;
    final cutoffDate =
        DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();

    return await db.delete(
      'news_drafts',
      where: 'updated_at < ? AND status != ?',
      whereArgs: [cutoffDate, DraftStatus.uploading.name],
    );
  }

  /// Update draft status (used by upload worker)
  Future<void> updateDraftStatus(
    int draftId,
    DraftStatus status, {
    String? uploadError,
  }) async {
    final db = await database;
    await db.update(
      'news_drafts',
      {
        'status': status.name,
        'upload_error': uploadError,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'draft_id = ?',
      whereArgs: [draftId],
    );
  }

  /// Update images in a draft (after processing completes)
  Future<void> updateDraftImages(
      int draftId, List<DraftImage> images) async {
    final db = await database;
    await db.update(
      'news_drafts',
      {
        'images': jsonEncode(images.map((img) => img.toJson()).toList()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'draft_id = ?',
      whereArgs: [draftId],
    );
  }

  /// Get count of drafts by status
  Future<int> getDraftCount({DraftStatus? status}) async {
    final db = await database;
    String query;
    List<Object?>? args;

    if (status != null) {
      query = 'SELECT COUNT(*) FROM news_drafts WHERE status = ?';
      args = [status.name];
    } else {
      query = 'SELECT COUNT(*) FROM news_drafts';
    }

    final result = await db.rawQuery(query, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Helper: Convert database JSON to NewsDraft
  NewsDraft _draftFromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'] as String?;
    final images = imagesJson != null
        ? (jsonDecode(imagesJson) as List)
            .map((img) => DraftImage.fromJson(img as Map<String, dynamic>))
            .toList()
        : <DraftImage>[];

    return NewsDraft(
      draftId: json['draft_id'] as int,
      title: json['title'] as String?,
      content: json['content'] as String?,
      categoryId: json['category_id'] as int?,
      sourceUrl: json['source_url'] as String?,
      images: images,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      status: DraftStatus.values.byName(json['status'] as String),
      uploadError: json['upload_error'] as String?,
    );
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
