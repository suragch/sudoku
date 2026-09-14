import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/engine/puzzle_seeds.dart';
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

    for (final difficulty in Difficulty.values) {
      test('generates playable board for ${difficulty.name} with unique solution', () {
        final generator = SudokuGenerator();
        final board = generator.generateBoard(difficulty);

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

        expect(clueCount, lessThanOrEqualTo(difficulty.clueTarget + 2));
        expect(clueCount, greaterThanOrEqualTo(21));
        expect(SudokuSolver.hasUniqueSolution(grid), isTrue);
      });
    }
  });

  group('PuzzleSeeds validation', () {
    for (int i = 0; i < PuzzleSeeds.seeds.length; i++) {
      final seed = PuzzleSeeds.seeds[i];
      test('seed $i (${seed.difficulty.name}) is valid, matches clues, and has unique solution', () {
        expect(seed.puzzle.length, equals(81));
        expect(seed.solution.length, equals(81));

        final grid = List.generate(9, (r) => List.filled(9, 0));
        for (int r = 0; r < 9; r++) {
          for (int c = 0; c < 9; c++) {
            final pChar = seed.puzzle[r * 9 + c];
            final sChar = seed.solution[r * 9 + c];
            if (pChar != '0' && pChar != '.') {
              expect(pChar, equals(sChar), reason: 'Clue mismatch at ($r, $c)');
              grid[r][c] = int.parse(pChar);
            }
          }
        }

        // Validate solution rows, cols, boxes
        for (int r = 0; r < 9; r++) {
          final row = [for (int c = 0; c < 9; c++) int.parse(seed.solution[r * 9 + c])];
          expect(row.toSet(), equals({1, 2, 3, 4, 5, 6, 7, 8, 9}), reason: 'Row $r invalid');
        }
        for (int c = 0; c < 9; c++) {
          final col = [for (int r = 0; r < 9; r++) int.parse(seed.solution[r * 9 + c])];
          expect(col.toSet(), equals({1, 2, 3, 4, 5, 6, 7, 8, 9}), reason: 'Col $c invalid');
        }
        for (int b = 0; b < 9; b++) {
          final startR = (b ~/ 3) * 3;
          final startC = (b % 3) * 3;
          final box = [
            for (int r = 0; r < 3; r++)
              for (int c = 0; c < 3; c++)
                int.parse(seed.solution[(startR + r) * 9 + (startC + c)])
          ];
          expect(box.toSet(), equals({1, 2, 3, 4, 5, 6, 7, 8, 9}), reason: 'Box $b invalid');
        }

        // Validate uniqueness
        expect(SudokuSolver.countSolutions(grid, maxCount: 2), equals(1));
        final solved = SudokuSolver.solve(grid);
        expect(solved, isNotNull);
        final solvedStr = solved!.map((r) => r.join()).join();
        expect(solvedStr, equals(seed.solution));
      });
    }
  });
}

