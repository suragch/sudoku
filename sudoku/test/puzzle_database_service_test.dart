import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sudoku/engine/sudoku_solver.dart';
import 'package:sudoku/models/game_enums.dart';
import 'package:sudoku/services/puzzle_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('PuzzleDatabaseService', () {
    late PuzzleDatabaseService service;

    setUpAll(() async {
      // In flutter test, open assets/puzzles/puzzles.db directly via FFI with absolute path
      final absPath = File('assets/puzzles/puzzles.db').absolute.path;
      final db = await databaseFactoryFfi.openDatabase(
        absPath,
        options: OpenDatabaseOptions(readOnly: true),
      );
      service = await PuzzleDatabaseService.init(database: db);
    });

    tearDownAll(() async {
      await service.close();
    });

    test('PuzzleDatabaseService.init() works with default arguments', () async {
      final defaultService = await PuzzleDatabaseService.init();
      expect(await defaultService.getPuzzleCount(), equals(4000));
    });

    test('verifies puzzle counts for all 4 difficulties in database', () async {
      final total = await service.getPuzzleCount();
      expect(total, equals(4000));

      for (final diff in Difficulty.values) {
        final count = await service.getPuzzleCount(diff);
        expect(count, equals(1000), reason: 'Expected 1000 puzzles for ${diff.name}');
      }
    });

    test('getRandomPuzzle returns valid, unique, solvable board', () async {
      for (final diff in Difficulty.values) {
        final board = await service.getRandomPuzzle(diff);
        expect(board.cells.length, equals(9));
        expect(board.cells.every((r) => r.length == 9), isTrue);

        int clues = 0;
        final grid = List.generate(9, (r) => List.filled(9, 0));
        for (int r = 0; r < 9; r++) {
          for (int c = 0; c < 9; c++) {
            final cell = board.cellAt(r, c);
            if (cell.isGiven) {
              clues++;
              grid[r][c] = cell.value;
              expect(cell.value, equals(cell.solutionValue));
            }
          }
        }

        expect(clues, greaterThanOrEqualTo(17));
        expect(SudokuSolver.hasUniqueSolution(grid), isTrue);
      }
    });

    test('getPuzzleById returns expected record', () async {
      final record = await service.getPuzzleById('easy_0001');
      expect(record, isNotNull);
      expect(record!.id, equals('easy_0001'));
      expect(record.difficulty, equals('easy'));
      expect(record.puzzle.length, equals(81));
      expect(record.solution.length, equals(81));
      expect(record.techniquesUsed, isNotEmpty);
    });

    test('preloaded boards are available synchronously and independently', () {
      for (final diff in Difficulty.values) {
        final board1 = service.getPreloadedBoard(diff);
        final board2 = service.getPreloadedBoard(diff);
        expect(identical(board1, board2), isFalse);
        expect(board1.cells.length, equals(9));
      }
    });
  });
}
