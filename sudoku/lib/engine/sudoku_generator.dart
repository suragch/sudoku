import 'dart:math';

import '../models/game_enums.dart';
import '../models/sudoku_board.dart';
import '../models/sudoku_cell.dart';
import 'puzzle_seeds.dart';
import 'sudoku_solver.dart';

class SudokuGenerator {
  final Random _random;

  SudokuGenerator([Random? random]) : _random = random ?? Random();

  /// Generates a fully solved 9x9 board.
  List<List<int>> generateSolvedBoard() {
    final board = List.generate(9, (_) => List<int>.filled(9, 0));

    // Fill the 3 independent diagonal boxes with random permutations
    for (int box = 0; box < 9; box += 4) {
      final nums = List.generate(9, (i) => i + 1)..shuffle(_random);
      int idx = 0;
      final startR = (box ~/ 3) * 3;
      final startC = (box % 3) * 3;
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          board[startR + r][startC + c] = nums[idx++];
        }
      }
    }

    // Solve the rest of the board using SudokuSolver
    final solved = SudokuSolver.solve(board);
    if (solved != null) {
      return solved;
    }

    // Fallback if random box placement was rare dead-end (very rare, retry)
    return generateSolvedBoard();
  }

  /// Generates a playable [SudokuBoard] for the given [difficulty].
  SudokuBoard generateBoard(Difficulty difficulty) {
    // Generate fresh solved board
    final solvedGrid = generateSolvedBoard();
    final puzzleGrid = List.generate(9, (r) => List<int>.from(solvedGrid[r]));

    // Generate list of symmetrical cell pairs
    final pairs = <Point<int>>[];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c <= 4; c++) {
        pairs.add(Point(r, c));
      }
    }
    pairs.shuffle(_random);

    int currentClues = 81;
    final targetClues = difficulty.clueTarget;

    for (final pt in pairs) {
      if (currentClues <= targetClues) break;

      final r1 = pt.x;
      final c1 = pt.y;
      final r2 = 8 - r1;
      final c2 = 8 - c1;

      final val1 = puzzleGrid[r1][c1];
      final val2 = puzzleGrid[r2][c2];

      if (val1 == 0) continue;

      // Temporarily remove
      puzzleGrid[r1][c1] = 0;
      puzzleGrid[r2][c2] = 0;
      final removedCount = (r1 == r2 && c1 == c2) ? 1 : 2;

      // Verify unique solution
      if (SudokuSolver.countSolutions(puzzleGrid, maxCount: 2) == 1) {
        currentClues -= removedCount;
      } else {
        // Restore
        puzzleGrid[r1][c1] = val1;
        puzzleGrid[r2][c2] = val2;
      }
    }

    // Create SudokuBoard with SudokuCell objects
    final cells = List.generate(9, (r) {
      return List.generate(9, (c) {
        final val = puzzleGrid[r][c];
        final isGiven = val != 0;
        return SudokuCell(
          row: r,
          col: c,
          solutionValue: solvedGrid[r][c],
          isGiven: isGiven,
          value: val,
        );
      });
    });

    return SudokuBoard(cells);
  }

  /// Creates a board from curated seeds (instantaneous load).
  static SudokuBoard loadFromSeed(Difficulty difficulty, [int seedIndex = 0]) {
    final matching = PuzzleSeeds.seeds.where((s) => s.difficulty == difficulty).toList();
    if (matching.isEmpty) {
      return SudokuGenerator().generateBoard(difficulty);
    }
    final seed = matching[seedIndex % matching.length];
    final cells = List.generate(9, (r) {
      return List.generate(9, (c) {
        final index = r * 9 + c;
        final pChar = seed.puzzle[index];
        final sChar = seed.solution[index];
        final val = (pChar != '.' && pChar != '0') ? int.parse(pChar) : 0;
        final sol = int.parse(sChar);
        return SudokuCell(
          row: r,
          col: c,
          solutionValue: sol,
          isGiven: val != 0,
          value: val,
        );
      });
    });
    return SudokuBoard(cells);
  }
}
