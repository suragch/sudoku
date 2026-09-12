import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/engine/sudoku_solver.dart';
import 'package:sudoku/engine/sudoku_generator.dart';
import 'package:sudoku/models/game_enums.dart';

void main() {
  group('SudokuSolver', () {
    test('solves a known puzzle correctly', () {
      final puzzle = [
        [5, 3, 0, 0, 7, 0, 0, 0, 0],
        [6, 0, 0, 1, 9, 5, 0, 0, 0],
        [0, 9, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 6, 0, 0, 0, 3],
        [4, 0, 0, 8, 0, 3, 0, 0, 1],
        [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 8, 0],
        [0, 0, 0, 4, 1, 9, 0, 0, 5],
        [0, 0, 0, 0, 8, 0, 0, 7, 9],
      ];

      final solved = SudokuSolver.solve(puzzle);
      expect(solved, isNotNull);
      expect(solved![0][0], equals(5));
      expect(solved[0][1], equals(3));
      expect(solved[0][2], equals(4));

      // Verify each row has 1..9
      for (int r = 0; r < 9; r++) {
        expect(solved[r].toSet(), equals({1, 2, 3, 4, 5, 6, 7, 8, 9}));
      }

      // Verify unique solution
      expect(SudokuSolver.countSolutions(puzzle), equals(1));
    });

    test('detects board with multiple solutions', () {
      // Empty board has many solutions
      final empty = List.generate(9, (_) => List.filled(9, 0));
      expect(SudokuSolver.countSolutions(empty, maxCount: 2), equals(2));
    });
  });

  group('SudokuGenerator', () {
    test('generates valid solved board', () {
      final generator = SudokuGenerator();
      final solved = generator.generateSolvedBoard();

      expect(solved.length, equals(9));
      for (int r = 0; r < 9; r++) {
        expect(solved[r].toSet(), equals({1, 2, 3, 4, 5, 6, 7, 8, 9}));
      }
    });

    test('generates a playable board with unique solution', () {
      final generator = SudokuGenerator();
      final board = generator.generateBoard(Difficulty.easy);

      expect(board.cells.length, equals(9));
      int clueCount = 0;
      final grid = List.generate(9, (r) => List.filled(9, 0));

      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          final cell = board.cellAt(r, c);
          if (cell.isGiven) {
            clueCount++;
            grid[r][c] = cell.value;
          }
        }
      }

      expect(clueCount, lessThanOrEqualTo(45));
      expect(clueCount, greaterThanOrEqualTo(25));
      expect(SudokuSolver.hasUniqueSolution(grid), isTrue);
    });
  });
}
