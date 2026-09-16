import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../engine/puzzle_record.dart';
import '../models/game_enums.dart';
import '../models/sudoku_board.dart';

/// Service responsible for loading and querying puzzles from the pre-generated SQLite database.
class PuzzleDatabaseService {
  final Database _db;
  static PuzzleDatabaseService? _instance;

  PuzzleDatabaseService(this._db);

  static PuzzleDatabaseService? get instanceOrNull => _instance;

  static PuzzleDatabaseService get instance {
    final inst = _instance;
    if (inst == null) {
      throw StateError(
        'PuzzleDatabaseService has not been initialized. Call init() first.',
      );
    }
    return inst;
  }

  /// Internal preloaded cache of 1 board per difficulty for immediate synchronous access.
  final Map<Difficulty, SudokuBoard> _preloadedBoards = {};

  /// Ensures SQLite FFI is initialized when running on desktop or in test environments.
  static void _ensureDatabaseFactory() {
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      return;
    }
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    } catch (_) {}
  }

  /// Opens or copies the pre-populated SQLite database.
  static Future<Database> openPuzzlesDatabase({
    String? customDbPath,
    String assetPath = 'assets/puzzles/puzzles.db',
    bool forceCopy = false,
  }) async {
    _ensureDatabaseFactory();

    if (customDbPath != null) {
      return await openDatabase(customDbPath, readOnly: true);
    }

    // In test environments or when running tests, if the asset exists on disk, open directly with FFI.
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final file = File(assetPath);
      if (file.existsSync()) {
        return await databaseFactoryFfi.openDatabase(
          file.absolute.path,
          options: OpenDatabaseOptions(readOnly: true),
        );
      }
    }

    String path;
    try {
      final databasesPath = await getDatabasesPath();
      path = p.join(databasesPath, 'puzzles.db');
    } catch (_) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final databasesPath = await databaseFactoryFfi.getDatabasesPath();
      path = p.join(databasesPath, 'puzzles.db');
    }

    final exists = await databaseExists(path);
    if (!exists || forceCopy) {
      try {
        await Directory(p.dirname(path)).create(recursive: true);
      } catch (_) {}

      Uint8List bytes;
      try {
        final data = await rootBundle.load(assetPath);
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } catch (_) {
        final file = File(assetPath);
        if (file.existsSync()) {
          bytes = await file.readAsBytes();
        } else {
          rethrow;
        }
      }
      await File(path).writeAsBytes(bytes, flush: true);
    }

    return await openDatabase(path, readOnly: true);
  }

  /// Initializes the service and preloads one initial puzzle per difficulty.
  static Future<PuzzleDatabaseService> init({
    Database? database,
    String? customDbPath,
    String assetPath = 'assets/puzzles/puzzles.db',
    bool forceCopy = false,
  }) async {
    final db = database ??
        await openPuzzlesDatabase(
          customDbPath: customDbPath,
          assetPath: assetPath,
          forceCopy: forceCopy,
        );

    final service = PuzzleDatabaseService(db);
    await service._preloadInitialBoards();
    _instance = service;
    return service;
  }

  Future<void> _preloadInitialBoards() async {
    for (final diff in Difficulty.values) {
      final record = await getRandomPuzzleRecord(diff);
      _preloadedBoards[diff] = SudokuBoard.fromRecord(record);
    }
  }

  /// Gets a preloaded board synchronously for initial fast display.
  SudokuBoard getPreloadedBoard(Difficulty difficulty) {
    final board = _preloadedBoards[difficulty];
    if (board != null) {
      return board.copy();
    }
    throw StateError(
      'No preloaded board found for difficulty: ${difficulty.name}',
    );
  }

  /// Fetches a random [SudokuPuzzleRecord] from SQLite for the given [difficulty].
  Future<SudokuPuzzleRecord> getRandomPuzzleRecord(Difficulty difficulty) async {
    final results = await _db.rawQuery(
      'SELECT id, difficulty, clue_count, puzzle, solution, hardest_technique, techniques_used '
      'FROM puzzles WHERE difficulty = ? ORDER BY RANDOM() LIMIT 1',
      [difficulty.name],
    );
    if (results.isEmpty) {
      throw StateError(
        'No puzzles found in database for difficulty: ${difficulty.name}',
      );
    }
    return _mapRow(results.first);
  }

  /// Fetches a random puzzle and constructs a [SudokuBoard].
  Future<SudokuBoard> getRandomPuzzle(Difficulty difficulty) async {
    final record = await getRandomPuzzleRecord(difficulty);
    return SudokuBoard.fromRecord(record);
  }

  /// Looks up a puzzle by its unique identifier (e.g. 'hard_0042').
  Future<SudokuPuzzleRecord?> getPuzzleById(String id) async {
    final results = await _db.rawQuery(
      'SELECT id, difficulty, clue_count, puzzle, solution, hardest_technique, techniques_used '
      'FROM puzzles WHERE id = ? LIMIT 1',
      [id],
    );
    if (results.isEmpty) return null;
    return _mapRow(results.first);
  }

  /// Looks up a puzzle with a specific hardest technique.
  Future<SudokuPuzzleRecord?> getPuzzleByTechnique(String technique) async {
    final results = await _db.rawQuery(
      'SELECT id, difficulty, clue_count, puzzle, solution, hardest_technique, techniques_used '
      'FROM puzzles WHERE hardest_technique = ? LIMIT 1',
      [technique],
    );
    if (results.isEmpty) return null;
    return _mapRow(results.first);
  }

  /// Returns the number of puzzles in the database, optionally filtered by difficulty.
  Future<int> getPuzzleCount([Difficulty? difficulty]) async {
    if (difficulty != null) {
      final res = await _db.rawQuery(
        'SELECT COUNT(*) as cnt FROM puzzles WHERE difficulty = ?',
        [difficulty.name],
      );
      return Sqflite.firstIntValue(res) ?? 0;
    } else {
      final res = await _db.rawQuery('SELECT COUNT(*) as cnt FROM puzzles');
      return Sqflite.firstIntValue(res) ?? 0;
    }
  }

  /// Closes the database connection.
  Future<void> close() async {
    await _db.close();
  }

  static SudokuPuzzleRecord _mapRow(Map<String, Object?> row) {
    final rawTechniques = row['techniques_used'];
    final Map<String, int> techniques;
    if (rawTechniques is String) {
      final decoded = jsonDecode(rawTechniques) as Map<String, dynamic>;
      techniques = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } else if (rawTechniques is Map) {
      techniques = rawTechniques.map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      );
    } else {
      techniques = {};
    }

    return SudokuPuzzleRecord(
      id: row['id'] as String,
      difficulty: row['difficulty'] as String,
      clueCount: (row['clue_count'] as num).toInt(),
      puzzle: row['puzzle'] as String,
      solution: row['solution'] as String,
      hardestTechnique: row['hardest_technique'] as String,
      techniquesUsed: techniques,
    );
  }
}
